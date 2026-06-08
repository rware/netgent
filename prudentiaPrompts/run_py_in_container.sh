#!/usr/bin/env bash
# Runs a NetGent Python SDK script INSIDE the netgent container.
# Sets up a virtual display (+ optional noVNC live view on :8080), then execs
# `python3 <script>`. Intended to be the container command via --entrypoint bash.
#
# Usage (inside container): run_py_in_container.sh /path/to/script.py
set -euo pipefail

SCRIPT="${1:?usage: run_py_in_container.sh <python-script>}"

export DISPLAY="${DISPLAY:-:99}"
RESOLUTION="${RESOLUTION:-1920x1080x24}"

# 1. Virtual display
Xvfb "$DISPLAY" -screen 0 "$RESOLUTION" >/tmp/xvfb.log 2>&1 &
sleep 2
fluxbox >/dev/null 2>&1 &
sleep 1

# 2. Optional live view via noVNC (set VIEW=0 to skip)
if [ "${VIEW:-1}" = "1" ]; then
  x11vnc -display "$DISPLAY" -bg -forever -nopw -quiet \
         -listen localhost -rfbport 5900 >/tmp/x11vnc.log 2>&1 || true
  ( cd /opt/noVNC/utils/websockify && \
    python3 -m websockify --web /opt/noVNC 0.0.0.0:8080 localhost:5900 \
    >/tmp/websockify.log 2>&1 & )
  sleep 2
  echo "Live view: http://localhost:8080"
fi

# 3. Run the script (PYTHONPATH is set in the image)
echo "Running $SCRIPT ..."
exec python3 "$SCRIPT"
