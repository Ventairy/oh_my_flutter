#!/usr/bin/env bash

set -euo pipefail

flutter_version="$(jq -er '.flutter | select(type == "string" and length > 0)' .fvmrc)"
fvm_version=4.3.0
version_directory="$PWD/.fvm/versions/$flutter_version"

if [[ "$(fvm --version 2>/dev/null || true)" != "$fvm_version" ]]; then
  dart pub global activate fvm "$fvm_version"
fi

if [[ "${RUNNER_OS:-}" == Windows ]]; then
  pub_cache_bin="$(cygpath -u "$PUB_CACHE")/bin"
else
  pub_cache_bin="${PUB_CACHE:-$HOME/.pub-cache}/bin"
fi
export PATH="$pub_cache_bin:$PATH"

if [[ "$(fvm --version)" != "$fvm_version" ]]; then
  echo "Expected FVM $fvm_version, found $(fvm --version)." >&2
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

installed_version="$(fvm flutter --version --machine | jq -er '.frameworkVersion')"
if [[ "$installed_version" != "$flutter_version" ]]; then
  echo "Expected Flutter $flutter_version, found $installed_version." >&2
  exit 1
fi
