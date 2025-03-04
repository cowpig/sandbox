#!/bin/bash
# File: run.sh

# Create directories
mkdir -p network_logs
mkdir -p container_home

# Run the container with persistent home directory
docker run -it --rm \
  --name untrusted-app \
  --net=host \
  --volume /tmp/.X11-unix:/tmp/.X11-unix \
  --volume /run/user/$(id -u)/pulse:/tmp/pulse:ro \
  --volume $HOME/.Xauthority:/home/appuser/.Xauthority:ro \
  --volume $(pwd)/network_logs:/var/log/network_logs \
  --volume $(pwd)/container_home:/home/appuser \
  untrusted-app-container "$@"

echo "Container exited. Network logs are available in the network_logs directory."
echo "User files are preserved in the container_home directory."
