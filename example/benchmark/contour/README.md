# Contour benchmark

Use a physical device and a profile build. For older Android hardware, explicitly
select Skia:

```sh
cd example
fvm flutter run --profile --no-enable-impeller \
  --target benchmark/contour/main.dart --device-id <device-id>
```

The benchmark emits one chunked JSON result after 120 cold frames and
300 steady frames. The `schema` field is `2`. A run with
`--dart-define=CONTOUR_ENABLED=false` is the undecorated baseline. Match every
other option between baseline and decorated runs.

The small workload uses alternating text and icons in fixed 48-by-48 logical
pixel cells. Changing the count never changes the font or icon size. Decorated
and undecorated runs have exactly the same cells, spacing, content, and parent
transforms. A workload that does not fit the viewport emits
`CONTOUR_BENCHMARK_ERROR` instead of silently scaling or hiding samples.
Schema 2 uses different content and layout from the original benchmark; do not
compare its numbers with schema 1.

Android devices may truncate individual Flutter log entries at about 1 KB.
Results therefore always use this protocol:

```text
CONTOUR_BENCHMARK_BEGIN {"chunks":3,"characters":1520}
CONTOUR_BENCHMARK_CHUNK 1/3 <first 600 JSON characters>
CONTOUR_BENCHMARK_CHUNK 2/3 <next 600 JSON characters>
CONTOUR_BENCHMARK_CHUNK 3/3 <remaining JSON characters>
CONTOUR_BENCHMARK_END
```

Strip each logcat prefix, collect chunk payloads in numeric order, concatenate
without adding whitespace or line breaks, then parse the reconstructed JSON.
Verify every index from 1 through the declared count is present exactly once,
the end marker exists, and the reconstructed character count matches the begin
record. Reject incomplete runs. Payloads are at most 600 characters and wait 8 ms between chunks after the
measurements are captured, allowing Android logging buffers to drain. The full
JSON is never also emitted as a potentially truncated single line. Each run
should use a fresh process and its own log capture to avoid mixing chunks.

## Workloads

Set `--dart-define=CONTOUR_WORKLOAD=<name>`:

| Name | Work measured |
| --- | --- |
| `static` | Unchanged artwork and backing while the ticker requests frames |
| `translation` | Translation of the complete composition |
| `rotation` | Rotation of the complete composition |
| `combined` | Translation and rotation together; the default |
| `amount` | Contour amount varying continuously from 1 to 7 logical pixels |
| `content` | All labels and icons change at a fixed elapsed-time cadence |

Additional independent options:

| Define | Default | Meaning |
| --- | --- | --- |
| `CONTOUR_COLOR` | `ffffffff` | Eight hexadecimal ARGB digits for contour paint |
| `CONTOUR_ENABLED` | `true` | Include contours |
| `CONTOUR_COUNT` | `20` | Number of fixed-size small widgets; also test 40 and 80 |
| `CONTOUR_SHADOWS` | `true` | Include one blurred, offset contour shadow |
| `CONTOUR_UNIQUE` | `false` | Use distinct artwork in every small cell, up to 80 cells |
| `CONTOUR_LARGE` | `false` | Replace the grid with one 56-point label |
| `CONTOUR_UPDATES` | `false` | Also refresh content during any workload |
| `CONTOUR_UPDATE_MS` | `1500` | Elapsed milliseconds between content refreshes |
| `CONTOUR_COLD_FRAMES` | `120` | Number of frames in the cold phase |
| `CONTOUR_STEADY_FRAMES` | `300` | Number of frames in the steady phase |
| `CONTOUR_DIAGNOSTICS` | `false` | Separately sample shape readiness |
| `CONTOUR_DELAY_MS` | `0` | Delay mounting and measuring the workload |

Content changes follow elapsed wall time rather than delivered frame count. A
slow run therefore cannot appear cheaper simply by refreshing less often.
`refreshes_requested` reports the actual number of update requests.

