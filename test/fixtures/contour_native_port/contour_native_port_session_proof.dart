@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_session.dart';

import 'contour_native_port_proof_support.dart';

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

  test('when geometry is posted before native retirement, it should keep the trace future pending', () async {
    final session = ContourNativePortSession.create()!;
    final ticket = ContourNativePortSessionTestSupport.nextTicket();
    ContourNativePortSessionTestSupport.block(ticket, 3);
    addTearDown(() async {
      ContourNativePortSessionTestSupport.release(ticket);
      await session.close();
    });
    var finished = false;
    final future = session
        .trace(
          ContourNativePortSessionTestSupport.source(),
          width: 32,
          height: 32,
          pixelRatio: 3,
          totalQuota: 1024 * 1024,
          ticket: ticket,
        )
        .whenComplete(() => finished = true);
    await ContourNativePortSessionTestSupport.waitForPhase(ticket, 3);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final blocked = [
      finished,
      session.pendingTickets,
      session.stats['active'],
      session.stats['heldBytes'],
    ];
    ContourNativePortSessionTestSupport.release(ticket);
    final result = await future;
    session.ack(result!.ticket);
    await session.close();
    expect(
      [blocked, result.status, session.stats['jobs']],
      [
        [
          false,
          [ticket],
          1,
          1024 * 1024,
        ],
        0,
        0,
      ],
    );
  }, skip: !supported);

  test(
    'when close races active native work, it should retain pending futures until actual cleanup acknowledgment',
    () async {
      final session = ContourNativePortSession.create()!;
      final ticket = ContourNativePortSessionTestSupport.nextTicket();
      ContourNativePortSessionTestSupport.block(ticket, 2);
      addTearDown(() async {
        ContourNativePortSessionTestSupport.release(ticket);
        await session.close();
      });
      var traceFinished = false;
      var closeFinished = false;
      final future = session
          .trace(
            ContourNativePortSessionTestSupport.source(),
            width: 32,
            height: 32,
            pixelRatio: 3,
            totalQuota: 1024 * 1024,
            ticket: ticket,
          )
          .whenComplete(() => traceFinished = true);
      await ContourNativePortSessionTestSupport.waitForPhase(ticket, 2);
      final closing = session.close().whenComplete(() => closeFinished = true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final blocked = (
        traceFinished,
        closeFinished,
        session.stats['jobs'],
        session.stats['heldBytes'],
      );
      ContourNativePortSessionTestSupport.release(ticket);
      await closing;
      final result = await future;
      expect(
        (
          blocked,
          result,
          session.pendingTickets.isEmpty,
          session.stats['jobs'],
          session.stats['heldBytes'],
          session.stats['nativeOutAndWorkspaceBytes'],
        ),
        ((false, false, 1, 1024 * 1024), null, true, 0, 0, 0),
      );
    },
    skip: !supported,
  );

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
