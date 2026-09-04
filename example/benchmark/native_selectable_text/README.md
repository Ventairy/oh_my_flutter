# NativeSelectableText performance benchmark

This profile-mode benchmark compares `NativeSelectableText` with ordinary
`SelectableText` under three workloads:

- `scroll` moves a lazy list a fixed logical distance on every display frame.
- `selection` keeps a toolbar open while moving a selection endpoint on every
  display frame. The native case exercises the Pigeon and platform-menu update
  path. The control uses an empty Flutter toolbar.
- `menu_idle` opens the same selection and menu, then drives the frame ticker
  without changing selection or geometry. It isolates the resident native menu
  and Android `ActionMode`/pre-draw cost from bridge update traffic.

The `short`, `paragraph`, `long`, and `rich` text cases separate fixed bridge
overhead from glyph/selection geometry costs. Run each A/B case in a fresh
process and alternate their order. Keep the device, renderer, display refresh
rate, thermal state, item count, text case, and frame counts unchanged.

## Capture one run

Verify the renderer from startup or device logs before assigning its label.
Use a fresh run ID and retain the complete `flutter run` log:

```console
cd example
set -o pipefail

device_id=<android-device-id>
scenario=selection
widget=native
text_case=paragraph
renderer=impeller-vulkan
warmup_frames=180
measured_frames=600
item_count=240
run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$-${RANDOM}"
log_path="/tmp/native-selectable-text-$run_id.log"

fvm flutter run --profile --no-dds --no-enable-dart-profiling \
  --target benchmark/native_selectable_text/main.dart \
  --device-id "$device_id" \
  --dart-define=NATIVE_SELECTABLE_TEXT_SCENARIO="$scenario" \
  --dart-define=NATIVE_SELECTABLE_TEXT_WIDGET="$widget" \
  --dart-define=NATIVE_SELECTABLE_TEXT_TEXT_CASE="$text_case" \
  --dart-define=NATIVE_SELECTABLE_TEXT_RENDERER="$renderer" \
  --dart-define=NATIVE_SELECTABLE_TEXT_RUN_ID="$run_id" \
  --dart-define=NATIVE_SELECTABLE_TEXT_WARMUP_FRAMES="$warmup_frames" \
  --dart-define=NATIVE_SELECTABLE_TEXT_MEASURED_FRAMES="$measured_frames" \
  --dart-define=NATIVE_SELECTABLE_TEXT_ITEM_COUNT="$item_count" \
  --dart-define=NATIVE_SELECTABLE_TEXT_ENFORCE_FRAME_BUDGET=true \
  2>&1 | tee "$log_path"
```

With enforcement enabled, an application error or a build/raster p99 miss in
either measured trial requests a nonzero process exit. The host validator below
is still the authoritative gate because it detects missing/truncated records,
stale run IDs, configuration drift, inconsistent metrics, and a false
application acceptance result even when a runner masks the application exit.

For a native selection or menu-idle run, the harness lets menu presentation
settle and verifies that exactly one `NativeSelectableText` target still owns a
valid non-collapsed selection and an open context-menu overlay, with no
`AdaptiveTextSelectionToolbar` mounted. It repeats this check before and after
every warmup and measured window, so a failed or dismissed presentation cannot
produce native-labelled timings. Fix the host or device state before repeating
an invalid measurement.

## Validate the captured evidence

```console
artifact_directory="/tmp/native-selectable-text-$run_id-artifacts"
validator_path=benchmark/native_selectable_text/\
validate_native_selectable_text_benchmark_log.dart

fvm dart run "$validator_path" \
  --log "$log_path" \
  --output-directory "$artifact_directory" \
  --expected-run-id "$run_id" \
  --expected-renderer "$renderer" \
  --expected-scenario "$scenario" \
  --expected-widget "$widget" \
  --expected-text-case "$text_case" \
  --expected-item-count "$item_count" \
  --expected-warmup-frames "$warmup_frames" \
  --expected-frames-per-trial "$measured_frames" \
  --require-budget-pass \
  --require-enforced
```

The validator writes normalized JSON Lines and a human-readable summary. Omit
`--require-budget-pass` only when preserving a structurally valid failing
baseline; the emitted `acceptance.passed` and failed trial paths still expose
the miss. Omit `--require-enforced` only for intentionally non-gating evidence
collection.

Each trial reports refresh-derived build, raster, total-span, and vsync-overhead
distributions and over-budget counts. It also reports build/raster work misses,
any-latency misses, and the longest consecutive streak for each category. The
acceptance gate uses build and raster p99 independently because those threads
are pipelined; total span and vsync overhead remain latency diagnostics.

Physical-device profile runs are the performance authority. A constrained
emulator is useful for compatibility, backpressure, and relative stress only;
host-shared CPU and software-rendering timings cannot certify Galaxy J5
performance. Neither a Galaxy S20 run nor an emulator proves exact Galaxy J5
or iPhone behavior; preserve the device metadata and qualify conclusions to the
hardware actually measured.
