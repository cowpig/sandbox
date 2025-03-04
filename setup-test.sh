#!/bin/bash
# File: setup-test.sh
# test-container.sh - Script to test the untrusted application container

# Set up test directory structure
TEST_DIR="container-test"
mkdir -p $TEST_DIR/untrusted_app
mkdir -p $TEST_DIR/network_logs
cd $TEST_DIR

# Create a test application that:
# 1. Displays a window
# 2. Plays a sound
# 3. Makes a network connection
cat > untrusted_app/test-app.py << 'EOF'
#!/usr/bin/env python3
import tkinter as tk
import subprocess
import socket
import threading
import time
import os

def play_sound():
    # Use aplay to generate a simple beep sound
    subprocess.run(["aplay", "-q", "/dev/stdin"], input=bytes.fromhex("52494646240000005741564566"
        "6d74201000000001000100803e0000007d0000020010004c49535414000000494e464f495346"
        "5408000000000000000064617461000000000000ff"), check=False)

def make_network_connection():
    # Attempt to connect to multiple destinations
    destinations = [
        ("www.example.com", 80),
        ("8.8.8.8", 53),  # Google DNS
        ("localhost", 22)  # Local SSH
    ]
    
    results = []
    for dest, port in destinations:
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(2)
            start = time.time()
            result = s.connect_ex((dest, port))
            elapsed = time.time() - start
            status = "Success" if result == 0 else f"Failed (code: {result})"
            results.append(f"{dest}:{port} - {status} ({elapsed:.2f}s)")
            s.close()
        except Exception as e:
            results.append(f"{dest}:{port} - Error: {str(e)}")
    
    return results

class TestApp:
    def __init__(self, root):
        self.root = root
        root.title("Container Test Application")
        
        # Create GUI
        tk.Label(root, text="Untrusted Application Test", font=("Helvetica", 16)).pack(pady=10)
        
        # Display environment information
        env_frame = tk.Frame(root)
        env_frame.pack(fill="x", padx=20, pady=10)
        
        env_vars = {
            "Container Username": os.popen("whoami").read().strip(),
            "Display": os.environ.get("DISPLAY", "Not set"),
            "Pulse Server": os.environ.get("PULSE_SERVER", "Not set"),
            "Container Hostname": os.popen("hostname").read().strip(),
            "Working Directory": os.getcwd()
        }
        
        for i, (key, value) in enumerate(env_vars.items()):
            tk.Label(env_frame, text=f"{key}:", anchor="w").grid(row=i, column=0, sticky="w")
            tk.Label(env_frame, text=value).grid(row=i, column=1, sticky="w", padx=10)
        
        # Add sound test button
        sound_btn = tk.Button(root, text="Test Audio", command=play_sound)
        sound_btn.pack(pady=10)
        
        # Network test section
        tk.Label(root, text="Network Connection Tests:", anchor="w").pack(anchor="w", padx=20)
        self.network_results = tk.Text(root, height=10, width=60)
        self.network_results.pack(padx=20, pady=10, fill="both", expand=True)
        
        network_btn = tk.Button(root, text="Run Network Tests", command=self.run_network_test)
        network_btn.pack(pady=10)
        
        # File access test
        file_frame = tk.Frame(root)
        file_frame.pack(fill="x", padx=20, pady=10)
        
        self.file_path = tk.Entry(file_frame, width=40)
        self.file_path.insert(0, "/etc/passwd")
        self.file_path.pack(side="left", padx=5)
        
        file_btn = tk.Button(file_frame, text="Try to Read File", command=self.try_read_file)
        file_btn.pack(side="left")
        
        self.file_result = tk.Text(root, height=5, width=60)
        self.file_result.pack(padx=20, pady=5, fill="both")
        
    def run_network_test(self):
        def run():
            self.network_results.delete(1.0, tk.END)
            self.network_results.insert(tk.END, "Running network tests...\n")
            results = make_network_connection()
            self.network_results.delete(1.0, tk.END)
            for result in results:
                self.network_results.insert(tk.END, result + "\n")
        
        threading.Thread(target=run).start()
        
    def try_read_file(self):
        path = self.file_path.get()
        self.file_result.delete(1.0, tk.END)
        
        try:
            with open(path, 'r') as f:
                content = f.read(500)  # Read first 500 chars
                if len(content) == 500:
                    content += "...(truncated)"
                self.file_result.insert(tk.END, content)
        except Exception as e:
            self.file_result.insert(tk.END, f"Error: {str(e)}")

