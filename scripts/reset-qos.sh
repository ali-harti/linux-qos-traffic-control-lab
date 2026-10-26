#!/bin/bash
# ==============================================================================
# Reset and flush all Linux tc QoS rules and iptables mangle markings
# ==============================================================================

INTERFACE="${1:-eth1}"

echo "Flushing tc qdisc on $INTERFACE..."
sudo tc qdisc del dev "$INTERFACE" root 2>/dev/null

echo "Flushing iptables mangle table..."
sudo iptables -t mangle -F

echo "QoS rules flushed. Default FIFO queuing restored."
