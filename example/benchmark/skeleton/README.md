# Skeleton performance benchmark

Run the dense Skeleton workload in profile mode, capture the complete Flutter
log, then validate its exact records on the host:

```console
cd example

effect=shimmer
topology=single
renderer=impeller-vulkan
card_count=16
warmup_frames=180
frames_per_trial=600
run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$-${RANDOM}"
result_directory="build/benchmark-results/skeleton/$effect-$topology-$run_id"
mkdir -p "$result_directory"

fvm flutter run --profile --no-dds --no-enable-dart-profiling \
  --target benchmark/skeleton/main.dart \
  --device-id <device-id> \
  --dart-define=SKELETON_EFFECT="$effect" \
  --dart-define=SKELETON_TOPOLOGY="$topology" \
  --dart-define=SKELETON_RENDERER="$renderer" \
  --dart-define=SKELETON_RUN_ID="$run_id" \
  --dart-define=SKELETON_CARD_COUNT="$card_count" \
  --dart-define=SKELETON_WARMUP_FRAMES="$warmup_frames" \
  --dart-define=SKELETON_MEASURED_FRAMES="$frames_per_trial" \
  --dart-define=SKELETON_ENFORCE_FRAME_BUDGET=true \
  2>&1 | tee "$result_directory/flutter.log"

fvm dart run benchmark/skeleton/validate_skeleton_benchmark_log.dart \
  --log "$result_directory/flutter.log" \
  --output-directory "$result_directory/validated" \
  --expected-run-id "$run_id" \
  --expected-renderer "$renderer" \
  --expected-effect "$effect" \
  --expected-topology "$topology" \
  --expected-card-count "$card_count" \
  --expected-warmup-frames "$warmup_frames" \
  --expected-frames-per-trial "$frames_per_trial" \
  --require-budget-pass \
  --require-enforced
```

The validator's exit code is the acceptance authority. `flutter run` can lose
the device connection while the application closes and obscure its exit code.
The validator requires one profile environment, the exact fresh run ID and
workload labels, two separately gated steady trials, and one successful
acceptance record. It writes canonical records to `skeleton_benchmark.jsonl`
and a readable result to `skeleton_benchmark_summary.txt`.

The application waits for finite, nonzero logical and physical view metrics
before it captures the environment or begins either trial. The host validator
also rejects zero or nonfinite view sizes, device-pixel ratio, and refresh rate.
Platform animation scales must be enabled: reduced motion intentionally makes
animated Skeleton effects static, so the application fails immediately instead
of waiting for animation-driven frames that cannot arrive.

Each trial gets its own warmup and exactly `SKELETON_MEASURED_FRAMES` attributed
frames. Build and raster p99 must each fit the display's measured frame budget
in both trials; a good trial cannot hide a bad one. Build, raster, total-span,
and vsync-overhead distributions, missed-frame runs, descendant probe paints,
and transient callback counts are recorded. Every trial also requires zero
descendant probe paints and exactly one transient animation callback; these are
hard structural invariants, independent of the timing budget.

The harness observes Flutter lifecycle and benchmark-view focus. A change
during a steady window discards the whole attempt and records explicit
`invalid_reasons`. It waits for an interactive view, warms again, and retries
the trial up to three times. Exhausting those attempts fails validation.

`SKELETON_RENDERER` is a reporting label only. Verify the active renderer and
backend in startup or device logs before setting it. Generate a new
`SKELETON_RUN_ID` and start a fresh application process for every baseline or
candidate sample; the validator rejects stale or mixed records by requiring the
exact ID supplied on the command line.

The existing workload controls remain available:

- `SKELETON_EFFECT=fade|shimmer` selects the effect.
- `SKELETON_TOPOLOGY=single|many` selects one parent Skeleton or one per card.
- `SKELETON_CARD_COUNT` controls workload density.
- `SKELETON_WARMUP_FRAMES` controls the warmup before each steady trial.
- `SKELETON_MEASURED_FRAMES` controls each trial's sample size.
- `SKELETON_RENDERER` and `SKELETON_RUN_ID` label and bind the evidence.
- `SKELETON_ENFORCE_FRAME_BUDGET=true` makes the application also fail when
  either steady gate exceeds its build/raster p99 budget.

Repeat with a fresh run ID for `effect=fade` and for any topology under
comparison. Alternate baseline and candidate process order while holding device
refresh rate, renderer, thermal state, and workload values constant. Physical
low-end hardware is the release authority; emulator runs are relative stress
evidence only.

