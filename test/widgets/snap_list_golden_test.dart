import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

Future<void> main() async {
  // Text blocking repaints render objects directly and skips opacity layers.
  // These geometry-only scenes use no text, so capture their real composition.
  final config = AlchemistConfig.current();
  await AlchemistConfig.runWithConfig(
    config: config.copyWith(ciGoldensConfig: config.ciGoldensConfig.copyWith(obscureText: false)),
    run: () {
      for (final axis in Axis.values) {
        for (final loading in [false, true]) {
          final controller = SnapListController();
          unawaited(
            goldenTest(
              'when a $axis list is ${loading ? 'waiting' : 'moving'}, it should preserve item geometry',
              fileName: 'snap_list_${axis.name}_${loading ? 'loading' : 'midpoint'}',
              constraints: const BoxConstraints.tightFor(width: 360, height: 300),
              whilePerforming: (tester) async {
                await tester.pumpAndSettle();
                unawaited(controller.next());
                await tester.pump();
                await tester.pump(Duration(milliseconds: loading ? 300 : 130));
                return tester.pumpAndSettle;
              },
              builder: () => MaterialApp(
                debugShowCheckedModeBanner: false,
                home: Scaffold(
                  body: SnapList(
                    axis: axis,
                    controller: controller,
                    duration: const Duration(milliseconds: 260),
                    incomingTransitionBuilder: (_, progress, isReverse, child) =>
                        FadeTransition(opacity: progress, child: child),
                    outgoingTransitionBuilder: (_, progress, isReverse, child) =>
                        ScaleTransition(scale: Tween<double>(begin: 1, end: .9).animate(progress), child: child),
                    spacing: 12,
                    trailingBuilder: loading
                        ? (_) => SizedBox(
                            width: axis == Axis.horizontal ? 90 : null,
                            height: axis == Axis.vertical ? 90 : null,
                            child: const ColoredBox(
                              color: Color(0xFFE1F5FE),
                              child: Center(
                                child: SizedBox(width: 52, height: 20, child: ColoredBox(color: Color(0xFF202020))),
                              ),
                            ),
                          )
                        : null,
                    children: [
                      for (var i = 0; i < (loading ? 1 : 3); i++)
                        ColoredBox(
                          color: i.isEven ? const Color(0xFFBBDEFB) : const Color(0xFFFFECB3),
                          child: const Center(
                            child: SizedBox(width: 40, height: 20, child: ColoredBox(color: Color(0xFF202020))),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      }
    },
  );
}
