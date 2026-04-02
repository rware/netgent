# NetGent Data Capture

Capture network traffic, browser logs, screenshots, and screen recordings as evidence that a NetGent workflow actually ran.

## Quick Start

```bash
# Build the image (includes tcpdump + ffmpeg)
docker build -t netgent .

# Run with all 4 capture types enabled
docker run --rm \
  --cap-add=NET_RAW \
  --entrypoint /usr/local/bin/start-netgent-capture \
  -v ./capture_output:/capture \
  -v ./examples/video_streaming/youtube-non-navigate/results/youtube-non-navigate_result.json:/home/agent/app/executable.json:ro \
  -p 8080:8080 \
  netgent \
  -e /home/agent/app/executable.json -s
```

After the run completes, all artifacts will be in `./capture_output/`.

## Capture Types

### 1. Packet Capture (tcpdump)

Captures all network traffic in pcap format. Shows DNS lookups, TLS handshakes to YouTube/other servers, and all HTTP(S) connections made by Chrome.

**Output:** `pcap/capture_<timestamp>.pcap`

**Analyze with:**
```bash
# Summary of connections
tshark -r capture_output/pcap/capture_*.pcap -q -z conv,tcp

# DNS queries
tshark -r capture_output/pcap/capture_*.pcap -Y dns

# Open in Wireshark (GUI)
wireshark capture_output/pcap/capture_*.pcap
```

**Requires:** `--cap-add=NET_RAW` on `docker run` for tcpdump to have permission to capture packets.

### 2. Chrome Net-Log

Chrome's built-in network logging captures HTTP request/response headers, timing, TLS certificate details, and connection pooling at the application layer. More structured than raw pcap.

**Output:** `chrome_netlog_<timestamp>.json`

**Analyze with:**
- Open `chrome://net-export/` in Chrome, then use the "Import" feature
- Or use the [NetLog Viewer](https://netlog-viewer.appspot.com/) web tool
- Or parse the JSON directly

The net-log file is written when Chrome exits, so it will appear after the automation completes.

### 3. Screenshots

Periodic screenshots of the virtual display, taken every 2 seconds (configurable). Captures the full desktop including the Chrome window.

**Output:** `screenshots/screenshot_<sequence>_<timestamp>.png`

**Configure interval:**
```bash
docker run ... -e SCREENSHOT_INTERVAL=1 ...   # every 1 second
docker run ... -e SCREENSHOT_INTERVAL=5 ...   # every 5 seconds
```

**Approximate sizes:** Each screenshot is ~500KB-2MB at 1920x1080. A 2-minute run at 2-second intervals produces ~60 screenshots (~30-120MB).

### 4. Screen Recording

Records the entire virtual display as an MP4 video using ffmpeg. Shows the complete browser automation from start to finish.

**Output:** `recording_<timestamp>.mp4`

**Play with:** Any video player (VLC, mpv, browser, etc.)

Recording uses x264 ultrafast preset at 15fps to minimize CPU overhead during automation.

## Output Directory Structure

```
capture_output/
  pcap/
    capture_20260402_194500.pcap       # Network packet capture
  screenshots/
    screenshot_0000_20260402_194500.png # First screenshot
    screenshot_0001_20260402_194500.png # 2 seconds later
    ...
  chrome_netlog_20260402_194500.json   # Chrome network log
  recording_20260402_194500.mp4        # Screen recording video
```

## Configuration

| Environment Variable     | Default    | Description                          |
|--------------------------|------------|--------------------------------------|
| `CAPTURE_DIR`            | `/capture` | Output directory inside the container |
| `SCREENSHOT_INTERVAL`    | `2`        | Seconds between screenshots          |
| `NOVNC_PORT`             | `8080`     | noVNC web viewer port                |
| `VNC_PORT`               | `5900`     | VNC server port                      |

## Running Without Capture

The original entrypoint is unchanged. To run without capture, use the normal command:

```bash
docker run --rm \
  -v ./executable.json:/home/agent/app/executable.json:ro \
  -p 8080:8080 \
  netgent \
  -e /home/agent/app/executable.json -s
```

## How It Works

The capture system is a wrapper around the existing CLI:

1. `start-netgent-capture` (entrypoint) sets up Xvfb, VNC, and noVNC (same as `start-netgent`)
2. Instead of calling `cli.py` directly, it calls `capture-netgent`
3. `capture-netgent` starts the 4 capture processes in the background
4. It then runs `cli.py` with all the original arguments
5. On exit, a trap handler stops all capture processes and prints a summary

No core NetGent code is modified except for a 3-line addition to `session.py` that optionally passes `--log-net-log` to Chrome when the `NETGENT_NET_LOG` environment variable is set.

## Troubleshooting

**tcpdump: "Operation not permitted"**
Add `--cap-add=NET_RAW` to your `docker run` command. tcpdump needs raw socket access.

**ffmpeg: "Could not open display"**
Ensure the `-s` flag is passed so Xvfb starts. Without a virtual display, ffmpeg has nothing to record.

**Chrome net-log file is empty or missing**
The net-log is flushed when Chrome exits. If the container is killed with `docker kill` instead of stopping gracefully, the file may not be written. Use `docker stop` or let the automation complete naturally.

**Screenshots are black**
The screenshot loop starts immediately, so the first few screenshots may be captured before Chrome opens. This is normal.