## Crossfade switch workload

`crossfade_main.dart` measures enabled-state switches rather than a continuously
running effect. It alternates skeleton-to-content and content-to-skeleton,
reports them separately, and counts descendant `CustomPainter.paint` calls.
Run identical commands against the baseline and candidate source trees; the
variant is an evidence label and does not change benchmark behavior.

```console
cd example

variant=baseline # use candidate in the candidate source tree
source=baseline-staged-snapshot # identify this exact source tree
renderer=skia-opengles # verify this in startup or device logs
topology=many
effect=static # repeat with shimmer
card_count=12
warmup_switches=12
measured_switches=40
run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$-${RANDOM}"
result_directory="build/benchmark-results/skeleton-crossfade/$variant-$effect-$topology-$run_id"
mkdir -p "$result_directory"

fvm flutter run --profile --no-dds --no-enable-dart-profiling \
  --target benchmark/skeleton/crossfade_main.dart \
  --device-id <device-id> \
  --dart-define=SKELETON_SWITCH_VARIANT="$variant" \
  --dart-define=SKELETON_SWITCH_SOURCE="$source" \
  --dart-define=SKELETON_SWITCH_RENDERER="$renderer" \
  --dart-define=SKELETON_SWITCH_RUN_ID="$run_id" \
  --dart-define=SKELETON_SWITCH_TOPOLOGY="$topology" \
  --dart-define=SKELETON_SWITCH_EFFECT="$effect" \
  --dart-define=SKELETON_SWITCH_CARD_COUNT="$card_count" \
  --dart-define=SKELETON_SWITCH_WARMUP_SWITCHES="$warmup_switches" \
  --dart-define=SKELETON_SWITCH_MEASURED_SWITCHES="$measured_switches" \
  2>&1 | tee "$result_directory/flutter.log"

fvm dart run benchmark/skeleton/validate_skeleton_crossfade_benchmark_log.dart \
  --log "$result_directory/flutter.log" \
  --output-directory "$result_directory/validated" \
  --expected-run-id "$run_id" \
  --expected-variant "$variant" \
  --expected-source "$source" \
  --expected-renderer "$renderer" \
  --expected-topology "$topology" \
  --expected-effect "$effect" \
  --expected-card-count "$card_count" \
  --expected-warmup-switches "$warmup_switches" \
  --expected-measured-switches "$measured_switches"
```

The validator requires profile mode, a matching run ID, valid display
metrics, an uninterrupted record for each direction, and nonempty timing
samples. It writes JSONL and a human-readable summary. After each switch, the
application schedules a frame and allows 500 ms for batched timings to arrive.
Frames that rasterize or report later can still be omitted, so inspect unusually
low frame counts and treat the reported percentiles as a bounded observation.
Frame attribution and pacing use the frame's vsync timestamp, which matches
the scheduler timestamp used to start each switch.
Add
`--dart-define=SKELETON_SWITCH_ENFORCE_BUDGET=true` to the run and
`--require-budget-pass --require-enforced` to validation when the test device
must pass the measured refresh-rate budget. Build, raster, and total-span
p50/p90/p99/max, budget misses, and probe paints are reported per direction.
The report also includes per-switch worst build and raster times, per-switch
vsync gaps (including the start and end of the 300 ms fade), and the
number of switches with a gap longer than 1.5 frame budgets. These pacing
numbers show stalls that pooled frame percentiles can
hide. The budget gate checks build and raster p99; inspect frame gaps and frame
counts separately when judging visual smoothness. Probe paints are counted
through switch settlement, slightly beyond the timing window.

`PASS` in the summary means log validation passed. The summary separately
reports whether the application enforced the timing budget and whether each
direction met it. The renderer and source labels are supplied by the runner;
the validator checks their consistency but cannot verify the active renderer,
APK source, or that a run ID was newly generated. Confirm those from device
startup logs and the built artifact before using a run as performance evidence.

For comparisons, use the same device, renderer, refresh rate, card count,
topology, effect, and switch counts. Alternate baseline and candidate process
order, rerun with fresh IDs, and inspect thermals and startup logs. Run both
`effect=static` and `effect=shimmer`; use `topology=many` to stress independent
instances and `topology=single` to isolate one large transition. A 1 GB
SwiftShader emulator provides relative stress evidence. It cannot establish
physical Galaxy J5 frame rates or guarantee equal smoothness across devices.
