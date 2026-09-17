#!/usr/bin/env bash

set -euo pipefail

setup_started=$SECONDS

flutter_version="$(jq -er '.flutter | select(type == "string" and length > 0)' .fvmrc)"
fvm_version=4.3.0
version_directory="$PWD/.fvm/versions/$flutter_version"
# FVM resolves versions through its cache, including from nested packages.
# A project-local versions link alone does not configure that cache.
export FVM_CACHE_PATH="$PWD/.fvm"
if [[ "${RUNNER_OS:-}" == Windows ]]; then
  export FVM_CACHE_PATH="$(cygpath -w "$FVM_CACHE_PATH")"
fi
if [[ -n "${GITHUB_ENV:-}" ]]; then
  environment_file="$GITHUB_ENV"
  if [[ "${RUNNER_OS:-}" == Windows ]]; then
    environment_file="$(cygpath -u "$environment_file")"
  fi
  echo "FVM_CACHE_PATH=$FVM_CACHE_PATH" >> "$environment_file"
fi

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

installed_fvm_version="$(dart pub global list | awk '$1 == "fvm" { print $2 }')"
if [[ "$installed_fvm_version" != "$fvm_version" ]]; then
  echo "Expected FVM $fvm_version, found $installed_fvm_version." >&2
  exit 1
fi

mkdir -p "$PWD/.fvm/versions"

if [[ ! -e "$version_directory" ]]; then
  if [[ "${RUNNER_OS:-}" == Windows ]]; then
    windows_version_directory="$(cygpath -w "$version_directory")"
    powershell.exe -NoProfile -NonInteractive -Command \
      "\$ErrorActionPreference = 'Stop'; New-Item -ItemType Junction -Path '$windows_version_directory' -Target '$FLUTTER_ROOT' | Out-Null"
  else
    ln -s "$FLUTTER_ROOT" "$version_directory"
  fi
fi

flutter_version_output="$("$flutter_executable" --version --machine)"
installed_version="$(awk 'found || /^\{/ { found = 1; print }' <<<"$flutter_version_output" | jq -er '.frameworkVersion')"
if [[ "$installed_version" != "$flutter_version" ]]; then
  echo "Expected Flutter $flutter_version, found $installed_version." >&2
  exit 1
fi

repository_root="$PWD"
for package in . example tool/country_bindings tool/device_location_bindings; do
  (
    cd "$repository_root/$package"
    fvm exec python3 "$repository_root/tool/ci/verify_sdk.py"
  )
done
echo "FVM setup and SDK verification: $((SECONDS - setup_started))s"
