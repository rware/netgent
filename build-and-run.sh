#!/usr/bin/env bash 
#
# build-and-run.sh — Build the NetGent Docker image and run the container.
#
# Defaults reproduce the "Code Execution Mode" example from the README:
# it runs a pre-generated workflow in a sandboxed browser.
#
# Usage:
#   ./build-and-run.sh                       # build + run the default example
#   ./build-and-run.sh --no-build            # skip the build, just run
#   ./build-and-run.sh --build-only          # build the image and exit
#   EXECUTABLE=path/to/foo.json ./build-and-run.sh #if you wish t to run a different workflow, set EXECUTABLE to point at it (relative or absolute)
#
# Override behaviour via environment variables (see DEFAULTS below).
set -euo pipefail

echo " ----------------------------------------------" 
echo "   DOING SOMETHING WITH build-and-run.sh" 
echo " ----------------------------------------------"


# Path to this script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"  #change directory to the script's directory, and capture that absolute path in SCRIPT_DIR
SCRIPT_PATH="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
cd "$SCRIPT_DIR" 


# Default values for environment variables (can be overridden by user)
IMAGE="${IMAGE:-netgent}"
PLATFORM="${PLATFORM:-linux/amd64}"
PORT="${PORT:-8080}"
EXECUTABLE="${EXECUTABLE:-/home/magani1/qoe-measurement/netgent/examples/web_browsing/youtube/results/youtube_stats_result.json}" #Hardcoded path
OUT_DIR="${OUT_DIR:-/local/capture_qoe_measurement/stats}"
OUT_FILE="${OUT_FILE:-/capture/execution_result-$(date +%s).json}"
DOCKER_RUN_FLAGS="${DOCKER_RUN_FLAGS:---rm}" # Pass `docker run` extra flags via DOCKER_RUN_FLAGS (e.g. "--rm -d").
DOCKER="${DOCKER:-docker}" # Use sudo if the current user can't talk to the Docker daemon.


# Set permissions for the output directory so the container can write to it, and user can read the results after container stops
chown -R $USER:$USER "$OUT_DIR" # no need for sudo here since we added the current user to the docker group
# --- Flags -------------------------------------------------------------------
DO_BUILD=1
DO_RUN=1
for arg in "$@"; do
  case "$arg" in
    --no-build)   DO_BUILD=0 ;;
    --build-only) DO_RUN=0 ;;
    -h|--help)
      sed -n '2,14p' "$SCRIPT_PATH" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1 ;;
  esac
done

# # Fall back to sudo if Docker isn't reachable without it.
# if ! $DOCKER info >/dev/null 2>&1; then
#   if command -v sudo >/dev/null 2>&1 && sudo $DOCKER info >/dev/null 2>&1; then
#     echo "==> Docker requires elevated privileges; using sudo."
#     DOCKER="sudo $DOCKER"
#   else
#     echo "ERROR: cannot reach the Docker daemon. Is Docker installed and running?" >&2
#     exit 1
#   fi
# fi

# --- Build -------------------------------------------------------------------
if [ "$DO_BUILD" -eq 1 ]; then
  echo "==> Building image '$IMAGE' (platform $PLATFORM)..."
  $DOCKER build --platform "$PLATFORM" -t "$IMAGE" .
fi

[ "$DO_RUN" -eq 1 ] || exit 0

# --- Run ---------------------------------------------------------------------
if [ ! -f "$EXECUTABLE" ]; then
  echo "ERROR: executable workflow not found: $EXECUTABLE" >&2
  echo "       Set EXECUTABLE=path/to/workflow.json to point at a valid file." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

# Resolve to an absolute path so the bind-mount works whether EXECUTABLE was
# given as relative (to this dir) or absolute.
EXECUTABLE_ABS="$(cd "$(dirname "$EXECUTABLE")" && pwd)/$(basename "$EXECUTABLE")"

echo "==> Running container from image '$IMAGE'..."
echo "    workflow : $EXECUTABLE_ABS"
echo "    output   : $OUT_DIR ($OUT_FILE inside container)"
echo "    viewer   : http://localhost:$PORT (view-only, with -s)"

$DOCKER run --platform="$PLATFORM" $DOCKER_RUN_FLAGS \
  -p "$PORT:8080" \
  -v "$EXECUTABLE_ABS:/executable_code.json:ro" \
  -v /local/capture_qoe_measurement:/capture \
  "$IMAGE" \
  -e /executable_code.json \
  --user-data-dir /tmp/browser-cache \
  -o "$OUT_FILE" \
  -s


#as soon as the container is stopped, move the stats file to a new file with timestamp
# you could add
TIMESTAMP="$(date +%s)"
sudo mv /local/capture_qoe_measurement/stats/youtube_stats.jsonl /local/capture_qoe_measurement/stats/youtube_stats-$TIMESTAMP.jsonl