#!/bin/sh
set -eu

task_package_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
task_temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/particle-disintegrate-native.XXXXXX")
trap 'rm -rf "$task_temp_dir"' EXIT HUP INT TERM

clang \
  -std=c11 -O3 -Wall -Wextra -Werror \
  -ffp-contract=off -fsanitize=address,undefined -fno-omit-frame-pointer \
  "$task_package_dir/android/src/main/cpp/motion/particle_geometry.c" \
  "$task_package_dir/test/native/motion/particle_geometry_test.c" \
  -lm -o "$task_temp_dir/particle_geometry_test"
"$task_temp_dir/particle_geometry_test"
sh "$task_package_dir/tool/test_motion_lifecycle.sh"
