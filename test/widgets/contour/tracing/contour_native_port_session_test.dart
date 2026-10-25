@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_session.dart';

import 'contour_native_port_session_test_support.dart';

void main() {
  final supported = ContourNativePortSession.isSupported;

  test('when native tracing completes, it should retain only admission until the consumer acknowledges it', () async {
    final session = ContourNativePortSession.create()!;
    addTearDown(session.close);
    final before = session.stats;
    final result = await session.trace(
      ContourNativePortSessionTestSupport.source(),
      width: 32,
      height: 32,
      pixelRatio: 3,
      totalQuota: 1024 * 1024,
    );
    final completed = session.stats;
    session.ack(result!.ticket);
    await session.close();
    final released = session.stats;
    expect(
      (
        result.status,
        result.contours.isNotEmpty,
        completed['calls']! - before['calls']!,
        completed['jobs'],
        completed['active'],
        completed['nativeOutAndWorkspaceBytes'],
        completed['heldBytes'],
        completed['cInputCopies'],
        released['owners'],
        released['jobs'],
        released['heldBytes'],
      ),
      (0, true, 1, 1, 0, 0, 1024 * 1024, 0, 0, 0, 0),
    );
  }, skip: !supported);

  test('when atomic admission rejects a quota, it should release its pending reply port immediately', () async {
    final session = ContourNativePortSession.create()!;
    addTearDown(session.close);
    Object? failure;
    try {
      await session.trace(
        ContourNativePortSessionTestSupport.source(),
        width: 32,
        height: 32,
        pixelRatio: 3,
        totalQuota: 1,
      );
    } catch (error) {
      failure = error;
    }
    await session.close();
    expect(
      (
        failure is StateError,
        session.pendingTickets.isEmpty,
        session.stats['jobs'],
        session.stats['heldBytes'],
      ),
      (true, true, 0, 0),
    );
  }, skip: !supported);

  test(
    'when a session closes twice, it should return the same cleanup fence and retain its owner identifier',
    () async {
      final session = ContourNativePortSession.create()!;
      final ownerId = session.ownerId;
      final first = session.close();
      final second = session.close();
      await first;
      expect(
        (identical(first, second), session.ownerId, session.stats['owners']),
        (true, ownerId, 0),
      );
    },
    skip: !supported,
  );

  test(
    'when the admitted kernel quota is exhausted, it should return a failure ticket for normal acknowledgment',
    () async {
      final session = ContourNativePortSession.create()!;
      addTearDown(session.close);
      final result = await session.trace(
        ContourNativePortSessionTestSupport.source(),
        width: 32,
        height: 32,
        pixelRatio: 3,
        totalQuota: 8193,
      );
      final completed = session.stats;
      session.ack(result!.ticket);
      await session.close();
      expect(
        (
          result.status,
          result.contours.isEmpty,
          completed['heldBytes'],
          session.stats['jobs'],
          session.stats['heldBytes'],
        ),
        (4, true, 8193, 0, 0),
      );
    },
    skip: !supported,
  );
}
