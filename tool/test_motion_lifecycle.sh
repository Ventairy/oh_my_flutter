#!/bin/sh
set -eu

task_package_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
task_temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/particle-disintegrate-lifecycle.XXXXXX")
trap 'rm -rf "$task_temp_dir"' EXIT HUP INT TERM

find "$task_package_dir/test/native/motion/lifecycle" -name '*.java' -print > "$task_temp_dir/sources"
for task_source in DisintegrateScene DisintegrateOutput DisintegrateConfiguration RenderTimings; do
    printf '%s\n' "$task_package_dir/android/src/main/java/dev/ventairy/oh_my_flutter/motion/$task_source.java" >> "$task_temp_dir/sources"
done

javac --release 17 -d "$task_temp_dir/classes" @"$task_temp_dir/sources"
java -cp "$task_temp_dir/classes" dev.ventairy.oh_my_flutter.motion.DisintegrateSceneLifecycleTest
java -cp "$task_temp_dir/classes" dev.ventairy.oh_my_flutter.motion.DisintegrateOutputLifecycleTest
java -cp "$task_temp_dir/classes" dev.ventairy.oh_my_flutter.motion.DisintegrateModernOutputTest
