#!/bin/zsh

set -euo pipefail

arguments="$*"
if [[ "$arguments" == 'simctl list devicetypes --json' ]]; then
  print -r -- '{"devicetypes":[{"productFamily":"iPhone","modelIdentifier":"iPhone18,1","minRuntimeVersion":1703936}]}'
elif [[ "$arguments" == 'simctl list devices available --json' ]]; then
  print -r -- '{"devices":{}}'
else
  exit 1
fi
