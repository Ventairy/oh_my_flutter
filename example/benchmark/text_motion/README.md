# TextMotion performance benchmark

Run this benchmark in profile mode on a physical target device:

```sh
cd example
fvm flutter run --profile \
  --target benchmark/text_motion/main.dart \
  --device-id <device-id>
```

The benchmark warms Flutter's text and rendering engines, measures cold
construction, and then measures the shared motion-effect glyph-atlas renderer
in two 300-frame steady trials. Results are printed as JSON lines beginning
with `TEXT_MOTION_BENCHMARK`.

The final acceptance entry compares build and raster p99 values with the
device's own refresh-rate budget. To make a failed acceptance terminate the
benchmark with a non-zero application exit code, add:

```sh
--dart-define=TEXT_MOTION_ENFORCE_FRAME_BUDGET=true
```

To stress multiple independently rendered labels, set the instance count:

```sh
--dart-define=TEXT_MOTION_INSTANCE_COUNT=8
```

The default is one instance. The acceptance JSON includes the configured
count so results cannot be confused across workloads.

Use a physical Galaxy J5-class Android device for the low-end release gate.
Emulator timings are useful for relative stress comparisons, but they are not
evidence of frame pacing on the target GPU and CPU.
