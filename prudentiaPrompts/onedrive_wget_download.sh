#!/usr/bin/env bash
# A sample non-browser NetGent workflow: download a file with wget to generate
# bulk-transfer network traffic. Runs concurrently alongside browser workflows.
#
# Output is written to the current working directory, which the orchestrator
# sets to out/<workflow-name>/ so parallel workflows never clobber each other.
set -euo pipefail

URL="https://1drv.ms/u/c/e36def71a46d26fc/IQDTCSodgk_sS57jP17UCYjJAXs8VOuBPV8jCa3V_5KvoxY?e=oRJqeQ&download=1"

echo "[wget] downloading: $URL"
wget --no-verbose --output-document=download.bin "$URL"
echo "[wget] done: $(ls -lh download.bin | awk '{print $5}')"