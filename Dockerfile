# File: Dockerfile
FROM ubuntu:22.04

# Install essential dependencies
RUN apt-get update && apt-get install -y \
    pulseaudio \
    x11-apps \
    xauth \
    libpulse0 \
    tcpdump \
    net-tools \
    iptables \
    iproute2 \
    ca-certificates \
    curl \
    dbus-x11 \
    alsa-utils \
    bzip2 \
    gzip \
    xz-utils \
    unzip \
    tar \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN useradd -m appuser && \
    mkdir -p /home/appuser/.local/bin && \
    echo 'export PATH="/home/appuser/.local/bin:$PATH"' >> /home/appuser/.bashrc && \
    chown -R appuser:appuser /home/appuser

# Set up network monitoring
COPY network-monitor.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/network-monitor.sh

# Setup entry script
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Switch to non-root user
USER appuser
WORKDIR /home/appuser

# Environment variables
ENV PATH="/home/appuser/.local/bin:$PATH"
ENV PULSE_SERVER=unix:/tmp/pulse/native
ENV DISPLAY=:0

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]