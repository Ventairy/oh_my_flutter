// Included inside contour_native_port. Public Dart API DL only.
int32_t compositeCancelled(void *context) {
  return static_cast<Context *>(context)->closed.load() ? 1 : 0;
}
int32_t compositeStatus(contour_generic::Status status) {
  switch (status) {
  case contour_generic::Status::ok:
    return 0;
  case contour_generic::Status::empty:
    return 1;
  case contour_generic::Status::invalid:
    return 2;
  case contour_generic::Status::failed:
    return 3;
  case contour_generic::Status::capacity:
    return 4;
  case contour_generic::Status::cancelled:
    return 5;
  case contour_generic::Status::unsupported:
    return 7;
  }
  return 3;
}
bool exactInteger(double value, uint64_t maximum) {
  return std::isfinite(value) && value >= 0 && value <= double(maximum) &&
         std::floor(value) == value;
}
int32_t executeComposite(const std::shared_ptr<Job> &job, Dart_CObject **fields) {
  const auto &data = fields[7]->value.as_typed_data;
  if (data.type != Dart_TypedData_kFloat64 || data.length < 25 || data.length > 40 * 25 ||
      data.length % 25)
    return 2;
  const size_t count = size_t(data.length) / 25;
  const auto *values = reinterpret_cast<const double *>(data.values);
  std::array<contour_cpu::Tile, 40> tiles{};
  for (size_t i = 0; i < count; i++) {
    const auto *v = values + i * 25;
    for (int j = 0; j < 4; j++)
      if (!exactInteger(v[j], 4096))
        return 2;
    if (!exactInteger(v[7], UINT32_MAX) || !exactInteger(v[8], 4))
      return 2;
    auto &t = tiles[i];
    t.x = uint32_t(v[0]);
    t.y = uint32_t(v[1]);
    t.width = uint32_t(v[2]);
    t.height = uint32_t(v[3]);
    t.source_ratio = v[4];
    t.output_ratio = v[5];
    t.amount = v[6];
    t.contour_argb = uint32_t(v[7]);
    t.shadow_count = size_t(v[8]);
    for (size_t s = 0; s < t.shadow_count; s++) {
      const auto *q = v + 9 + s * 4;
      if (!std::isfinite(q[0]) || !std::isfinite(q[1]) || !std::isfinite(q[2]) ||
          !exactInteger(q[3], UINT32_MAX))
        return 2;
      t.shadows[s] = {float(q[0]), float(q[1]), float(q[2]), uint32_t(q[3])};
    }
  }
  const auto width = readInteger(fields[4]), height = readInteger(fields[5]),
             stride = readInteger(fields[6]), workers = readInteger(fields[8]);
  if (width < 1 || width > 4096 || height < 1 || height > 4096 || stride < width * 4 ||
      uint64_t(stride) > job->inputBytes || workers < 1 || workers > 2)
    return 2;
  contour_cpu::Request request;
  request.rgba = fields[3]->value.as_typed_data.values;
  request.length = job->inputBytes;
  request.stride = size_t(stride);
  request.width = uint32_t(width);
  request.height = uint32_t(height);
  request.tiles = tiles.data();
  request.count = count;
  request.workers = uint32_t(workers);
  request.allocation_limit = job->quota - kJobOverhead;
  auto &output = job->compositeOutput;
  const auto result = contour_cpu::render(request, output, compositeCancelled, job->context.get());
  if (result == contour_generic::Status::ok &&
      (output.metrics.known_peak_bytes > request.allocation_limit ||
       output.rgba.size() > request.allocation_limit - output.metrics.known_peak_bytes)) {
    output = {};
    return 4; // Include the simultaneous VM copied-reply buffer.
  }
  return compositeStatus(result);
}
bool postComposite(const std::shared_ptr<Job> &job, Dart_Port_DL reply, int32_t status) {
  auto &o = job->compositeOutput;
  std::array<double, 40 * 6> placements{};
  const size_t count = status == 0 ? o.placements.size() : 0;
  for (size_t i = 0; i < count; i++) {
    const auto &p = o.placements[i];
    auto *v = placements.data() + i * 6;
    v[0] = p.x;
    v[1] = p.y;
    v[2] = p.width;
    v[3] = p.height;
    v[4] = p.left;
    v[5] = p.top;
  }
  const auto &m = o.metrics;
  const std::array<double, 10> metricValues{
      double(m.wall_ns),
      double(m.cpu_sum_ns),
      double(m.trace_cpu_ns),
      double(m.backing_cpu_ns),
      double(m.composition_cpu_ns),
      double(m.pack_cpu_ns),
      double(m.source_rgba_bytes),
      double(m.output_rgba_bytes),
      double(m.known_peak_bytes),
      double(m.active_peak)};
  Dart_CObject ticket = integer(job->ticket), result = integer(status),
               width = integer(status == 0 ? o.width : 0),
               height = integer(status == 0 ? o.height : 0), pixels{}, rects{}, metrics{},
               message{};
  pixels.type = rects.type = metrics.type = Dart_CObject_kTypedData;
  pixels.value.as_typed_data = {Dart_TypedData_kUint8, status == 0 ? intptr_t(o.rgba.size()) : 0,
                                o.rgba.data()};
  rects.value.as_typed_data = {Dart_TypedData_kFloat64, intptr_t(count * 6),
                               reinterpret_cast<uint8_t *>(placements.data())};
  metrics.value.as_typed_data = {
      Dart_TypedData_kFloat64, intptr_t(metricValues.size()),
      reinterpret_cast<uint8_t *>(const_cast<double *>(metricValues.data()))};
  Dart_CObject *fields[]{&ticket, &result, &width, &height, &pixels, &rects, &metrics};
  message.type = Dart_CObject_kArray;
  message.value.as_array = {7, fields};
  const bool posted = Dart_PostCObject_DL(reply, &message);
  if (posted) {
    std::lock_guard<std::mutex> lock(registry);
    copiedOutputBytesPosted +=
        o.rgba.size() + count * 6 * sizeof(double) + metricValues.size() * sizeof(double);
  }
  o = {};
  return posted;
}
