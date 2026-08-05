part of 'main.dart';

enum _TextMotionBenchmarkStage {
  engineWarmup,
  optimizedCold,
  optimizedWarmupFirst,
  optimizedSteadyFirst,
  optimizedWarmupSecond,
  optimizedSteadySecond,
  finished;

  bool get isEngineWarmup => this == engineWarmup;

  bool get isFinished => this == finished;

  bool get isOptimizedSteady => switch (this) {
    optimizedSteadyFirst || optimizedSteadySecond => true,
    _ => false,
  };

  int get sampleFrames => switch (this) {
    optimizedCold => _coldFrames,
    optimizedSteadyFirst || optimizedSteadySecond => _steadyFramesPerTrial,
    _ => 0,
  };

  String? get reportName => switch (this) {
    optimizedCold => 'optimized_cold',
    optimizedSteadyFirst => 'optimized_steady_first',
    optimizedSteadySecond => 'optimized_steady_second',
    _ => null,
  };
}
