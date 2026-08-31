#!/bin/zsh

zmodload zsh/zselect

_omf_descendant_process_ids() {
  local parent_pid="$1"
  local child_pid
  local -a child_pids
  child_pids=("${(@f)$(/usr/bin/pgrep -P "$parent_pid" 2>/dev/null || true)}")
  for child_pid in "${child_pids[@]}"; do
    [[ "$child_pid" == <-> ]] || continue
    _omf_descendant_process_ids "$child_pid"
    print -r -- "$child_pid"
  done
}

run_with_timeout() {
  local seconds="$1"
  shift
  "$@" &
  local command_pid=$!
  local timeout_marker
  timeout_marker="$(mktemp "${TMPDIR:-/tmp}/omf-device-display-timeout.XXXXXX")"
  rm -f "$timeout_marker"
  (
    zselect -t $((seconds * 100)) || true
    : > "$timeout_marker"
    local descendant_output
    local -a descendant_pids
    descendant_output="$(_omf_descendant_process_ids "$command_pid")"
    if [[ -n "$descendant_output" ]]; then
      descendant_pids=("${(@f)descendant_output}")
    fi
    kill -TERM "$command_pid" "${descendant_pids[@]}" >/dev/null 2>&1 || true
    zselect -t 200 || true
    descendant_output="$(_omf_descendant_process_ids "$command_pid")"
    if [[ -n "$descendant_output" ]]; then
      descendant_pids+=("${(@f)descendant_output}")
    fi
    typeset -U descendant_pids
    kill -KILL "$command_pid" "${descendant_pids[@]}" >/dev/null 2>&1 || true
  ) >/dev/null 2>&1 &
  local timer_pid=$!
  local command_exit_code=0
  wait "$command_pid" || command_exit_code=$?
  if [[ -e "$timeout_marker" ]]; then
    wait "$timer_pid" >/dev/null 2>&1 || true
    rm -f "$timeout_marker"
    return 124
  fi
  kill "$timer_pid" >/dev/null 2>&1 || true
  wait "$timer_pid" >/dev/null 2>&1 || true
  rm -f "$timeout_marker"
  return "$command_exit_code"
}
