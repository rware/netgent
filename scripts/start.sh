#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# NetGent container entrypoint.
#
# Modes, auto-detected from the arguments:
#
#   1. Legacy single-workflow mode: invoked with the netgent CLI flags
#      -e/--execute or -g/--generate. One browser on display :99, one optional
#      noVNC view on $NOVNC_PORT. Delegates to cli.py exactly as before.
#
#   2. Multi-workflow mode: invoked with one or more positional workflow files.
#      Each file is run concurrently:
#        - *.json  -> a NetGent executable workflow (its own browser, Xvfb
#                     display, Chrome profile, and -- with -s -- its own noVNC
#                     port so the cursors never collide).
#        - *.sh    -> an arbitrary bash workflow (wget, ping, ...). No display.
#      Example:  start-netgent youtube.json netflix.json ping.sh -s
#
# Add --capture (or CAPTURE=1) to either mode to also record traffic + screen:
#   - one container-wide tcpdump pcap, plus
#   - per-display screenshots + mp4 + Chrome net-log for each browser workflow.
#   Capture helpers live in capture.sh (installed as /usr/local/bin/capture-netgent).
# ---------------------------------------------------------------------------

export RESOLUTION="${RESOLUTION:-1920x1080x24}"
export VNC_LISTEN_HOST="${VNC_LISTEN_HOST:-localhost}"
BASE_NOVNC_PORT="${NOVNC_PORT:-8080}"
BASE_VNC_PORT="${VNC_PORT:-5900}"
BASE_DISPLAY_NUM="${BASE_DISPLAY_NUM:-99}"

# Where per-workflow results, logs, and capture artifacts go.
OUT_DIR="${OUT_DIR:-/capture}"
if [ ! -d "$OUT_DIR" ]; then
  OUT_DIR="$(pwd)/capture"
fi
mkdir -p "$OUT_DIR"

# --- Argument inspection ---------------------------------------------------
USE_VDISPLAY=0
LEGACY=0
CAPTURE="${CAPTURE:-0}"
WORKFLOWS=()
CLI_ARGS=()   # everything forwarded to cli.py (i.e. all args except --capture)
for arg in "$@"; do
  case "$arg" in
    -s|--screen)
      USE_VDISPLAY=1
      CLI_ARGS+=("$arg")
      ;;
    -e|--execute|-g|--generate)
      LEGACY=1
      CLI_ARGS+=("$arg")
      ;;
    --capture)
      CAPTURE=1   # consumed here; cli.py never sees it
      ;;
    *)
      WORKFLOWS+=("$arg")
      CLI_ARGS+=("$arg")
      ;;
  esac
done

# Source capture helpers (start_pcap/stop_pcap/start_screen_capture/...) on demand.
if [ "$CAPTURE" -eq 1 ]; then
  # shellcheck source=/dev/null
  source /usr/local/bin/capture-netgent
  CAP_TS="$(date +%Y%m%d_%H%M%S)"
  echo "Capture enabled -> artifacts under $OUT_DIR"
fi

# --- Bring up an X display (and, optionally, a noVNC view) for it -----------
# start_display <display_num> <vnc_port> <novnc_port> <use_vnc>
start_display() {
  local dnum="$1" vncport="$2" novncport="$3" usevnc="$4"
  local disp=":${dnum}"

  Xvfb "$disp" -screen 0 "$RESOLUTION" &
  sleep 2
  # Lightweight WM for proper window focus/placement (needed by pyautogui).
  DISPLAY="$disp" fluxbox 2>/dev/null &
  sleep 1

  if [ "$usevnc" -eq 1 ]; then
    echo "Starting x11vnc for $disp on port $vncport (view-only)..."
    if [ -n "${VNC_PASSWORD:-}" ]; then
      x11vnc -display "$disp" -bg -forever -quiet \
             -listen "$VNC_LISTEN_HOST" -xkb -nodpms -viewonly \
             -rfbport "$vncport" -passwd "$VNC_PASSWORD"
    else
      x11vnc -display "$disp" -bg -forever -nopw -quiet \
             -listen "$VNC_LISTEN_HOST" -xkb -nodpms -viewonly \
             -rfbport "$vncport"
    fi

    echo "Starting websockify (noVNC) for $disp on port $novncport..."
    python3 -m websockify --web /opt/noVNC \
            "0.0.0.0:${novncport}" "localhost:${vncport}" \
            > "/tmp/websockify_${novncport}.log" 2>&1 &
    sleep 1
    echo "  -> view at http://localhost:${novncport}"
  fi
}

# Always run sshd (kept from the original entrypoint).
mkdir -p /run/sshd
/usr/sbin/sshd

