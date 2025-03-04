#!/bin/bash
# File: network-monitor.sh

LOG_DIR="/var/log/network_logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PCAP_FILE="$LOG_DIR/network_capture_$TIMESTAMP.pcap"
CONN_LOG="$LOG_DIR/connections_$TIMESTAMP.log"

mkdir -p "$LOG_DIR"

# Try to start tcpdump, but don't fail if it doesn't work
if tcpdump -i any -nn -s 0 -w "$PCAP_FILE" 2>/dev/null & then
    TCPDUMP_PID=$!
    echo "Started packet capture."
else
    echo "Warning: Could not start packet capture."
    TCPDUMP_PID=""
fi

# Function to log connections periodically
log_connections() {
  while true; do
    echo "--- Connection Report $(date) ---" >> "$CONN_LOG"
    echo "Active Internet connections:" >> "$CONN_LOG"
    netstat -tunapl >> "$CONN_LOG"
    echo "" >> "$CONN_LOG"
    sleep 10
  done
}

# Start connection logging in background
log_connections &
LOG_PID=$!

# Clean up on exit
trap 'kill $TCPDUMP_PID $LOG_PID 2>/dev/null; echo "Network monitoring stopped."' EXIT

echo "Network monitoring started. Logs in $LOG_DIR"