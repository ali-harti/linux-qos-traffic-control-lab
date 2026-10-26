#!/bin/bash
# ==============================================================================
# Weighted Queuing Sharing (WQS) Configuration using Linux tc (HTB + SFQ)
# Implements proportional bandwidth sharing between UDP and TCP streams
# ==============================================================================

INTERFACE="${1:-eth1}"
CLIENT_NET="192.168.1.0/24"

# 1. Flush existing queue disciplines and mangle rules
tc qdisc del dev "$INTERFACE" root 2>/dev/null
iptables -t mangle -F

# 2. Mark packets according to protocol
iptables -t mangle -A PREROUTING -i eth0 -s "$CLIENT_NET" -p udp -j MARK --set-mark 10
iptables -t mangle -A OUTPUT -p tcp -j MARK --set-mark 20

# 3. Create Hierarchical Token Bucket (HTB) root qdisc with default class 30
tc qdisc add dev "$INTERFACE" root handle 1: htb default 30
tc class add dev "$INTERFACE" parent 1: classid 1:1 htb rate 1mbit ceil 1mbit

# 4. Define weighted child classes
# Class 1:10 (UDP): 700 kbps guaranteed (70% weight), max 1 Mbps
tc class add dev "$INTERFACE" parent 1:1 classid 1:10 htb rate 700kbit ceil 1mbit
# Class 1:20 (TCP): 300 kbps guaranteed (30% weight), max 1 Mbps
tc class add dev "$INTERFACE" parent 1:1 classid 1:20 htb rate 300kbit ceil 1mbit

# 5. Attach Stochastic Fairness Queueing (SFQ) to prevent TCP flow starvation
tc qdisc add dev "$INTERFACE" parent 1:10 handle 10: sfq perturb 10
tc qdisc add dev "$INTERFACE" parent 1:20 handle 20: sfq perturb 10

# 6. Filter rules mapping firewall marks to HTB classes
tc filter add dev "$INTERFACE" parent 1:0 protocol ip handle 10 fw flowid 1:10
tc filter add dev "$INTERFACE" parent 1:0 protocol ip handle 20 fw flowid 1:20

echo "Weighted Queuing Sharing (WQS) successfully applied on $INTERFACE."
