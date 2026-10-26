#!/bin/bash
# ==============================================================================
# Priority Queuing (PQ) Configuration using Linux tc (HTB) & iptables
# Prioritizes real-time UDP traffic over TCP/ICMP bulk traffic
# ==============================================================================

INTERFACE="${1:-eth1}"
CLIENT_NET="192.168.1.0/24"

# 1. Flush existing queue disciplines and mangle rules
tc qdisc del dev "$INTERFACE" root 2>/dev/null
iptables -t mangle -F

# 2. Mark packets according to protocol
# Mark 10: High-priority UDP traffic (e.g. VoIP / real-time)
iptables -t mangle -A PREROUTING -i eth0 -s "$CLIENT_NET" -p udp -j MARK --set-mark 10
# Mark 20: Normal/Lower-priority TCP and ICMP traffic (e.g. HTTP, NFS)
iptables -t mangle -A OUTPUT -p tcp -j MARK --set-mark 20
iptables -t mangle -A OUTPUT -p icmp -j MARK --set-mark 20

# 3. Create Hierarchical Token Bucket (HTB) root qdisc with default class 20
tc qdisc add dev "$INTERFACE" root handle 1: htb default 20
tc class add dev "$INTERFACE" parent 1: classid 1:1 htb rate 1mbit

# 4. Define child classes
# Class 1:10 (UDP): 500 kbps rate, strict priority 0 (highest)
tc class add dev "$INTERFACE" parent 1:1 classid 1:10 htb rate 500kbit ceil 500kbit prio 0
# Class 1:20 (TCP/ICMP): 500 kbps rate, priority 5 (lower)
tc class add dev "$INTERFACE" parent 1:1 classid 1:20 htb rate 500kbit ceil 500kbit prio 5

# 5. Attach FIFO leaf qdiscs with small buffer limit (5 packets) to expose drops under congestion
tc qdisc add dev "$INTERFACE" parent 1:10 handle 10: pfifo limit 5
tc qdisc add dev "$INTERFACE" parent 1:20 handle 20: pfifo limit 5

# 6. Filter rules mapping firewall marks to HTB classes
tc filter add dev "$INTERFACE" parent 1:0 protocol ip handle 10 fw flowid 1:10
tc filter add dev "$INTERFACE" parent 1:0 protocol ip handle 20 fw flowid 1:20

echo "Priority Queuing (PQ) successfully applied on $INTERFACE."
