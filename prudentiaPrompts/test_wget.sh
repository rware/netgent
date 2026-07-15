#!/usr/bin/env bash
# A sample non-browser NetGent workflow: download a file with wget to generate
# bulk-transfer network traffic. Runs concurrently alongside browser workflows.
#
# Output is written to the current working directory, which the orchestrator
# sets to out/<workflow-name>/ so parallel workflows never clobber each other.
set -euo pipefail

URL="https://file-examples.com/wp-content/storage/2017/04/file_example_MP4_480_1_5MG.mp4"

echo "[wget] downloading: $URL"
wget --no-verbose --output-document=download.bin "$URL"
echo "[wget] done: $(ls -lh download.bin | awk '{print $5}')"