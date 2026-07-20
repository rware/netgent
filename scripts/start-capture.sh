#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# NetGent Startup with Data Capture (compatibility shim).
#
# Capture is now built into start-netgent via the --capture flag, so this just
# forwards to it. Kept so the
#   --entrypoint /usr/local/bin/start-netgent-capture
# interface (and the existing README examples) keep working.
#
# Defaults output to the conventional /capture mount; override with -e OUT_DIR=...
# Works in both legacy (-e/-g) and multi-workflow modes.
# ============================================================================

trap '' SIGUSR1
trap '' SIGCONT

exec env OUT_DIR="${OUT_DIR:-/capture}" /usr/local/bin/start-netgent --capture "$@"
