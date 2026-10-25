@DefaultAsset(
  'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_bindings.dart',
)
library;

import 'dart:ffi';

/// Connects contour sessions to the packaged public NativePort backend.
abstract final class ContourNativePortBindings {
  /// Opens an owner and attaches its native finalizer in the same non-leaf call.
  @Native<Uint64 Function(Handle, Pointer<Void>)>(symbol: 'ct_np_open')
  external static int open(Object owner, Pointer<Void> initializeApiData);

  /// Closes admission and acknowledges only after native work has drained.
  @Native<Int32 Function(Handle, Uint64, Int64)>(symbol: 'ct_np_close_async')
  external static int closeAsync(Object owner, int ownerId, int replyPort);

  /// Allocates a unique ticket without admitting or posting any work.
  @Native<Uint64 Function()>(symbol: 'ct_np_next_ticket')
  external static int nextTicket();

  /// Atomically admits and posts one message using copied TypedData replies.
  @Native<Int32 Function(Handle, Uint64, Uint64, Uint64, Uint64)>(
    symbol: 'ct_np_submit',
  )
  external static int submit(
    Object message,
    int ownerId,
    int ticket,
    int sourceBytes,
    int totalQuota,
  );

  /// Releases admission after the caller has consumed copied geometry.
  @Native<Void Function(Uint64, Uint64)>(symbol: 'ct_np_ack')
  external static void ack(int ownerId, int ticket);

  /// Reads a process-global native diagnostic counter.
  @Native<Uint64 Function(Uint32)>(symbol: 'ct_np_stat')
  external static int stat(int index);

  /// Submits a bounded atlas for native contour and shadow composition.
  @Native<Int32 Function(Handle, Uint64, Uint64, Uint64, Uint64)>(symbol: 'ct_np_submit_composite')
  external static int submitComposite(Object message, int ownerId, int ticket, int sourceBytes, int totalQuota);
}
