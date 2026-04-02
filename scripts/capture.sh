#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# NetGent Data Capture Wrapper
# Runs tcpdump, Chrome net-log, periodic screenshots, and screen recording
# alongside the NetGent CLI.
# ============================================================================

CAPTURE_DIR="${CAPTURE_DIR:-/capture}"
SCREENSHOT_INTERVAL="${SCREENSHOT_INTERVAL:-2}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DISPLAY="${DISPLAY:-:99}"

mkdir -p "$CAPTURE_DIR/screenshots" "$CAPTURE_DIR/pcap"

echo "=== NetGent Data Capture ==="
echo "Output directory: $CAPTURE_DIR"
echo "Timestamp: $TIMESTAMP"
echo ""

# Track PIDs for cleanup
TCPDUMP_PID=""
SCREENSHOT_PID=""
FFMPEG_PID=""

# ---- 1. tcpdump (packet capture) ----
PCAP_FILE="$CAPTURE_DIR/pcap/capture_${TIMESTAMP}.pcap"
if command -v tcpdump &>/dev/null; then
  echo "[1/4] Starting tcpdump..."
  tcpdump -i any -w "$PCAP_FILE" -U 2>/dev/null &
  TCPDUMP_PID=$!
  echo "  -> PID $TCPDUMP_PID, writing to $PCAP_FILE"
else
  echo "[1/4] SKIPPED: tcpdump not found"
fi

# ---- 2. Chrome net-log (via environment variable) ----
export NETGENT_NET_LOG="$CAPTURE_DIR/chrome_netlog_${TIMESTAMP}.json"
echo "[2/4] Chrome net-log will be written to $NETGENT_NET_LOG"

# ---- 3. Periodic screenshots ----
echo "[3/4] Starting screenshot capture (every ${SCREENSHOT_INTERVAL}s)..."
(
  COUNTER=0
  while true; do
    FILENAME="$CAPTURE_DIR/screenshots/screenshot_$(printf '%04d' $COUNTER)_${TIMESTAMP}.png"
    scrot "$FILENAME" 2>/dev/null || true
    COUNTER=$((COUNTER + 1))
    sleep "$SCREENSHOT_INTERVAL"
  done
) &
SCREENSHOT_PID=$!
echo "  -> PID $SCREENSHOT_PID"

# ---- 4. Screen recording (ffmpeg) ----
RECORDING_FILE="$CAPTURE_DIR/recording_${TIMESTAMP}.mp4"
if command -v ffmpeg &>/dev/null; then
  echo "[4/4] Starting screen recording..."
  ffmpeg -y -f x11grab -video_size 1920x1080 -framerate 15 -i "$DISPLAY" \
    -c:v libx264 -preset ultrafast -crf 25 \
    "$RECORDING_FILE" </dev/null &>/dev/null &
  FFMPEG_PID=$!
  echo "  -> PID $FFMPEG_PID, writing to $RECORDING_FILE"
else
  echo "[4/4] SKIPPED: ffmpeg not found"
fi

echo ""
echo "All capture processes started. Running NetGent CLI..."
echo "======================================================="
echo ""

# ---- Cleanup on exit ----
cleanup() {
  echo ""
  echo "=== Stopping capture processes ==="

  if [ -n "$SCREENSHOT_PID" ]; then
    kill "$SCREENSHOT_PID" 2>/dev/null || true
    echo "  Stopped screenshots"
  fi

  if [ -n "$FFMPEG_PID" ]; then
    # Send INT for clean ffmpeg shutdown (finalizes mp4)
    kill -INT "$FFMPEG_PID" 2>/dev/null || true
    # Give ffmpeg a moment to finalize the file
    sleep 2
    kill "$FFMPEG_PID" 2>/dev/null || true
    echo "  Stopped screen recording"
  fi

  if [ -n "$TCPDUMP_PID" ]; then
    kill "$TCPDUMP_PID" 2>/dev/null || true
    echo "  Stopped tcpdump"
  fi

  wait 2>/dev/null || true

  echo ""
  echo "=== Capture Summary ==="
  echo "Output directory: $CAPTURE_DIR"
  echo ""
  ls -lhR "$CAPTURE_DIR" 2>/dev/null || true
  echo ""
  echo "=== Capture complete ==="
}
trap cleanup EXIT INT TERM

# ---- Run the NetGent CLI ----
python3 /home/agent/app/src/netgent/cli.py "$@"
