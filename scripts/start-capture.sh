#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# NetGent Startup with Data Capture
# Same as start.sh but launches capture.sh instead of cli.py directly.
# ============================================================================

export RESOLUTION="${RESOLUTION:-1920x1080x24}"
export NOVNC_PORT="${NOVNC_PORT:-8080}"
export VNC_PORT="${VNC_PORT:-5900}"
export VNC_LISTEN_HOST="${VNC_LISTEN_HOST:-localhost}"

USE_VDISPLAY=0
for arg in "$@"; do
  case "$arg" in
    -s|--screen)
      USE_VDISPLAY=1
      ;;
  esac
done

if [ "$USE_VDISPLAY" -eq 1 ]; then
  echo "Starting VNC/noVNC setup..."
  export DISPLAY="${DISPLAY:-:99}"
  Xvfb "$DISPLAY" -screen 0 "$RESOLUTION" &
  sleep 2

  fluxbox 2>/dev/null &
  sleep 1

  echo "Starting x11vnc on port $VNC_PORT (view-only mode)..."
  if [ -n "${VNC_PASSWORD:-}" ]; then
    x11vnc -display "$DISPLAY" -bg -forever -quiet \
            -listen "$VNC_LISTEN_HOST" -xkb -nodpms -viewonly \
            -rfbport "$VNC_PORT" -passwd "$VNC_PASSWORD" &
  else
    x11vnc -display "$DISPLAY" -bg -forever -nopw -quiet \
            -listen "$VNC_LISTEN_HOST" -xkb -nodpms -viewonly \
            -rfbport "$VNC_PORT" &
  fi
  sleep 1

  echo "Starting websockify on port $NOVNC_PORT..."
  cd /opt/noVNC/utils/websockify || { echo "ERROR: Cannot find /opt/noVNC/utils/websockify"; exit 1; }

  WEBSOCKIFY_PID=""
  if [ -f "websockify.py" ]; then
    echo "Using websockify.py..."
    python3 websockify.py --web /opt/noVNC 0.0.0.0:$NOVNC_PORT localhost:$VNC_PORT > /tmp/websockify.log 2>&1 &
    WEBSOCKIFY_PID=$!
  elif python3 -c "import websockify" 2>/dev/null; then
    echo "Using python3 -m websockify..."
    python3 -m websockify --web /opt/noVNC 0.0.0.0:$NOVNC_PORT localhost:$VNC_PORT > /tmp/websockify.log 2>&1 &
    WEBSOCKIFY_PID=$!
  else
    echo "ERROR: websockify not found. Trying alternative..."
    python3 -m websockify --web /opt/noVNC $NOVNC_PORT localhost:$VNC_PORT > /tmp/websockify.log 2>&1 &
    WEBSOCKIFY_PID=$!
  fi

  sleep 3

  if [ -n "$WEBSOCKIFY_PID" ] && ps -p $WEBSOCKIFY_PID > /dev/null 2>&1; then
    echo "websockify is running (PID: $WEBSOCKIFY_PID)"
  else
    echo "WARNING: websockify may not have started correctly"
    if [ -f /tmp/websockify.log ]; then
      tail -20 /tmp/websockify.log
    fi
  fi

  if netstat -tuln 2>/dev/null | grep -q ":$NOVNC_PORT " || ss -tuln 2>/dev/null | grep -q ":$NOVNC_PORT "; then
    echo "Port $NOVNC_PORT is listening"
  else
    echo "WARNING: Port $NOVNC_PORT may not be listening."
    ps aux | grep -E 'websockify|x11vnc' | grep -v grep || echo "No VNC processes found"
  fi

  echo "VNC/noVNC should be accessible at http://localhost:$NOVNC_PORT"
else
  export DISPLAY="${DISPLAY:-:99}"
  Xvfb "$DISPLAY" -screen 0 "$RESOLUTION" &
  sleep 2
  fluxbox 2>/dev/null &
  sleep 1
fi

mkdir -p /run/sshd
/usr/sbin/sshd

# Launch the capture wrapper instead of cli.py directly
exec /usr/local/bin/capture-netgent "$@"
