// Native contour tracing uses the unchanged public Dart API glue.
#include "sdk/include/dart_api_dl.h"
#include "kernel.cpp"
#include "composite/contour_cpu_batch.h"
#include <condition_variable>
#include <memory>
#include <mutex>
#include <unordered_map>
#include <chrono>
#if defined(__linux__)
#include <sched.h>
#endif

namespace contour_native_port {
constexpr uint64_t kGlobalLimit = 64 * 1024 * 1024;
constexpr uint64_t kJobOverhead = 4096;
struct Context {
  uint64_t id;
  std::mutex mutex;
  std::atomic<bool> closed{false};
  Dart_Port_DL closeReply = 0;
  explicit Context(uint64_t value) : id(value) {}
};
struct OwnerToken {
  std::shared_ptr<Context> context;
  Dart_FinalizableHandle handle = nullptr;
};
struct Job {
  std::shared_ptr<Context> context;
  uint64_t ticket, inputBytes, quota;
  bool composite = false;
  contour_cpu::Output compositeOutput;
  bool posted = false, drained = false, acknowledged = false;
  Budget budget;
  CtOutput output{};
  std::atomic<uint32_t> phase{0};
  std::mutex barrierMutex;
  std::condition_variable barrierCondition;
  uint32_t blockStage = 0;
  bool released = false;
  Job(std::shared_ptr<Context> owner, uint64_t key, uint64_t source, uint64_t cap, bool full)
      : context(std::move(owner)), ticket(key), inputBytes(source), quota(cap), composite(full) {
    budget.limit = quota - inputBytes - kJobOverhead;
  }
  ~Job() {
    ct_free(&output);
  }
};
std::mutex registry;
std::mutex apiLifecycle;
std::unordered_map<uint64_t, OwnerToken *> owners;
std::unordered_map<uint64_t, std::shared_ptr<Job>> jobs;
std::unordered_map<uint64_t, uint32_t> blocks;
uint64_t nextOwner = 1, nextTicket = 1;
Dart_Port_DL nativePort = 0;
uint64_t heldBytes = 0, queued = 0, active = 0, maximumActive = 0;
uint64_t ownerCloses = 0;
uint64_t drainedCalls = 0, postedCalls = 0, failedPosts = 0, portsCreated = 0, acknowledgements = 0;
uint64_t inputBytesSubmitted = 0, currentIsolateChecks = 0;
// Native resource-accounting, timing, and thread-affinity diagnostics.
uint64_t handlerAffinityChecks = 0, handlerAffinityFailures = 0;
uint64_t handlerAffinityUnion = 0, firstHandlerAffinity = 0;
uint64_t kernelMicros = 0, firstKernelMicros = 0, kernelOutputBytes = 0;
uint64_t copiedOutputBytesPosted = 0, kernelStatuses[5]{};
bool kernelMeasured = false;

void handler(Dart_Port_DL, Dart_CObject *);

bool initialize(void *data) {
  // The finalizer/handler never takes this lock. No bookkeeping mutex spans a
  // VM API call, including slow-path native-port creation.
  std::lock_guard<std::mutex> apiLock(apiLifecycle);
  {
    std::lock_guard<std::mutex> lock(registry);
    if (nativePort != 0)
      return true;
  }
  if (Dart_InitializeApiDL(data) != 0 || !Dart_NewNativePort_DL || !Dart_Post_DL ||
      !Dart_PostCObject_DL || !Dart_NewFinalizableHandle_DL || !Dart_DeleteFinalizableHandle_DL ||
      !Dart_CurrentIsolate_DL || !Dart_CurrentIsolate_DL())
    return false;
  const auto port = Dart_NewNativePort_DL("oh_my_flutter_contour_native_port", handler, false);
  {
    std::lock_guard<std::mutex> lock(registry);
    nativePort = port;
    if (port != 0)
      portsCreated++;
  }
  return port != 0;
}

void closeToken(void *, void *peer) {
  // This callback may have no current isolate. No Dart API is called here.
  auto *token = static_cast<OwnerToken *>(peer);
  const auto context = token->context;
  context->closed = true;
  {
    std::lock_guard<std::mutex> lock(registry);
    owners.erase(context->id);
    ownerCloses++;
    // Queued/active jobs retain their reservation until the handler drains.
    // Copied output has no VM-free callback; explicit close retires only the
    // C admission lease. VM-owned copied reply storage is outside C visibility.
    for (auto it = jobs.begin(); it != jobs.end();) {
      const auto &job = it->second;
      if (job->context == context && job->drained) {
        heldBytes -= job->quota;
        it = jobs.erase(it);
      } else {
        ++it;
      }
    }
  }
  delete token;
}

void notifyClosed(const std::shared_ptr<Context> &context) {
  Dart_Port_DL reply = 0;
  {
    std::lock_guard<std::mutex> ownerLock(context->mutex);
    std::lock_guard<std::mutex> lock(registry);
    if (!context->closed || !context->closeReply)
      return;
    for (const auto &entry : jobs) {
      if (entry.second->context == context && !entry.second->drained)
        return;
    }
    reply = context->closeReply;
    context->closeReply = 0;
  }
  // Explicit UI close or native handler completion, never a finalizer callback.
  Dart_PostInteger_DL(reply, int64_t(context->id));
}

void waitAt(const std::shared_ptr<Job> &job, uint32_t phase) {
  job->phase.store(phase);
  if (job->blockStage != phase)
    return;
  std::unique_lock<std::mutex> lock(job->barrierMutex);
  job->barrierCondition.wait(lock, [&] { return job->released; });
}

Dart_CObject integer(int64_t value) {
  Dart_CObject object{};
  object.type = Dart_CObject_kInt64;
  object.value.as_int64 = value;
  return object;
}
int64_t readInteger(Dart_CObject *value) {
  if (value->type == Dart_CObject_kInt64)
    return value->value.as_int64;
  if (value->type == Dart_CObject_kInt32)
    return value->value.as_int32;
  return -1;
}

#include "composite/native_port_composite.inc"

bool postResult(const std::shared_ptr<Job> &job, Dart_Port_DL reply, int32_t status) {
  if (job->composite)
    return postComposite(job, reply, status);
  Dart_CObject ticket = integer(job->ticket), result = integer(status), lengths{}, values{},
               message{};
  const bool nonempty = status == 0 && job->output.count != 0;
  lengths.type = values.type = Dart_CObject_kTypedData;
  lengths.value.as_typed_data = {Dart_TypedData_kUint32,
                                 nonempty ? intptr_t(job->output.count) : 0,
                                 reinterpret_cast<uint8_t *>(job->output.lengths)};
  values.value.as_typed_data = {Dart_TypedData_kFloat64,
                                nonempty ? intptr_t(job->output.value_count) : 0,
                                reinterpret_cast<uint8_t *>(job->output.values)};
  Dart_CObject *fields[] = {&ticket, &result, &lengths, &values};
  message.type = Dart_CObject_kArray;
  message.value.as_array = {4, fields};
  const bool posted = Dart_PostCObject_DL(reply, &message);
  if (posted) {
    std::lock_guard<std::mutex> lock(registry);
    copiedOutputBytesPosted +=
        job->output.value_count * sizeof(double) + job->output.count * sizeof(uint32_t);
  }
  ct_free(&job->output); // The VM copied the data before returning.
  return posted;
}

void handler(Dart_Port_DL, Dart_CObject *message) {
  if (message->type != Dart_CObject_kArray ||
      (message->value.as_array.length != 8 && message->value.as_array.length != 9 &&
       message->value.as_array.length != 10))
    return;
  auto **fields = message->value.as_array.values;
  const int64_t ticket = readInteger(fields[2]);
  std::shared_ptr<Job> job;
  {
    std::lock_guard<std::mutex> lock(registry);
    const auto found = jobs.find(ticket);
    if (found == jobs.end())
      return;
    job = found->second;
    queued--;
    active++;
    maximumActive = std::max(maximumActive, active);
  }
  waitAt(job, 1);
  bool closed;
  {
    std::lock_guard<std::mutex> lock(job->context->mutex);
    closed = job->context->closed;
  }
  int32_t status = 5;
  const bool shape =
      readInteger(fields[1]) == int64_t(job->context->id) &&
      fields[0]->type == Dart_CObject_kSendPort && fields[3]->type == Dart_CObject_kTypedData &&
      fields[3]->value.as_typed_data.type == Dart_TypedData_kUint8 &&
      fields[3]->value.as_typed_data.length == intptr_t(job->inputBytes) &&
      (job->composite
           ? message->value.as_array.length == 9 && fields[7]->type == Dart_CObject_kTypedData
           : message->value.as_array.length == 8 && fields[6]->type == Dart_CObject_kDouble);
  if (!closed && shape) {
    // Decoded typed data is caller-owned until this handler returns. There is
    // no C input allocation or second input copy.
    BudgetScope scope(&job->budget);
#if defined(__linux__)
    cpu_set_t cpus;
    CPU_ZERO(&cpus);
    uint64_t mask = 0;
    const bool affinityValid = sched_getaffinity(0, sizeof(cpus), &cpus) == 0;
    if (affinityValid) {
      for (int cpu = 0; cpu < 64; cpu++) {
        if (CPU_ISSET(cpu, &cpus))
          mask |= uint64_t(1) << cpu;
      }
    }
    {
      std::lock_guard<std::mutex> lock(registry);
      if (handlerAffinityChecks == 0)
        firstHandlerAffinity = mask;
      handlerAffinityChecks++;
      if (!affinityValid)
        handlerAffinityFailures++;
      handlerAffinityUnion |= mask;
    }
#endif
    const auto began = std::chrono::steady_clock::now();
    status = job->composite
                 ? executeComposite(job, fields)
                 : ct_trace(fields[3]->value.as_typed_data.values, job->inputBytes,
                            uint32_t(readInteger(fields[4])), uint32_t(readInteger(fields[5])),
                            fields[6]->value.as_double, &job->output);
    if (!job->composite && status == 3 && job->budget.denied.load())
      status = job->output.status = 4;
    const auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(
                             std::chrono::steady_clock::now() - began)
                             .count();
    {
      std::lock_guard<std::mutex> lock(registry);
      kernelMicros += elapsed;
      if (!kernelMeasured) {
        firstKernelMicros = elapsed;
        kernelMeasured = true;
      }
      if (status >= 0 && status < 5)
        kernelStatuses[status]++;
      if (status == 0)
        kernelOutputBytes +=
            job->output.value_count * sizeof(double) + job->output.count * sizeof(uint32_t);
    }
  } else if (!closed) {
    status = 2;
  }
  waitAt(job, 2);
  bool attemptedPost = false;
  // No mutex is held across a VM call: a VM finalizer must never block on a
  // lock held by a thread waiting for the VM. A close racing this check can
  // produce a harmless late reply; the VM owns delivery/drop of copied data.
  if (!job->context->closed && fields[0]->type == Dart_CObject_kSendPort) {
    attemptedPost = true;
    job->posted = postResult(job, fields[0]->value.as_send_port.id, status);
  } else {
    job->compositeOutput = {};
    ct_free(&job->output);
  }
  {
    std::lock_guard<std::mutex> lock(registry);
    if (job->posted)
      postedCalls++;
    else if (attemptedPost)
      failedPosts++;
  }
  waitAt(job, 3);
  {
    std::lock_guard<std::mutex> ownerLock(job->context->mutex);
    std::lock_guard<std::mutex> lock(registry);
    job->drained = true;
    active--;
    drainedCalls++;
    if (!job->posted || job->acknowledged || job->context->closed) {
      heldBytes -= job->quota;
      jobs.erase(job->ticket);
    }
  }
  if (job->posted && fields[0]->type == Dart_CObject_kSendPort) {
    // The result can arrive before this handler retires its native state. This
    // separate event is posted only after ct_free and active/accounting updates.
    Dart_CObject key = integer(job->ticket), kind = integer(6), retired{};
    Dart_CObject *values[] = {&key, &kind};
    retired.type = Dart_CObject_kArray;
    retired.value.as_array = {2, values};
    Dart_PostCObject_DL(fields[0]->value.as_send_port.id, &retired);
  }
  notifyClosed(job->context);
  // Job/source RAII ends here; the VM reclaims decoded message data immediately
  // after callback return. A source reservation is never refunded on owner close
  // while its message is still queued or its handler is active.
}
} // namespace contour_native_port

