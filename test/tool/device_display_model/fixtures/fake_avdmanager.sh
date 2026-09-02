#!/usr/bin/env bash

set -euo pipefail

printf 'Available Android Virtual Devices:\n'
printf '    Name: anonymous-fixture\n'
printf '    Path: %s\n' "${OMF_FAKE_AVD_PATH:?}"
if [[ -n ${OMF_FAKE_SECOND_AVD_PATH:-} ]]; then
  printf '    Name: anonymous-fixture-second\n'
  printf '    Path: %s\n' "${OMF_FAKE_SECOND_AVD_PATH}"
fi
