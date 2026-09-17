#!/usr/bin/env bash
# Preserve the command's exit status while reporting elapsed time on failure too.
set -uo pipefail
label="${1:?Usage: time_command.sh label command [arguments...]}"
shift
started=$SECONDS
"$@"
result=$?
echo "$label: $((SECONDS - started))s (exit $result)"
exit "$result"