extern "C" {
uint64_t ct_np_open(Dart_Handle object, void *api) {
  using namespace contour_native_port;
  if (!initialize(api) || !Dart_CurrentIsolate_DL())
    return 0;
  std::shared_ptr<Context> context;
  {
    std::lock_guard<std::mutex> lock(registry);
    currentIsolateChecks++;
    context = std::make_shared<Context>(nextOwner++);
  }
  auto *token = new OwnerToken{context};
  token->handle =
      Dart_NewFinalizableHandle_DL(object, token, sizeof(OwnerToken) + sizeof(Context), closeToken);
  if (!token->handle) {
    delete token;
    return 0;
  }
  {
    std::lock_guard<std::mutex> lock(registry);
    owners[context->id] = token;
  }
  return context->id;
}
int32_t ct_np_close_async(Dart_Handle object, uint64_t owner, Dart_Port_DL reply) {
  using namespace contour_native_port;
  if (reply == 0)
    return 3;
  OwnerToken *token;
  std::shared_ptr<Context> context;
  {
    std::lock_guard<std::mutex> lock(registry);
    const auto found = owners.find(owner);
    if (found == owners.end())
      return 2;
    token = found->second;
    context = token->context;
  }
  {
    std::lock_guard<std::mutex> ownerLock(context->mutex);
    context->closed = true;
    context->closeReply = reply;
  }
  Dart_DeleteFinalizableHandle_DL(token->handle, object);
  closeToken(nullptr, token);
  notifyClosed(context);
  return 0;
}
uint64_t ct_np_next_ticket() {
  std::lock_guard<std::mutex> lock(contour_native_port::registry);
  return contour_native_port::nextTicket++;
}
static int32_t ct_np_submit_impl(Dart_Handle message, uint64_t owner, uint64_t ticket,
                                 uint64_t sourceBytes, uint64_t quota, bool composite) {
  using namespace contour_native_port;
  std::shared_ptr<Job> job;
  {
    std::lock_guard<std::mutex> lock(registry);
    const auto found = owners.find(owner);
    if (found == owners.end() || found->second->context->closed.load())
      return 2;
    if (quota < sourceBytes || quota - sourceBytes < kJobOverhead || quota > kGlobalLimit)
      return 3;
    if (quota > kGlobalLimit - heldBytes)
      return 1;
    if (jobs.count(ticket))
      return 3;
    job = std::make_shared<Job>(found->second->context, ticket, sourceBytes, quota, composite);
    const auto blocked = blocks.find(ticket);
    if (blocked != blocks.end()) {
      job->blockStage = blocked->second;
      blocks.erase(blocked);
    }
    jobs[ticket] = job;
    heldBytes += quota;
    queued++;
    inputBytesSubmitted += sourceBytes;
  }
  // The reservation and queue transfer share this non-leaf FFI call. No Dart
  // cancellation point exists between an accepted reservation and posting it.
  if (Dart_Post_DL(nativePort, message))
    return 0;
  {
    std::lock_guard<std::mutex> lock(registry);
    jobs.erase(ticket);
    heldBytes -= quota;
    queued--;
    failedPosts++;
  }
  return 4;
}
int32_t ct_np_submit(Dart_Handle message, uint64_t owner, uint64_t ticket, uint64_t sourceBytes,
                     uint64_t quota) {
  return ct_np_submit_impl(message, owner, ticket, sourceBytes, quota, false);
}
int32_t ct_np_submit_composite(Dart_Handle message, uint64_t owner, uint64_t ticket,
                               uint64_t sourceBytes, uint64_t quota) {
  return ct_np_submit_impl(message, owner, ticket, sourceBytes, quota, true);
}
void ct_np_ack(uint64_t owner, uint64_t ticket) {
  using namespace contour_native_port;
  std::lock_guard<std::mutex> lock(registry);
  const auto found = jobs.find(ticket);
  if (found == jobs.end() || found->second->context->id != owner)
    return;
  const auto job = found->second;
  job->acknowledged = true;
  acknowledgements++;
  if (job->drained) {
    heldBytes -= job->quota;
    jobs.erase(found);
  }
}
uint64_t ct_np_stat(uint32_t index) {
  using namespace contour_native_port;
  std::lock_guard<std::mutex> lock(registry);
  switch (index) {
  case 0:
    return nativePort != 0;
  case 1:
    return owners.size();
  case 2:
    return queued;
  case 3:
    return active;
  case 4:
    return heldBytes;
  case 7:
    return ownerCloses;
  case 8:
    return drainedCalls;
  case 9:
    return postedCalls;
  case 10:
    return failedPosts;
  case 11:
    return portsCreated;
  case 12:
    return maximumActive;
  case 13:
    return jobs.size();
  case 14:
    return liveBytes.load();
  case 15:
    return calls.load();
  case 16:
    return acknowledgements;
  case 17:
    return 0; // C input copies/allocations.
  case 18:
    return inputBytesSubmitted;
  case 19:
    return currentIsolateChecks;
  case 20:
    return handlerAffinityChecks;
  case 21:
    return handlerAffinityFailures;
  case 22:
    return handlerAffinityUnion;
  case 23:
    return firstHandlerAffinity;
  case 24:
    return kernelMicros;
  case 25:
    return firstKernelMicros;
  case 26:
    return copiedOutputBytesPosted;
  case 27:
    return kernelOutputBytes;
  case 28:
    return kernelStatuses[0];
  case 29:
    return kernelStatuses[1];
  case 30:
    return kernelStatuses[2];
  case 31:
    return kernelStatuses[3];
  case 32:
    return kernelStatuses[4];
  case 33:
    return peakBytes.load();
  default:
    return 0;
  }
}
#ifdef CT_TESTING
void ct_np_test_block(uint64_t ticket, uint32_t stage) {
  std::lock_guard<std::mutex> lock(contour_native_port::registry);
  contour_native_port::blocks[ticket] = stage;
}
void ct_np_test_release(uint64_t ticket) {
  std::shared_ptr<contour_native_port::Job> job;
  {
    std::lock_guard<std::mutex> lock(contour_native_port::registry);
    const auto found = contour_native_port::jobs.find(ticket);
    if (found == contour_native_port::jobs.end())
      return;
    job = found->second;
  }
  std::lock_guard<std::mutex> lock(job->barrierMutex);
  job->released = true;
  job->barrierCondition.notify_all();
}
uint32_t ct_np_test_phase(uint64_t ticket) {
  std::lock_guard<std::mutex> lock(contour_native_port::registry);
  const auto found = contour_native_port::jobs.find(ticket);
  return found == contour_native_port::jobs.end() ? 0 : found->second->phase.load();
}
#endif // CT_TESTING
}