# ===========================================================================
# Legacy single-workflow mode.
# ===========================================================================
if [ "$LEGACY" -eq 1 ]; then
  export DISPLAY=":${BASE_DISPLAY_NUM}"
  [ "$USE_VDISPLAY" -eq 1 ] && echo "Starting VNC/noVNC setup..."
  start_display "$BASE_DISPLAY_NUM" "$BASE_VNC_PORT" "$BASE_NOVNC_PORT" "$USE_VDISPLAY"

  if [ "$CAPTURE" -eq 1 ]; then
    start_pcap "$OUT_DIR" "$CAP_TS"
    start_screen_capture ":${BASE_DISPLAY_NUM}" "$OUT_DIR" "run" "$CAP_TS"
    trap 'stop_screen_capture; stop_pcap' EXIT INT TERM
    # Not exec'd, so the trap runs after cli.py to finalize the capture files.
    python3 /home/agent/app/src/netgent/cli.py "${CLI_ARGS[@]}"
    exit $?
  fi

  python3 /home/agent/app/src/netgent/cli.py "${CLI_ARGS[@]}"
fi

# ===========================================================================
# Multi-workflow mode.
# ===========================================================================
if [ "${#WORKFLOWS[@]}" -eq 0 ]; then
  echo "Error: no workflows provided."
  echo "Usage: start-netgent [-s] [--capture] <workflow1> [<workflow2> ...]"
  echo "  *.json -> NetGent executable workflow (browser)"
  echo "  *.sh   -> bash workflow (wget, ping, ...)"
  exit 1
fi

echo "=== NetGent multi-workflow run: ${#WORKFLOWS[@]} workflow(s) ==="
[ "$USE_VDISPLAY" -eq 1 ] && echo "Live viewing enabled (one noVNC port per browser workflow)."

# One container-wide packet capture covers all workflows' traffic.
if [ "$CAPTURE" -eq 1 ]; then
  start_pcap "$OUT_DIR" "$CAP_TS"
  trap 'stop_pcap' EXIT INT TERM
fi

declare -a PIDS=()
declare -a NAMES=()
dnum="$BASE_DISPLAY_NUM"
vncport="$BASE_VNC_PORT"
novncport="$BASE_NOVNC_PORT"

for wf in "${WORKFLOWS[@]}"; do
  base="$(basename "$wf")"
  name="${base%.*}"
  # Resolve to an absolute path so a per-workflow cwd doesn't break it.
  wfabs="$(readlink -f "$wf" 2>/dev/null || echo "$wf")"
  wdir="$OUT_DIR/$name"
  mkdir -p "$wdir"

  if [ ! -f "$wfabs" ]; then
    echo "[$name] WARNING: file not found ($wf) - skipping"
    continue
  fi

  case "$wf" in
    *.json)
      start_display "$dnum" "$vncport" "$novncport" "$USE_VDISPLAY"
      if [ "$USE_VDISPLAY" -eq 1 ]; then
        echo "[$name] browser workflow on DISPLAY :${dnum} -> watch at http://localhost:${novncport}"
      else
        echo "[$name] browser workflow on DISPLAY :${dnum} (no screen)"
      fi
      (
        cd "$wdir"
        if [ "$CAPTURE" -eq 1 ]; then
          # Per-display screen capture for this workflow; net-log into its dir.
          start_screen_capture ":${dnum}" "$wdir" "$name" "$CAP_TS"
          trap 'stop_screen_capture' EXIT
        fi
        DISPLAY=":${dnum}" python3 /home/agent/app/src/netgent/cli.py \
          -e "$wfabs" \
          --user-data-dir "/tmp/netgent-profiles/${name}" \
          -o "$wdir/${name}_result.json" \
          > "$wdir/${name}.log" 2>&1
      ) &
      PIDS+=($!)
      NAMES+=("$name")
      dnum=$((dnum + 1))
      vncport=$((vncport + 1))
      novncport=$((novncport + 1))
      ;;
    *.sh)
      echo "[$name] bash workflow -> logging to $wdir/${name}.log"
      (
        cd "$wdir"
        bash "$wfabs" > "$wdir/${name}.log" 2>&1
      ) &
      PIDS+=($!)
      NAMES+=("$name")
      ;;
    *)
      echo "[$name] WARNING: unsupported type (expected .json or .sh) - skipping"
      ;;
  esac
done

echo "=== ${#PIDS[@]} workflow(s) launched. Waiting for completion... ==="

overall_status=0
for i in "${!PIDS[@]}"; do
  pid="${PIDS[$i]}"
  wf_name="${NAMES[$i]}"
  if wait "$pid"; then
    echo "[$wf_name] completed successfully."
  else
    code=$?
    echo "[$wf_name] FAILED (exit $code)."
    overall_status=1
  fi
done

# Finalize the container-wide pcap before reporting.
if [ "$CAPTURE" -eq 1 ]; then
  stop_pcap
fi

echo "=== All workflows finished (overall status: $overall_status) ==="
echo "Results and logs are in: $OUT_DIR/<workflow-name>/"
exit "$overall_status"
