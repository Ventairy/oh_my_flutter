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