Use `unique=true` (or `CONTOUR_UNIQUE=true`) when checking whether an improvement
also benefits varied artwork. At count 40 it displays text `T0` through `T19`
and 20 distinct constant Material icons; count 80 uses 40 labels and 40 icons.
The font, icon sizes, cells, and transforms stay the same. Content refreshes
alternate label prefixes and rotate the icon assignments. This option affects
the small grid; the large-label workload is unchanged. The JSON records `unique`.
The default `false` preserves the original repeated text/icon workload. Future
shared-cache comparisons must pair baseline and candidate runs for **both**
unique and repeated artwork, with matching settings, so repeated shapes alone
cannot account for the reported gain.

Use the runtime query `generic=true` to replace glyphs with small composite
widgets made from rounded boxes and circles. This exercises the generic contour
path instead of native text/icon rendering. It keeps the same fixed cells and
supports `unique=true` and content refreshes. Match `generic` between baseline
and candidate; comparing different artwork does not isolate an optimization.
The default is `false`, and the result records `generic`.


## Reusing one Android APK

An Android launch route overrides the compile-time defaults without rebuilding.
Force-stop between runs so the engine and Dart static configuration restart:

```sh
adb -s <device-id> shell am force-stop dev.ventairy.oh_my_flutter_example
adb -s <device-id> shell "am start -n dev.ventairy.oh_my_flutter_example/.MainActivity --ez enable-impeller false --es route '/?enabled=true&workload=rotation&count=80&shadows=true&delayMs=5000&cpumask=1'"
```

Query keys are `enabled`, `workload`, `count`, `shadows`, `large`, `updates`,
`updateMs`, `coldFrames`, `steadyFrames`, `diagnostics`, `delayMs`, `unique`, `generic`, `warmReuse`, and
`contourColor`. `contourColor` accepts exactly eight ARGB hexadecimal digits
without a prefix, such as `ff000000` for opaque black; the default is white and
the JSON records the normalized value as `contour_color`. Boolean
values are `true` or `false`. The five-second delay leaves time to inspect the
process before the workload is mounted; it is excluded from the reported elapsed
time. `CONTOUR_BENCHMARK_START` marks the measurement start.

The optional Android-only `cpumask` query takes a hexadecimal Linux CPU affinity
mask: `1` requests CPU 0, while `f` requests CPUs 0–3. Verify the device's CPU
layout before choosing a mask. This benchmark calls `sched_setaffinity` inside
its own process for every existing thread, both before the delay and immediately
before measurement. New threads normally inherit affinity from their creator.
The final JSON includes compact affinity summaries: requested mask, thread count,
allowed CPU-list counts, whether every observed thread was restricted to the
requested CPU set, and syscall failures when applying the policy. Per-thread
kernel results appear separately as `CONTOUR_BENCHMARK_AFFINITY_THREAD` JSON
records, with an `init`, `start`, or `end` phase. Each line stays short enough for
Android logcat; thread tables are never embedded in the main result. Check these
records: a requested mask by itself does not prove that affinity applied.
No device-wide CPU policy changes are made; restarting the process resets its
affinity. Omit `cpumask` for an unrestricted run. The FFI helper is benchmark-only
and adds no production dependency or code path.

## Collecting Android runs

The standard-library Python runner starts a fresh app process, requests Skia,
verifies every result chunk and its character count, and saves a JSON record
alongside the raw `.log`. Run it from the repository root with a unique output
filename for each repetition:

```sh
python3 example/benchmark/contour/run_android.py \
  --adb /path/to/adb --device <device-id> \
  --apk example/build/app/outputs/flutter-apk/app-profile.apk --install \
  --label optimized-rotation-40-little-01 \
  --route '/?enabled=true&workload=rotation&count=40&delayMs=5000&cpumask=f' \
  --output /tmp/contour-results/optimized-rotation-40-little-01.json
```

Omit `--install` to reuse the installed build; `--apk` still checks its hash
against the installed APK. Both flags may be omitted when the installed APK can
be hashed directly. Records include artifact hashes, runner-workspace revision/SDK metadata,
model and Android API level, before/after thermal, battery, frequency, and screen
metadata, plus final actual CPU affinity. If requested affinity is not verified
for every thread, the run fails and preserves its result for diagnosis.

