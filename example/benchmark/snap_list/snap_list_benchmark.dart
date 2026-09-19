// dart format width=80
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() => runApp(const MaterialApp(home: SnapListBenchmark()));

/// Reports frame timings for lazy navigation through large lists.
class SnapListBenchmark extends StatefulWidget {
  /// Creates a benchmark selected with the HEAVY and ITEM_COUNT dart defines.
  const new({super.key});

  @override
  State<SnapListBenchmark> createState() => _SnapListBenchmarkState();
}

class _SnapListBenchmarkState extends State<SnapListBenchmark> {
  static const _heavy = bool.fromEnvironment('HEAVY');
  static const _count = int.fromEnvironment('ITEM_COUNT', defaultValue: 1000);
  final _controller = SnapListController();
  final _frames = <FrameTiming>[];
  var _builds = 0;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_record);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  void _record(List<FrameTiming> frames) => _frames.addAll(frames);

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    _frames.clear();
    final initialBuilds = _builds;
    for (var i = 0; i < 20 && mounted; i++) {
      await _controller.next();
    }
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    final build = _frames.map((f) => f.buildDuration.inMicroseconds).toList()
      ..sort();
    final raster = _frames.map((f) => f.rasterDuration.inMicroseconds).toList()
      ..sort();
    final result = {
      'heavy': _heavy,
      'itemCount': _count,
      'frames': _frames.length,
      'itemBuildsDuring20Transitions': _builds - initialBuilds,
      'buildP95Micros': build.isEmpty
          ? null
          : build[(build.length * .95).floor()],
      'rasterP95Micros': raster.isEmpty
          ? null
          : raster[(raster.length * .95).floor()],
      'framesOver16ms': _frames
          .where(
            (f) =>
                f.buildDuration.inMicroseconds > 16667 ||
                f.rasterDuration.inMicroseconds > 16667,
          )
          .length,
    };
    debugPrint('SNAP_LIST_BENCHMARK ${jsonEncode(result)}');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SnapList.builder(
      controller: _controller,
      itemCount: _count,
      itemBuilder: (context, index) {
        _builds++;
        return ColoredBox(
          color: index.isEven ? Colors.white : Colors.blue.shade50,
          child: _heavy
              ? SingleChildScrollView(
                  child: Column(
                    children: [
                      for (var row = 0; row < 40; row++)
                        ListTile(
                          leading: const Icon(Icons.article),
                          title: Text('Item $index, paragraph $row'),
                          subtitle: const Text(
                            'A realistic amount of repeated content '
                            'for profiling.',
                          ),
                        ),
                    ],
                  ),
                )
              : Center(child: Text('Item $index')),
        );
      },
    ),
  );

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_record);
    _controller.dispose();
    super.dispose();
  }
}
