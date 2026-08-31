# Morph performance benchmark

Run on a physical target in profile mode without DevTools instrumentation,
capture the complete Flutter log, then validate the records on the host:

```console
cd example
result_directory=build/benchmark-results/morph/physical-all
mkdir -p "$result_directory"

fvm flutter run --profile --no-dds --no-devtools \
  --no-enable-dart-profiling \
  --enable-impeller \
  --target benchmark/morph/main.dart \
  --device-id <device-id> \
  --dart-define=MORPH_RENDERER=impeller-vulkan \
  --dart-define=MORPH_ENFORCE_FRAME_BUDGET=true \
  2>&1 | tee "$result_directory/flutter.log"

fvm dart run benchmark/morph/validate_morph_benchmark_log.dart \
  --log "$result_directory/flutter.log" \
  --output-directory "$result_directory/validated" \
  --expected-scenarios all \
  --minimum-frames 150 \
  --require-budget-pass \
  --require-enforced
```

The validator's exit code is the acceptance authority. Do not trust the
`flutter run` or pipeline exit status: losing the device connection while the
application closes can mask the application's exit code. Validation requires
the exact scenario set, one valid profile environment, all two-trial
forward/reverse steady gates, and exactly one successful application acceptance
record. It writes canonical extracted records to `morph_benchmark.jsonl` and a
human-readable result, including invalid attempts and completed retries, to
`morph_benchmark_summary.txt`.

`MORPH_RENDERER` is a reporting label only; it does not configure Flutter's
renderer. The example command explicitly enables Impeller because Flutter
3.47.1 does not enable it by default on Android. Verify the active renderer and
backend in Flutter's startup or device logs, then keep `impeller-vulkan` only
when that is the observed backend. Use `--no-enable-impeller` and an observed
Skia label for a Skia run. The harness rejects non-profile runs, an unspecified
renderer label, and an invalid display refresh rate.

The harness measures these Morph scenarios independently:

| ID | Coverage |
| --- | --- |
| `text` | Reflowing and restyled `Text` |
| `column` | Keyed four-text `Column` |
| `surface` | Decorated `Container` containing a `Column` |
| `foreground_static` | Static shadowed control painted live above a moving Morph surface |
| `foreground_live` | Shadowed foreground control repainting continuously above a moving Morph surface |
| `foreground_multi_static` | Sixteen independently retained static shadowed foreground controls |
| `foreground_multi_mixed` | Fifteen static controls plus one paint-only live caret control |
| `foreground_fallback_static` | Static shadowed control above a per-frame fallback Morph flight |
| `foreground_fallback_live` | Repainting shadowed control above a per-frame fallback Morph flight |
| `watch_text` | Continuously moving and resizing watched `Text` destination |
| `watch_compound` | Continuously moving and resizing watched compound destination |
| `watch_custom` | Continuously moving and resizing watched custom-delegate destination |
| `watch_stationary` | Watched destination that remains stationary after initial layout |
| `watch_stationary_control` | Matching stationary workload with watching disabled |
| `watch_snapshot_dense` | Twenty-four static snapshots inside a watched destination |
| `watch_snapshot_geometry_only` | Changing endpoint geometry with fixed descendant pixels and local sizes |
| `watch_snapshot_dynamic` | Four coalesced geometry and pixel mutation batches with one unchanged control |
| `watch_snapshot_full_surface` | Twelve consecutive-frame resizes of one near-full-surface snapshot |
| `watch_snapshot_nested_fallback` | Eight independent nested-boundary pixel changes |
| `resting_scroll` | Forty unmatched resting solid endpoints moving under one paint-only ancestor |
| `raw_descendants` | Ordinary descendants with endpoint-specific `MediaQuery` values |
| `raw_descendants_fade` | The same ordinary descendants with a fade transition |
| `descendant_live` | One live descendant in a resizing surface |
| `descendant_snapshot` | One captured descendant in a resizing surface |
| `descendant_hide` | One hidden descendant in a resizing surface |
| `descendant_snapshot_dense` | Twenty-four sibling snapshot descendants in one surface |
| `column_unmatched` | Unmatched ordinary departing and arriving `Column` children |
| `column_matched_raw_resize` | Hybrid `Column` path with one keyed ordinary child resizing from 166×62 to 278×126 |
| `nested_hold` | Four shorter nested `Text` flights held until their parent arrives |
| `nested_watch_hold` | Watched 160 ms nested `Text` held in a 640 ms parent while its target keeps moving |
| `decorated_background` | `DecoratedBox` background decoration |
| `decorated_foreground` | `DecoratedBox` foreground decoration |