if __name__ == "__main__":
    root = tk.Tk()
    root.geometry("600x600")
    app = TestApp(root)
    root.mainloop()
EOF

# Make the test script executable
chmod +x untrusted_app/test-app.py

# Create a Dockerfile for our test
cat > Dockerfile << 'EOF'
FROM ubuntu:22.04

# Install dependencies for display, audio, and network monitoring
RUN apt-get update && apt-get install -y \
    pulseaudio \
    x11-apps \
    xauth \
    libpulse0 \
    tcpdump \
    net-tools \
    iptables \
    sudo \
    iproute2 \
    ca-certificates \
    curl \
    dbus-x11 \
    alsa-utils \
    netcat \
    lsb-release \
    tshark \
    python3 \
    python3-tk \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user to run the app
RUN useradd -m appuser && \
    echo "appuser ALL=(ALL) NOPASSWD: /usr/sbin/tcpdump" >> /etc/sudoers

# Set up network monitoring
RUN mkdir -p /var/log/network_logs
COPY network-monitor.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/network-monitor.sh

# Setup entrypoint
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Switch to non-root user
USER appuser
WORKDIR /home/appuser

# Set environment variables for display and audio
ENV PULSE_SERVER=unix:/tmp/pulse/native
ENV DISPLAY=:0

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
EOF

# Create the network monitoring script
cat > network-monitor.sh << 'EOF'
#!/bin/bash

LOG_DIR="/var/log/network_logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PCAP_FILE="$LOG_DIR/network_capture_$TIMESTAMP.pcap"
CONN_LOG="$LOG_DIR/connections_$TIMESTAMP.log"

# Start tcpdump to capture all traffic
sudo tcpdump -i any -nn -s 0 -w "$PCAP_FILE" &
TCPDUMP_PID=$!

# Function to log connections
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
trap 'kill $TCPDUMP_PID $LOG_PID; echo "Network monitoring stopped."' EXIT

# Keep script running
echo "Network monitoring started. Logs in $LOG_DIR"
while true; do sleep 60; done
EOF

# Create the entrypoint script
cat > entrypoint.sh << 'EOF'
#!/bin/bash

# Start network monitoring in background
/usr/local/bin/network-monitor.sh &

echo "Container started with network monitoring."
echo "Display set to: $DISPLAY"
echo "PulseAudio server: $PULSE_SERVER"
echo ""
echo "Running your application in a sandboxed environment..."

# If command is provided, run it, otherwise start a shell
if [ $# -eq 0 ]; then
  echo "No command provided, starting shell."
  exec /bin/bash
else
  exec "$@"
fi
EOF

# Create the run script
cat > run.sh << 'EOF'
#!/bin/bash

# Create directory for network logs
mkdir -p network_logs

# Run the container with all necessary permissions and mounts
docker run -it --rm \
  --name untrusted-app \
  --net=host \
  --cap-drop=ALL \
  --cap-add=NET_RAW \
  --cap-add=NET_ADMIN \
  --security-opt no-new-privileges \
  --volume /tmp/.X11-unix:/tmp/.X11-unix \
  --volume /run/user/$(id -u)/pulse:/tmp/pulse:ro \
  --volume $HOME/.Xauthority:/home/appuser/.Xauthority:ro \
  --volume $(pwd)/network_logs:/var/log/network_logs \
  --volume $(pwd)/untrusted_app:/home/appuser/app \
  --env PULSE_SERVER=unix:/tmp/pulse/native \
  --env DISPLAY=:0 \
  untrusted-app-container "$@"

echo "Container exited. Network logs are available in the network_logs directory."
EOF

chmod +x *.sh

echo "Test environment created in '$(pwd)'"
echo "Run these commands to test:"
echo
echo "  # Build the container image"
echo "  docker build -t untrusted-app-container ."
echo
echo "  # Run the test application"
echo "  ./run.sh python3 /home/appuser/app/test-app.py"
echo
echo "After testing, you can check network_logs/ to see what was captured"
