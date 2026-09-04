#!/usr/bin/env bash

set -euo pipefail

flutter_version="$(jq -er '.flutter | select(type == "string" and length > 0)' .fvmrc)"
fvm_version=4.3.0
version_directory="$PWD/.fvm/versions/$flutter_version"

dart pub global activate fvm "$fvm_version"

if [[ "${RUNNER_OS:-}" == Windows ]]; then
  pub_cache_bin="$(cygpath -u "$PUB_CACHE")/bin"
  flutter_executable="$(cygpath -u "$FLUTTER_ROOT")/bin/flutter.bat"
else
  pub_cache_bin="${PUB_CACHE:-$HOME/.pub-cache}/bin"
  flutter_executable="$FLUTTER_ROOT/bin/flutter"
fi
export PATH="$pub_cache_bin:$PATH"

if [[ -n "${GITHUB_PATH:-}" ]]; then
  if [[ "${RUNNER_OS:-}" == Windows ]]; then
    github_path_file="$(cygpath -u "$GITHUB_PATH")"
    cygpath -w "$pub_cache_bin" >> "$github_path_file"
  else
    echo "$pub_cache_bin" >> "$GITHUB_PATH"
  fi
fi

installed_fvm_version="$(dart pub global run fvm:main --version)"
if [[ "$installed_fvm_version" != "$fvm_version" ]]; then
  echo "Expected FVM $fvm_version, found $installed_fvm_version." >&2
  exit 1
fi

mkdir -p "$PWD/.fvm/versions"

if [[ ! -e "$version_directory" ]]; then
  if [[ "${RUNNER_OS:-}" == Windows ]]; then
    windows_version_directory="$(cygpath -w "$version_directory")"
    cmd //c "mklink /J \"$windows_version_directory\" \"$FLUTTER_ROOT\""
  else
    ln -s "$FLUTTER_ROOT" "$version_directory"
  fi
fi

installed_version="$("$flutter_executable" --version --machine | jq -er '.frameworkVersion')"
if [[ "$installed_version" != "$flutter_version" ]]; then
  echo "Expected Flutter $flutter_version, found $installed_version." >&2
  exit 1
fi