The default capture timeout is 240 seconds; change it with `--timeout`. Errors,
timeouts, and interruption retain metadata and logs, and the runner stops its
logcat process and force-stops the benchmark in cleanup. Existing output files
are never overwritten. No device-wide settings or log buffers are changed.
Use `--trace-skia` only for a separate diagnostic run with an attached engine
trace collector; it enables Skia trace events but this runner itself collects
logcat and frame results. `--impeller` requests an Impeller comparison instead.

For final reproducibility, resolve dependencies first, then freeze allowlisted
build inputs **before** building. Use the same source tree, renderer, and explicit
build defines for the APK. Verify the snapshot again after the build:

```sh
python3 example/benchmark/contour/source_manifest.py \
  --output /tmp/contour-frozen-source.json --renderer skia \
  --define CONTOUR_COUNT=40
# Build the APK from these unchanged inputs and the same defines.
python3 example/benchmark/contour/source_manifest.py \
  --verify /tmp/contour-frozen-source.json
```

The commands print the frozen manifest SHA-256. Add
`--source-manifest /tmp/contour-frozen-source.json` and
`--source-manifest-sha256 <printed-sha256>` to `run_android.py`; validation happens
before contacting adb. The manifest hashes package, native/hook, shader/asset,
benchmark, dependency, and Android build inputs using relative allowlisted names.
Use `--root` when freezing a different checkout, and keep the output outside its
build inputs. Snapshots are never overwritten. Changes to an input or SDK make
verification fail.

Runner-workspace metadata identifies the runner, **not the APK's source**.
The supplied frozen snapshot and independently checked APK hash are separate
provenance records; this is not cryptographic proof that the APK was built from
that snapshot. Preserve both with the exact build command.

The framing parser and source-manifest validation have offline regression tests
that do not access a device:


```sh
python3 -m unittest discover -s example/benchmark/contour -p '*_test.py'
```

## Interpreting results

`implementation_at_end` is sampled once after the frame window, even when
readiness polling is disabled. It reports compact counts, state histograms, and
resource reuse without serializing source objects or per-owner tables. Shared
process counters—including native picture caches, shadow pools, and admission
bytes—use `global_max`; per-contour work uses `owner_totals`. Missing optional
fields remain absent so older baseline builds remain comparable.

The record includes build/raster p50, p90, p99 and maximum durations, total frame
span p99, vsync gap p99, observed phase duration, display refresh rate, pixel
ratio, viewport, and elapsed wall time. Durations are in microseconds.

`stage_over_budget_frames` counts frames where either build or raster exceeds
the display's frame budget. It is not the sum of those stages: Flutter pipelines
them. `estimated_missed_vsync_slots` sums rounded gaps between successive frame
vsync timestamps beyond one refresh period. This is an estimate of presentation
opportunities, not a hardware compositor measurement. Inspect both metrics and
the duration percentiles. Cold timings include framework and application startup;
they do not isolate shape generation.

For a separate readiness run, set `CONTOUR_DIAGNOSTICS=true`. This polls each
Contour's existing render diagnostics every 20 ms and reports the observed time
until all initial contour paths are ready, per-instance initial p50/p99,
completed refresh p99, superseded refreshes, and total captures. Readiness means
the first usable contour path exists (`contourReady`); it does not wait for any
optional background cache preparation. The result records
`ready_definition: "first_contour_path"` so runs with different definitions can
be distinguished. Initial latency starts when the delayed workload starts;
refresh latency starts at the content update request. It includes capture,
processing, and scheduling. The polling interval
and scheduling add measurement error. A pending refresh or incomplete initial
capture is represented by missing/null latency rather than zero.

