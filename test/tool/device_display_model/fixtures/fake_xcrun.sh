#!/usr/bin/env bash

set -euo pipefail

arguments="$*"
if [[ "$arguments" == 'simctl list devicetypes --json' ]]; then
  printf '%s\n' '{"devicetypes":[{"productFamily":"iPhone","modelIdentifier":"iPhone18,1","minRuntimeVersion":1703936}]}'
elif [[ "$arguments" == 'simctl list devices available --json' ]]; then
  printf '%s\n' '{"devices":{}}'
else
  exit 1
fi
