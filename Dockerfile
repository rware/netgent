FROM python:3.11-slim

ARG DEBIAN_FRONTEND=noninteractive

# Default environment for X and noVNC
ENV DISPLAY=:99 \
    RESOLUTION=1920x1080x24 \
    DBUS_SESSION_BUS_ADDRESS=/dev/null \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONPATH=/home/agent/app/netgent/src

WORKDIR /home/agent/app

# System deps (Xvfb, VNC, noVNC needs), Chrome dependencies, SSH (optional)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget unzip git xauth \
    xvfb x11vnc fluxbox \
    openssh-server \
    libnss3 libxss1 libasound2 libatk-bridge2.0-0 libgtk-3-0 libgbm1 fonts-liberation \
    python3-xlib python3-tk scrot \
    tcpdump ffmpeg \
  && rm -rf /var/lib/apt/lists/*

# Install Google Chrome
RUN wget -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
  && apt-get update \
  && apt-get install -y --no-install-recommends /tmp/chrome.deb \
  && rm -f /tmp/chrome.deb \
  && rm -rf /var/lib/apt/lists/*

# Install noVNC + Websockify
RUN git clone https://github.com/novnc/noVNC.git /opt/noVNC \
  && git clone https://github.com/novnc/websockify /opt/noVNC/utils/websockify \
  && pip install websockify \
  && ln -s /opt/noVNC/vnc.html /opt/noVNC/index.html

# Copy configuration script
COPY scripts/configure_novnc.sh /usr/local/bin/configure_novnc.sh
RUN chmod +x /usr/local/bin/configure_novnc.sh \
  && /usr/local/bin/configure_novnc.sh

# Python Dependencies First for Better Layer Caching
COPY requirements.txt .
RUN pip install -r requirements.txt \
  && seleniumbase get chromedriver --path

# Copy the ENTIRE netgent folder (not just src) into /home/agent/app/netgent/
# so examples/, scripts/, docs/, etc. are all available in the image.
# NOTE: this Dockerfile's build context IS the netgent/ dir, so the source is
# "." (the context root), not "netgent/". The layout mirrors the prudentia root
# Dockerfile, where start-netgent's hardcoded
# /home/agent/app/netgent/src/netgent/cli.py path resolves.
COPY . netgent/

# capture.sh execs /home/agent/app/src/netgent/cli.py, so also place cli.py there
# (matches the prudentia root Dockerfile, which copies it to both locations).
COPY src/netgent/cli.py /home/agent/app/src/netgent/cli.py
RUN chmod +x /home/agent/app/src/netgent/cli.py

# Copy and use the startup script
COPY scripts/start.sh /usr/local/bin/start-netgent
RUN chmod +x /usr/local/bin/start-netgent

# Capture scripts for data collection
COPY scripts/capture.sh /usr/local/bin/capture-netgent
RUN chmod +x /usr/local/bin/capture-netgent

COPY scripts/start-capture.sh /usr/local/bin/start-netgent-capture
RUN chmod +x /usr/local/bin/start-netgent-capture

ENTRYPOINT ["/usr/local/bin/start-netgent-capture"]