Each scenario reports its initial forward flight as the cold sample. The
reverse record labelled `cold` is the first return after that forward flight;
it can reuse work and resources created while moving forward, so it is not an
independently cold reverse start. The harness then warms the exact scenario and
records two separately gated, sequential steady trials in both directions.
Independent replicates require fresh application processes. Each steady trial
defaults to at least 150 attributed frames, so the combined result contains at
least 300 steady frames per direction.

After timing, the harness runs 100 forward/reverse soak cycles. An `all` run
keeps the original `surface` soak; a focused run soaks its selected scenario.
Override this only for focused iteration:

```console
--dart-define=MORPH_SOAK_CYCLES=0
```

For comparable forced-GC VM snapshots before and after the soak, add a pause
at both stable, collapsed-state markers:

```console
--dart-define=MORPH_HEAP_PAUSE_SECONDS=30
```

The console reports `heap.baseline_ready` and `heap.soak_complete`. Query the
VM service during each pause and compare used heap plus retained Morph class
counts after forcing collection.

Frames are attributed by the Morph lifecycle and the engine's frame timestamp.
A timing batch delivered after ownership has already changed therefore remains
assigned to the flight that produced it. Results are JSON lines beginning with
`MORPH_BENCHMARK` and include build, raster, total-span, and vsync-overhead
distributions, over-budget counts, the longest sequence of misses, device
refresh rate, and the corresponding frame budget.

Each result also reports `trigger_to_on_start_us`. This measures elapsed wall
time from the benchmark state change until Morph invokes `onStart`, so it
includes the scheduling frame and any endpoint capture work that happens before
the timed flight. Compare it only between repeated runs of the same focused
scenario on the same device.

Fields prefixed with `temporal_` are process-wide `ui.Image` diagnostics sampled
during a scenario or flight. They include endpoint captures and any unrelated
image created in the same interval, so they are not Morph attribution and do
not participate in structural acceptance. The peak-live field tracks the
physical pixels of temporally observed flight images that overlap in lifetime;
it is not a complete process or GPU-memory measurement. Soak records report
temporal creation and disposal deltas after two quiescent frames.

The watched-snapshot scenarios add benchmark paint probes to a changing
descendant and an unchanged control, then baseline them in `onStart` after
initial endpoint capture. Structural gates use these probes, not process-wide
image callbacks:

- `watch_snapshot_dense` requires zero post-start paints from both probes.
- `watch_snapshot_geometry_only` requests four geometry-only batches and
  requires zero probe paints.
- `watch_snapshot_dynamic` requests four batches with three synchronous changes
  each. The dirty probe must capture generations 3, 6, 9, and 12 relative to its
  start, while the unchanged probe remains at zero.
- `watch_snapshot_full_surface` changes the local size and pixels of a
  near-full-surface snapshot on twelve consecutive frames. Its dirty probe must
  capture every requested generation while its separate control remains at
  zero.
- `watch_snapshot_nested_fallback` changes a painter independently behind a
  nested repaint boundary. The dirty probe must observe every requested
  generation in order, while the unchanged nested control remains at zero.

Every changing probe must paint exactly once per requested batch and at most
once per frame. Unchanged probes must remain at zero. These records are
host-validated per transition in both directions and participate in
acceptance.

The harness also observes Flutter application lifecycle and view-focus events.
If either changes during a measured flight, the complete cold or steady trial
attempt is discarded and reported as `valid: false` with explicit
`invalid_reasons`. The trial restarts from its collapsed state, up to three
attempts. A valid retried result includes its `attempt` and `retried` fields;
the final acceptance line reports `invalid_trial_attempts` and
`retried_trials`. Exhausting all attempts fails the benchmark instead of
grading interrupted frame timings.

## Acceptance mode

Fail the application process when build or raster p99 exceeds the current
display budget in any steady trial:

