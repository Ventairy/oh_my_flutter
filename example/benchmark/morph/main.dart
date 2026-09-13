import 'package:flutter/material.dart';

import 'morph_benchmark.dart';

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final route = binding.platformDispatcher.defaultRouteName;
  runApp(
    route == '/' ? const MorphBenchmark() : MorphBenchmark(scenario: route.substring(1)),
  );
}
