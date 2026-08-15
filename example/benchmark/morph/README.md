# Morph performance benchmark

Run on a physical target in profile mode without DevTools instrumentation,
capture the complete Flutter log, then validate the records on the host:

```console
cd example
result_directory=build/benchmark-results/morph/physical-all
mkdir -p "$result_directory"

fvm flutter run --profile --no-dds --no-enable-dart-profiling \
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
renderer. Verify the active renderer and backend in Flutter's startup or device
logs, then set the label to that observed value. The harness rejects non-profile
runs, an unspecified renderer label, and an invalid display refresh rate.

The harness measures these Morph scenarios independently:

| ID                          | Coverage                                                                           |
| --------------------------- | ---------------------------------------------------------------------------------- |
| `text`                      | Reflowing and restyled `Text`                                                      |
| `column`                    | Keyed four-text `Column`                                                           |
| `surface`                   | Decorated `Container` containing a `Column`                                        |
| `watch_text`                | Continuously moving and resizing watched `Text` destination                        |
| `watch_compound`            | Continuously moving and resizing watched compound destination                      |
| `watch_custom`              | Continuously moving and resizing watched custom-delegate destination               |
| `watch_stationary`          | Watched destination that remains stationary after initial layout                   |
| `watch_stationary_control`  | Matching stationary workload with watching disabled                                |
| `resting_scroll`            | Forty unmatched resting solid endpoints moving under one paint-only ancestor       |
| `raw_descendants`           | Ordinary descendants with endpoint-specific `MediaQuery` values                    |
| `raw_descendants_fade`      | The same ordinary descendants with a fade transition                               |
| `column_unmatched`          | Unmatched ordinary departing and arriving `Column` children                        |
| `column_matched_raw_resize` | Hybrid `Column` path with one keyed ordinary child resizing from 166×62 to 278×126 |
| `nested_hold`               | Four shorter nested `Text` flights held until their parent arrives                 |
| `nested_watch_hold`         | Watched 160 ms nested `Text` held in a 640 ms parent while its target keeps moving |
| `decorated_background`      | `DecoratedBox` background decoration                                               |
| `decorated_foreground`      | `DecoratedBox` foreground decoration                                               |

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

Raster image creation and disposal fields are process-wide diagnostics sampled
during a scenario window. They are not reliable Morph attribution and are not
part of host acceptance.

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
gate, preventing one unusually good run from hiding another regression.

## Focused iteration

Run only one scenario while investigating it:

```console
--dart-define=MORPH_SCENARIO=text
--dart-define=MORPH_SCENARIO=column
--dart-define=MORPH_SCENARIO=surface
--dart-define=MORPH_SCENARIO=watch_text
--dart-define=MORPH_SCENARIO=watch_compound
--dart-define=MORPH_SCENARIO=watch_custom
--dart-define=MORPH_SCENARIO=watch_stationary
--dart-define=MORPH_SCENARIO=watch_stationary_control
--dart-define=MORPH_SCENARIO=resting_scroll
--dart-define=MORPH_SCENARIO=raw_descendants
--dart-define=MORPH_SCENARIO=raw_descendants_fade
--dart-define=MORPH_SCENARIO=column_unmatched
--dart-define=MORPH_SCENARIO=column_matched_raw_resize
--dart-define=MORPH_SCENARIO=nested_hold
--dart-define=MORPH_SCENARIO=nested_watch_hold
--dart-define=MORPH_SCENARIO=decorated_background
--dart-define=MORPH_SCENARIO=decorated_foreground
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
$HOME/Library/Android/sdk/emulator/emulator \
  -avd Small_Phone_2GB_RAM \
  -no-snapshot-load -no-snapshot-save -no-boot-anim \
  -no-audio -no-window -gpu swiftshader_indirect

fvm flutter run --profile --no-dds --no-enable-dart-profiling \
  --target benchmark/morph/main.dart \
  --device-id emulator-5554 \
  --dart-define=MORPH_RENDERER=impeller-opengles
```

Emulator results are relative stress evidence only. SwiftShader and the host
CPU do not reproduce a Galaxy J5 GPU or CPU, so a physical low-end Android
device remains necessary for the final release gate.
