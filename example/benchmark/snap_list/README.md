# SnapList benchmark

Run from `example/` on the device being measured:

```sh
fvm flutter run --profile -d DEVICE_ID --target benchmark/snap_list/snap_list_benchmark.dart --dart-define=ITEM_COUNT=1000
fvm flutter run --profile -d DEVICE_ID --target benchmark/snap_list/snap_list_benchmark.dart --dart-define=ITEM_COUNT=1000 --dart-define=HEAVY=true
```

Each run advances through 20 items and prints one `SNAP_LIST_BENCHMARK` JSON
record with frame counts, p95 build/raster durations, frames over a 16.67ms
budget, and item-builder calls. Compare counts of 100 and 10,000 to check that
lazy work stays bounded. The heavy case contains long scrollable item content.
Stop the application after its record appears.

Keep the device, renderer, build mode, and sample size with each result.
Desktop results do not certify phone performance; emulator measurements are
relative stress evidence. Separately test real gestures and nested handoff on
hardware. The widget rendering tests count eager child layouts and distant
paints without treating debug-test timings as frame-performance measurements.
