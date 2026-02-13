#!/usr/bin/env bash
set -euo pipefail

getopt() { tmux show-option -gqv "$1"; }

state_dir="$(getopt '@fluximux_state_dir')"
: "${state_dir:=${XDG_CACHE_HOME:-$HOME/.cache}/fluximux}"
mkdir -p "$state_dir"

run_flag="$state_dir/speedtest.running"
down_flag="$state_dir/speedtestdown"
up_flag="$state_dir/speedtestup"

# Mark overall running state
touch "$run_flag"

cleanup() {
  rm -f "$run_flag" "$down_flag" "$up_flag"
}
trap cleanup EXIT

# ----------------------------
# Stage 1: Download only
# ----------------------------
touch "$down_flag"
speedtest-cli --no-upload --simple > /dev/null 2>&1
rm -f "$down_flag"

# ----------------------------
# Stage 2: Upload only
# ----------------------------
touch "$up_flag"
speedtest-cli --no-download --simple > /dev/null 2>&1
rm -f "$up_flag"
