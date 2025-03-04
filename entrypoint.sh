#!/bin/bash
# File: entrypoint.sh

# Start network monitoring in background
/usr/local/bin/network-monitor.sh &

echo "Container started with network monitoring."
echo "Display: $DISPLAY"
echo "PulseAudio: $PULSE_SERVER"
echo "Running in isolated environment..."

# If command is provided, run it, otherwise start a shell
if [ $# -eq 0 ]; then
  echo "No command provided, starting shell."
  exec /bin/bash
else
  exec "$@"
fi