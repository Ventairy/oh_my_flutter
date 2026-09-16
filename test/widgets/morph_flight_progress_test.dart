import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  test('when constructed publicly, it should preserve independent progress and playback information', () {
    const progress = MorphFlightProgress(
      curvedProgress: 1.2,
      uncurvedProgress: .8,
      flightKind: MorphFlightKind.routePop,
      animationStatus: AnimationStatus.forward,
    );
    expect(
      (progress.curvedProgress, progress.uncurvedProgress, progress.flightKind, progress.animationStatus),
      (1.2, .8, MorphFlightKind.routePop, AnimationStatus.forward),
    );
  });
  test('when all timing fields match, it should have equal values and hashes', () {
    const first = MorphFlightProgress(
      curvedProgress: .5,
      uncurvedProgress: .25,
      flightKind: MorphFlightKind.routePush,
      animationStatus: AnimationStatus.forward,
    );
    const second = MorphFlightProgress(
      curvedProgress: .5,
      uncurvedProgress: .25,
      flightKind: MorphFlightKind.routePush,
      animationStatus: AnimationStatus.forward,
    );
    expect((first == second, first.hashCode == second.hashCode), (true, true));
  });
  for (final field in ['curved', 'uncurved', 'kind', 'status']) {
    test('when $field differs, it should distinguish the progress contexts', () {
      const first = MorphFlightProgress(
        curvedProgress: .5,
        uncurvedProgress: .25,
        flightKind: MorphFlightKind.routePush,
        animationStatus: AnimationStatus.forward,
      );
      final second = MorphFlightProgress(
        curvedProgress: field == 'curved' ? .6 : .5,
        uncurvedProgress: field == 'uncurved' ? .3 : .25,
        flightKind: field == 'kind' ? MorphFlightKind.routePop : MorphFlightKind.routePush,
        animationStatus: field == 'status' ? AnimationStatus.reverse : AnimationStatus.forward,
      );
      expect(first, isNot(second));
    });
  }
}