Only accept readiness records with `probe_version: 2` or later. Earlier APKs
used Flutter's default diagnostics builder, whose property collection is disabled
when assertions are off. Their zero ready-instance and capture counts are invalid
profile diagnostics, rather than evidence that contours failed to appear. The
benchmark now retains these fields with its own builder; actual device profile
runs must still validate that the ready-instance count matches the workload.

Readiness diagnostics add CPU work and allocations. Keep them **off** for frame
performance comparisons and enable them in separate paired runs. Static mode
still requests frames and performs a small transform-builder update; it measures
unchanged content during an active application, not idle battery consumption.

## First appearance diagnostics

Use a separate static run to measure how soon the child and contour arrive
together. Static mode keeps amount at 4 logical pixels. Test counts 1, 20, and
40 in fresh processes with the same settings, for example:

```text
/?enabled=true&workload=static&count=40&diagnostics=true&delayMs=2000
```

`presentation_readiness` samples existing renderer diagnostics after each frame,
independently of the older 20 ms path-ready timer. For each owner it records the
first main composition containing visible content, whether that composition also
contains its contour, and the first composition containing both. Own source
readbacks and preflight checks do not count as visible compositions. Do not take
export screenshots during the timed run.

First composition frame IDs are matched to `FrameTiming.frameNumber`. Reported
latency ends at that frame's **raster finish**, relative to the content request
using the engine timeline clock. It is not a measurement of hardware display,
scanout, or user-perceived presentation. The result includes matched-instance
counts and p50, p99, and all-instance latency. Missing diagnostics, negative frame
IDs, absent timings, or incompatible clock samples produce incomplete/unsupported
status and null latency rather than zero. At most 2,048 timing records are kept;
already matched first-appearance values survive later eviction.

Blank compositions before the first pair and child-only compositions are counted
separately, once per owner and observed frame. Their totals sum owner observations,
while their maximum is the highest count for one owner. A retained layer may not
report a new composition; an absent callback is never assumed to be a blank
frame. Inspect `observed_instances` and `composition_observations` alongside these
counts. `child_only_observed=true` records a visible content-without-contour
failure. Zero child-only observations by itself does not establish fast arrival:
also inspect blank counts and paired raster-finish latency.

Add `warmReuse=true` to the same diagnostics-only static run to remount the same
artwork once, with fresh Contour owners, after the initial paired compositions
and initial path-ready observation, once background preparation reports idle. The result separates `initial` and
`warm_reuse` phases, each with its own request timestamp and frame matches. The delay before
requesting the warm remount is reported separately; it is not warm arrival
latency. Very short runs can finish before remount and report `not_started`.
This option keeps one excluded, offstage transparent Contour attached to preserve
the active-consumer cache/worker lifetime across remount; it performs no capture
and is absent from sample counts. Without an active owner, disposing the complete
grid can clear caches and would not measure warm reuse. Initial and final actual
implementation summaries allow checking whether reuse occurred; it is never
assumed from the option alone. `warmReuse` requires enabled contours, diagnostics,
static mode, and no content updates. A warm remount is not a cold process launch.

Keep diagnostics disabled for headline build/raster comparisons. In a warm-reuse
run, the ordinary cold/steady frame windows include both diagnostic phases and
must not be interpreted as an isolated steady-performance comparison.

## Repeatable device runs

Use the same renderer, resolution, orientation, refresh rate, battery/charging
state, workload, and CPU-affinity policy for every pair. Alternate baseline and
decorated runs and repeat each pair; retain raw JSON records and report variation.
Record device model, Android version, Flutter revision, source revision, selected
CPU IDs, available CPU frequency policy, and thermal state with the results.
Inspect log output for layout errors and rendering failures before accepting a
record. Preserve the device's original settings and restore them afterwards.

Restricting an S20 to its efficiency cores can expose CPU bottlenecks, but does
not reproduce a Galaxy J5's GPU, memory bandwidth, driver behavior, RAM capacity,
or CPU architecture. CPU affinity also may require permissions unavailable on a
stock device. Use emulator results for repeatable regression comparisons, not
as evidence that a specific physical low-end device sustains a frame rate.
