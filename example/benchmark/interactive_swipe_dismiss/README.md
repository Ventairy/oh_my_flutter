# InteractiveSwipeDismiss performance benchmark

This profile-mode harness exercises the Cataqui-style path: a downward
`freeDrag` interaction with `0.37` sensitivity, a body already scrolled to 600
logical pixels, and a full-header `InteractiveSwipeDismissHandle`. It drives a
continuous deterministic path below the 25% dismissal threshold, so a valid
trial reports zero dismissal callbacks and zero scroll drift.

Run a fresh baseline process from `example/`, capture its complete output, and
validate the log on the host:

```console
cd example

device_id=<device-id>
renderer=impeller-vulkan
warmup_frames=180
frames_per_trial=600
run_id="baseline-$(date -u +%Y%m%dT%H%M%SZ)-$$-${RANDOM}"
result_directory="build/benchmark-results/interactive_swipe_dismiss/$run_id"
mkdir -p "$result_directory"

fvm flutter run --profile --no-dds --no-devtools \
  --no-enable-dart-profiling \
  --enable-impeller \
  --target benchmark/interactive_swipe_dismiss/main.dart \
  --device-id "$device_id" \
  --dart-define=INTERACTIVE_SWIPE_DISMISS_RENDERER="$renderer" \
  --dart-define=INTERACTIVE_SWIPE_DISMISS_RUN_ID="$run_id" \
  --dart-define=INTERACTIVE_SWIPE_DISMISS_WARMUP_FRAMES="$warmup_frames" \
  --dart-define=INTERACTIVE_SWIPE_DISMISS_MEASURED_FRAMES="$frames_per_trial" \
  --dart-define=INTERACTIVE_SWIPE_DISMISS_ENFORCE_FRAME_BUDGET=true \
  --dart-define=INTERACTIVE_SWIPE_DISMISS_REQUIRE_RETAINED_PAINT=false \
  2>&1 | tee "$result_directory/flutter.log"

fvm dart run \
  benchmark/interactive_swipe_dismiss/validate_interactive_swipe_dismiss_benchmark_log.dart \
  --log "$result_directory/flutter.log" \
  --output-directory "$result_directory/validated" \
  --expected-run-id "$run_id" \
  --expected-renderer "$renderer" \
  --expected-warmup-frames "$warmup_frames" \
  --expected-frames-per-trial "$frames_per_trial" \
  --require-budget-pass \
  --require-enforced
```

The validator's exit code is the acceptance authority. It requires the exact
fresh run ID and workload, one profile environment record, two independently
gated steady trials, and one successful acceptance record. It also recomputes
every reported distribution and frame-budget count from the raw values. The
validated artifacts are
`interactive_swipe_dismiss_benchmark.jsonl` and
`interactive_swipe_dismiss_benchmark_summary.txt`.

Each trial has its own warmup and exactly
`INTERACTIVE_SWIPE_DISMISS_MEASURED_FRAMES` measured pointer moves and frame
timings. The records contain raw build, raster, total-span, vsync-overhead, and
pointer-dispatch distributions; child build, layout, and paint deltas; scroll
start, end, and maximum drift; callback count; maximum raw travel; and active
transient callbacks.

Baseline descendant paints are diagnostic. The workload deliberately has no
benchmark-owned `RepaintBoundary`, so the current implementation is allowed to
report descendant paints while the translation changes. A retained-rendering
candidate must instead set:

```console
--dart-define=INTERACTIVE_SWIPE_DISMISS_REQUIRE_RETAINED_PAINT=true
```

and the matching validator invocation must add:

```console
--require-retained-paint
```

That candidate gate requires zero child builds, layouts, and paints in every
steady trial. Baseline and candidate commands must otherwise be identical.
Use a new run ID and fresh application process for every replicate, alternate
their order, and hold renderer, refresh rate, device thermal state, and
workload values constant.

The harness retries a complete warmup and trial after lifecycle or benchmark
view-focus interruption, up to three attempts. It rejects reduced-motion mode,
invalid view metrics, mixed/stale records, incomplete Android log chunks,
scroll movement, dismissal callbacks, and motion that reaches the dismissal
distance.

`INTERACTIVE_SWIPE_DISMISS_RENDERER` is only an evidence label. Verify the
actual renderer and backend in startup or device logs before setting it. The
command's explicit target launches only this example benchmark; it does not
refresh a running Cataqui process.

## Constrained emulator

For repeatable relative stress evidence, start the existing 720x1280 API-30
AVD in a separate terminal with fixed resources. This AVD enforces its 2 GB
minimum even when the emulator is asked for less memory:

```console
"$ANDROID_HOME/emulator/emulator" \
  -avd Small_Phone_2GB_RAM \
  -read-only -no-snapshot -no-boot-anim -no-audio -no-window \
  -gpu host -memory 2048 -cores 2 -vsync-rate 60
```

Then use the profile command above with the emulator's exact device ID and a
renderer label verified from its startup log. On this API-30 image, Flutter
reports Impeller with OpenGLES even when the emulator host uses Vulkan.
Software-rendered runs can expose extra stress but are not comparable to a
physical GPU. Physical low-end hardware remains the release authority.
