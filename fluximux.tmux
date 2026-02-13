#!/usr/bin/env bash

getopt() { tmux show-option -gqv "$1"; }
is_true() { [ "$1" = "true" ] || [ "$1" = "1" ] || [ "$1" = "yes" ] || [ "$1" = "on" ]; }

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

enable_prefix="$(getopt '@fluximux_enable_prefix_binds')"
enable_alt="$(getopt '@fluximux_enable_alt_binds')"
: "${enable_prefix:=true}"
: "${enable_alt:=true}"

# Prefix binding key (e.g. <prefix> + q)
p_speedtest="$(getopt '@fluximux_speedtest_key')"
: "${p_speedtest:=q}"

# Alt binding key (e.g. <Alt> + q)
a_speedtest="$(getopt '@fluximux_alt_speedtest_key')"
: "${a_speedtest:=M-q}"

cmd_speedtest="$CURRENT_DIR/scripts/flux_speedtest.sh"

# IMPORTANT: -b runs in the background so tmux doesn't block
if is_true "$enable_prefix"; then
  tmux bind-key "$p_speedtest" run-shell -b "$cmd_speedtest"
fi

if is_true "$enable_alt"; then
  tmux bind-key -n "$a_speedtest" run-shell -b "$cmd_speedtest"
fi
