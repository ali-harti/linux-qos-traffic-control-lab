#!/bin/bash
# ==============================================================================
# Traffic Generation & Network Congestion Script
# Injects mixed TCP, HTTP, NFS and UDP test streams across Router 1
# ==============================================================================

TARGET_R2="${1:-172.22.0.2}"
TARGET_ADMIN="${2:-10.0.0.101}"
NFS_SERVER="${3:-10.0.0.2}"

echo "[1/4] Launching TCP and ICMP flood towards $TARGET_R2..."
sudo hping3 -S --flood -p 80 "$TARGET_R2" &
HPING_TCP_PID=$!
sudo hping3 --icmp --flood "$TARGET_R2" &
HPING_ICMP_PID=$!

echo "[2/4] Generating background HTTP and NFS requests..."
for i in {1..1000}; do
  curl -s http://apache > /dev/null &
done

for i in {1..500}; do
  sudo mount -t nfs "$NFS_SERVER":/home/yasser/partage /home/yasser > /dev/null 2>&1 &
done

echo "[3/4] Running iperf3 UDP stream (VoIP simulation: 500 kbps, 60s)..."
iperf3 -c "$TARGET_ADMIN" -u -b 500kbit -t 60 -p 4506

echo "[4/4] Cleaning up background flood processes..."
kill "$HPING_TCP_PID" "$HPING_ICMP_PID" 2>/dev/null
echo "Test completed."
