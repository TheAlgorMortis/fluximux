#!/usr/bin/env bash
set -u

# ---------------------------
# A script to ouput internet speed status written by Dylan James Reid with a lot
# of help from chatGPT. Output is formatted for a tmux status bar.
# - Displays typical upload and download based on what you're busy doing on the
# fly
# - Displays an exclamation mark if there is no internet connection
# - when the user prompts it, it will perform an internet speed test, which the
# status will indicate.
# ---------------------------

getopt() { tmux show-option -gqv "$1"; }

# ---------------------------
# Theme (user-editable)
# ---------------------------
c_bg="$(getopt '@fluximux_c_bg_main')"
c_purple="$(getopt '@fluximux_c_purple')"
c_red="$(getopt '@fluximux_c_red')"
c_yellow="$(getopt '@fluximux_c_yellow')"

: "${c_bg:=#250025}"
: "${c_purple:=#C055F7}"
: "${c_red:=#EF4444}"
: "${c_yellow:=#FACC15}"

logo_override="$(getopt '@fluximux_logo')"
: "${logo_override:=}"

# ---------------------------
# Separator style
# ---------------------------
sep_style="$(getopt '@fluximux_separator_style')"
: "${sep_style:=slanted}"

case "$sep_style" in
  slanted)
    SEP_L="◥"; SEP_R="◣"
    ;;
  straight)
    SEP_L=" "; SEP_R=" "
    ;;
  pointed)
    SEP_L=""; SEP_R=""
    ;;
  rounded)
    SEP_L=""; SEP_R=""
    ;;
  *)
    SEP_L="◥"; SEP_R="◣"
    ;;
esac

# ---------------------------
# State dir
# ---------------------------
state_dir="$(getopt '@fluximux_state_dir')"
: "${state_dir:=${XDG_CACHE_HOME:-$HOME/.cache}/fluximux}"
mkdir -p "$state_dir"

run_flag="$state_dir/speedtest.running"
down_flag="$state_dir/speedtestdown"
up_flag="$state_dir/speedtestup"

# ---------------------------
# Interface detection
# ---------------------------
iface="$(getopt '@fluximux_interface')"
if [ -z "${iface:-}" ]; then
  iface="$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"
fi

has_net=1
[ -z "${iface:-}" ] && has_net=0

read_bytes() {
  awk -v IFACE="$iface" '
    $0 ~ IFACE ":" {
      gsub(":", "", $1);
      rx=$2; tx=$10;
      print rx, tx;
      exit
    }' /proc/net/dev 2>/dev/null
}

fmt_mbs() {
  awk -v b="$1" '
    BEGIN{
      mb = (b * 8) / (1000000.0);
      printf "%5.1f", mb;
    }'
}

# ---------------------------
# Capsules
# ---------------------------
segment_logo() {
  local text="$1" accent="$2"
  : "${accent:=$c_purple}"
  printf "#[bg=default,fg=%s]%s#[bg=%s,fg=%s]%s#[bg=%s,fg=%s]%s#[bg=%s]" \
    "$accent" "$SEP_L" \
    "$accent" "$c_bg" "$text" \
    "$c_bg" "$accent" "$SEP_R" \
    "$c_bg"
}

segment_up() {
  local text="$1" accent="$2"
  : "${accent:=$c_purple}"
  printf "#[bg=%s,fg=%s]%s#[bg=%s,fg=%s]%s#[bg=%s,fg=%s]%s#[bg=default]" \
    "$accent" "$c_bg" "$SEP_R" \
    "$accent" "$c_bg" "$text" \
    "$c_bg" "$accent" "$SEP_R"
}

segment_down() {
  local text="$1" accent="$2"
  : "${accent:=$c_purple}"
  printf "#[bg=default,fg=%s]#[bg=%s,fg=%s]%s#[bg=%s,fg=%s]#[bg=%s]" \
    "$c_bg" "$c_bg" "$accent" "$text" "$c_bg" "$c_bg" "$c_bg"
}

# ---------------------------
# Decide accent + logo
# ---------------------------
accent="$c_purple"
logo=""
now="$(date +%s)"

speedtest_running=0
[ -e "$run_flag" ] && speedtest_running=1

if [ "$speedtest_running" -eq 1 ]; then
  accent="$c_red"
  if [ -e "$down_flag" ]; then
    logo="#[blink]▼#[noblink]"
  elif [ -e "$up_flag" ]; then
    logo="#[blink]▲#[noblink]"
  else
    logo="⧗"
  fi
else
  if [ "$has_net" -eq 0 ]; then
    accent="$c_yellow"
    logo="?"
  else
    logo="⇵"
  fi
fi

[ -n "$logo_override" ] && logo="$logo_override"

# ---------------------------
# Compute speeds
# ---------------------------
down_str="  0.0"
up_str="  0.0"

if [ "$has_net" -eq 1 ]; then
  read -r rx tx < <(read_bytes || echo "0 0")

  state_file="$state_dir/iface_${iface}.state"
  last_now="$now"; last_rx="$rx"; last_tx="$tx"

  if [ -f "$state_file" ]; then
    read -r last_now last_rx last_tx < "$state_file" || true
  fi

  dt=$(( now - last_now )); [ "$dt" -le 0 ] && dt=1
  drx=$(( rx - last_rx )); [ "$drx" -lt 0 ] && drx=0
  dtx=$(( tx - last_tx )); [ "$dtx" -lt 0 ] && dtx=0

  down_bps=$(( drx / dt ))
  up_bps=$(( dtx / dt ))

  printf "%s %s %s\n" "$now" "$rx" "$tx" > "$state_file"

  down_str="$(fmt_mbs "$down_bps")"
  up_str="$(fmt_mbs "$up_bps")"
fi

# ---------------------------
# Render
# ---------------------------
out="#[default]"
out+="$(segment_logo " ${logo} " "$accent")"
out+="$(segment_down " ↓${down_str} " "$accent")"
out+="$(segment_up " ↑${up_str} " "$accent")"
echo "$out"