```console
--dart-define=MORPH_ENFORCE_FRAME_BUDGET=true
```

Cold and combined reports are diagnostic. Every individual steady trial is a
gate, preventing one unusually good run from hiding another regression. The
watched-snapshot structural gates apply even when frame-budget enforcement is
disabled.

## Focused iteration

Run only one scenario while investigating it:

```console
--dart-define=MORPH_SCENARIO=text
--dart-define=MORPH_SCENARIO=column
--dart-define=MORPH_SCENARIO=surface
--dart-define=MORPH_SCENARIO=foreground_static
--dart-define=MORPH_SCENARIO=foreground_live
--dart-define=MORPH_SCENARIO=foreground_multi_static
--dart-define=MORPH_SCENARIO=foreground_multi_mixed
--dart-define=MORPH_SCENARIO=foreground_fallback_static
--dart-define=MORPH_SCENARIO=foreground_fallback_live
--dart-define=MORPH_SCENARIO=watch_text
--dart-define=MORPH_SCENARIO=watch_compound
--dart-define=MORPH_SCENARIO=watch_custom
--dart-define=MORPH_SCENARIO=watch_stationary
--dart-define=MORPH_SCENARIO=watch_stationary_control
--dart-define=MORPH_SCENARIO=watch_snapshot_dense
--dart-define=MORPH_SCENARIO=watch_snapshot_geometry_only
--dart-define=MORPH_SCENARIO=watch_snapshot_dynamic
--dart-define=MORPH_SCENARIO=watch_snapshot_full_surface
--dart-define=MORPH_SCENARIO=watch_snapshot_nested_fallback
--dart-define=MORPH_SCENARIO=resting_scroll
--dart-define=MORPH_SCENARIO=raw_descendants
--dart-define=MORPH_SCENARIO=raw_descendants_fade
--dart-define=MORPH_SCENARIO=descendant_live
--dart-define=MORPH_SCENARIO=descendant_snapshot
--dart-define=MORPH_SCENARIO=descendant_hide
--dart-define=MORPH_SCENARIO=descendant_snapshot_dense
--dart-define=MORPH_SCENARIO=column_unmatched
--dart-define=MORPH_SCENARIO=column_matched_raw_resize
--dart-define=MORPH_SCENARIO=nested_hold
--dart-define=MORPH_SCENARIO=nested_watch_hold
--dart-define=MORPH_SCENARIO=decorated_background
--dart-define=MORPH_SCENARIO=decorated_foreground
```

The multi-foreground scenarios use 16 controls by default. Override the count
for focused scaling comparisons while keeping at least one control:

```console
--dart-define=MORPH_FOREGROUND_COUNT=4
```

The default is `all`. For quick local investigation, reduce the per-trial
sample target while retaining two separately gated trials:

```console
--dart-define=MORPH_STEADY_FRAMES_PER_TRIAL=60
```

Do not use a reduced sample target for release evidence.

An `all` run executes scenarios in a fixed order and is coverage evidence, not
a causal A/B comparison. Caches, raster pools, and device temperature can carry
across scenarios. For an optimization comparison, run the focused scenario in
a fresh application process for every sample, alternate the baseline and
candidate order, and balance the order of related scenario variants. Pass that
focused identifier to both `MORPH_SCENARIO` and the validator's
`--expected-scenarios` option.

## Constrained emulator

The local 720p, API-30, 2 GB AVD can provide a repeatable stress comparison:

```console
"$ANDROID_HOME/emulator/emulator" \
  -avd Small_Phone_2GB_RAM \
  -no-snapshot -no-boot-anim -no-audio -no-window \
  -gpu swiftshader -memory 1536 -cores 2 -vsync-rate 60

fvm flutter run --profile --no-dds --no-devtools \
  --no-enable-dart-profiling \
  --enable-impeller \
  --target benchmark/morph/main.dart \
  --device-id emulator-5554 \
  --dart-define=MORPH_RENDERER=impeller-vulkan
```

Emulator results are relative stress evidence only. SwiftShader and the host
CPU do not reproduce a Galaxy J5 GPU or CPU, so a physical low-end Android
device remains necessary for the final release gate. At the configured 60 Hz,
the enforced build and raster p99 ceiling is 16,666 microseconds per frame.
