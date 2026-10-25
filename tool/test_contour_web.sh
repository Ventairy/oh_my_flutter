#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"
assets_link="$repository_root/test/widgets/contour/assets"
if [[ -e "$assets_link" || -L "$assets_link" ]]; then
  echo "Refusing to replace existing Contour test assets: $assets_link" >&2
  exit 1
fi

sdk="$repository_root/.fvm/flutter_sdk"
flutter="$sdk/bin/flutter"
if [[ ! -x "$flutter" ]]; then
  echo "The tracked FVM SDK is missing. Run fvm install first." >&2
  exit 1
fi
case "$(uname -s)" in
  Darwin) host=darwin-x64 ;;
  Linux)
    case "$(uname -m)" in
      x86_64|amd64) host=linux-x64 ;;
      aarch64|arm64) host=linux-arm64 ;;
      riscv64) host=linux-riscv64 ;;
      *) echo "Unsupported Linux shader compiler architecture." >&2; exit 1 ;;
    esac
    ;;
  *) echo "This browser-test workflow requires macOS or Linux." >&2; exit 1 ;;
esac
compiler="$sdk/bin/cache/artifacts/engine/$host/impellerc"
if [[ ! -x "$compiler" ]]; then
  echo "The tracked SDK shader compiler is missing: $compiler" >&2
  exit 1
fi
command -v python3 >/dev/null || { echo "Python 3 is required by this test tool." >&2; exit 1; }

generated_directory=''
link_target=''
command_pid=''
cleanup() {
  local status=$?
  trap - EXIT
  if [[ -n "$link_target" && -L "$assets_link" && "$(readlink "$assets_link")" == "$link_target" ]]; then
    rm -- "$assets_link" || { if [[ "$status" == 0 ]]; then status=1; fi; }
  fi
  if [[ -n "$generated_directory" ]]; then
    rm -rf -- "$generated_directory" || { if [[ "$status" == 0 ]]; then status=1; fi; }
  fi
  exit "$status"
}
stop() {
  trap - INT TERM
  if [[ -n "$command_pid" ]]; then
    kill -TERM "$command_pid" 2>/dev/null || true
    wait "$command_pid" 2>/dev/null || true
  fi
  exit "$1"
}
run_command() {
  local status=0
  "$@" &
  command_pid=$!
  wait "$command_pid" || status=$?
  command_pid=''
  return "$status"
}
trap cleanup EXIT
trap 'stop 130' INT
trap 'stop 143' TERM

mkdir -p "$repository_root/lib/src/gen"
generated_directory="$(mktemp -d "$repository_root/lib/src/gen/contour_web_test_assets.XXXXXX")"
mkdir "$generated_directory/shaders"
shader="$generated_directory/shaders/contour_shadow_atlas.frag"
run_command "$compiler" --sksl --iplr --json \
  "--sl=$shader" "--spirv=$shader.spirv" \
  "--input=$repository_root/shaders/contour_shadow_atlas.frag" --input-type=frag \
  "--include=$repository_root/shaders" "--include=$(dirname "$compiler")/shader_lib"
if [[ ! -s "$shader" ]]; then
  echo "The shader compiler did not produce a browser fixture." >&2
  exit 1
fi
link_target="../../../lib/src/gen/${generated_directory##*/}"
# Unlike ln, this refuses a destination created concurrently, including a
# directory, rather than placing an extra link inside somebody else's assets.
python3 -c 'import os, sys; os.symlink(sys.argv[1], sys.argv[2])' "$link_target" "$assets_link"

# Additional Flutter arguments can filter these suites or add test files.
run_command "$flutter" test --ipv6 --platform chrome \
  test/widgets/contour/contour_declared_source_test.dart \
  test/widgets/contour/contour_known_box_source_test.dart \
  test/widgets/contour/contour_known_box_shadow_test.dart \
  test/widgets/contour/render_contour_processor_lifecycle_test.dart \
  "$@"
