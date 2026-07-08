#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# NetGent Data Capture
#
# Dual purpose:
#   * SOURCED (by start-netgent --capture): defines reusable helpers and does
#     nothing else. Helpers:
#       start_pcap / stop_pcap                      -- container-wide tcpdump
#       start_screen_capture / stop_screen_capture  -- per-display video +
#                                                      screenshots + Chrome net-log
#   * EXECUTED directly (legacy `capture-netgent <cli args>`): wraps a single
#     cli.py run with capture into $CAPTURE_DIR (default /capture), preserving
#     the original behavior.
# ============================================================================

SCREENSHOT_INTERVAL="${SCREENSHOT_INTERVAL:-2}"

# Derive ffmpeg WxH from RESOLUTION like "1920x1080x24" -> "1920x1080".
_video_size() {
  local r="${RESOLUTION:-3840x2160x24}"
  echo "${r%x*}"
}

# ---- container-wide packet capture (start once per container) --------------
_TCPDUMP_PID=""
start_pcap() {
  local outdir="$1" ts="$2"
  mkdir -p "$outdir/pcap"
  if command -v tcpdump &>/dev/null; then
    tcpdump -i any -w "$outdir/pcap/capture_${ts}.pcap" -U 2>/dev/null &
    _TCPDUMP_PID=$!
    echo "[capture] tcpdump PID $_TCPDUMP_PID -> $outdir/pcap/capture_${ts}.pcap"
  else
    echo "[capture] tcpdump not found - skipping pcap"
  fi
}
stop_pcap() {
  [ -n "${_TCPDUMP_PID:-}" ] && kill "$_TCPDUMP_PID" 2>/dev/null || true
  _TCPDUMP_PID=""
}

# ---- per-display screen capture (screenshots + video + net-log) ------------
# Sets _SHOT_PID/_FFMPEG_PID in the CURRENT shell scope and exports
# NETGENT_NET_LOG so the cli.py run that follows writes its Chrome net-log there.
# Call inside the same (sub)shell that will run cli.py.
# Usage: start_screen_capture <display> <outdir> <label> <ts>
_SHOT_PID=""
_FFMPEG_PID=""
start_screen_capture() {
  local disp="$1" outdir="$2" label="$3" ts="$4"
  mkdir -p "$outdir/screenshots"
  export NETGENT_NET_LOG="$outdir/chrome_netlog_${ts}.json"
  echo "[capture:$label] net-log -> $NETGENT_NET_LOG"

  ( COUNTER=0
    while true; do
      DISPLAY="$disp" scrot \
        "$outdir/screenshots/screenshot_$(printf '%04d' "$COUNTER")_${ts}.png" \
        2>/dev/null || true
      COUNTER=$((COUNTER + 1))
      sleep "$SCREENSHOT_INTERVAL"
    done ) &
  _SHOT_PID=$!
  echo "[capture:$label] screenshots PID $_SHOT_PID -> $outdir/screenshots/"

  if command -v ffmpeg &>/dev/null; then
    ffmpeg -y -f x11grab -video_size "$(_video_size)" -framerate 15 -i "$disp" \
      -c:v libx264 -preset ultrafast -crf 25 \
      "$outdir/recording_${ts}.mp4" </dev/null &>/dev/null &
    _FFMPEG_PID=$!
    echo "[capture:$label] recording PID $_FFMPEG_PID -> $outdir/recording_${ts}.mp4"
  else
    echo "[capture:$label] ffmpeg not found - skipping recording"
  fi
}
stop_screen_capture() {
  [ -n "${_SHOT_PID:-}" ] && kill "$_SHOT_PID" 2>/dev/null || true
  if [ -n "${_FFMPEG_PID:-}" ]; then
    kill -INT "$_FFMPEG_PID" 2>/dev/null || true   # let ffmpeg finalize the mp4
    sleep 2
    kill "$_FFMPEG_PID" 2>/dev/null || true
  fi
  _SHOT_PID=""; _FFMPEG_PID=""
}

# ---- Legacy direct execution: `capture-netgent <cli args>` -----------------
# Only runs when executed, not when sourced.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  CAPTURE_DIR="${CAPTURE_DIR:-/capture}"
  DISPLAY="${DISPLAY:-:99}"
  TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

  mkdir -p "$CAPTURE_DIR"
  echo "=== NetGent Data Capture (single run) ==="
  echo "Output directory: $CAPTURE_DIR"
  echo "Timestamp: $TIMESTAMP"

  start_pcap "$CAPTURE_DIR" "$TIMESTAMP"
  start_screen_capture "$DISPLAY" "$CAPTURE_DIR" "run" "$TIMESTAMP"

  cleanup() {
    echo ""
    echo "=== Stopping capture processes ==="
    stop_screen_capture
    stop_pcap
    wait 2>/dev/null || true
    echo "=== Capture Summary ==="
    ls -lhR "$CAPTURE_DIR" 2>/dev/null || true
    echo "=== Capture complete ==="
  }
  trap cleanup EXIT INT TERM

  echo ""
  echo "Running NetGent CLI..."
  echo "======================================================="
  python3 /home/agent/app/src/netgent/cli.py "$@"
fi
