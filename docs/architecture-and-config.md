# Network Architecture & Configuration

This document specifies the addressing scheme, VM configurations, services setup, and routing mechanics for the Linux QoS lab.

## Topology & Subnets

The network consists of three distinct IP subnets connected through two routed Linux gateways:

```
[ Clients LAN: 192.168.1.0/24 ]
  ├── Client 1 (DHCP lease)
  ├── Client 2 (DHCP lease)
  ├── DNS/DHCP Server (192.168.1.3)
  └── Router 1 - ens33 (192.168.1.1/24)
            │
[ Inter-Router Transit Link: 172.22.0.0/30 ]
  ├── Router 1 - ens37 (172.22.0.1/30)
  └── Router 2 - ens33 (172.22.0.2/30)
            │
[ Servers & Admin LAN: 10.0.0.0/24 ]
  ├── Router 2 - ens37 (10.0.0.1/24)
  ├── Web Server - Apache (10.0.0.4)
  ├── File Server - NFS (10.0.0.2)
  └── Admin Host (10.0.0.101)
```

## Router Addressing & IP Forwarding

Both routers are configured with static routes and Linux kernel packet forwarding:

### Router 1 (Gateway 1)
- **Interfaces**:
  - `ens33`: `192.168.1.1/24` (Facing Clients)
  - `ens37`: `172.22.0.1/30` (Transit Link)
- **Static Route**:
  ```bash
  sudo ip route add 10.0.0.0/24 via 172.22.0.2 dev ens37
  ```
- **IP Forwarding**:
  ```bash
  sudo sysctl -w net.ipv4.ip_forward=1
  ```

### Router 2 (Gateway 2)
- **Interfaces**:
  - `ens33`: `172.22.0.2/30` (Transit Link)
  - `ens37`: `10.0.0.1/24` (Facing Servers & Admin)
- **Static Route**:
  ```bash
  sudo ip route add 192.168.1.0/24 via 172.22.0.1 dev ens33
  ```
- **IP Forwarding**:
  ```bash
  sudo sysctl -w net.ipv4.ip_forward=1
  ```

## Service Configurations

1. **DHCP (`isc-dhcp-server` on 192.168.1.3)**:
   - Pool: `192.168.1.100` to `192.168.1.254`
   - Gateway: `192.168.1.1`
   - DNS: `192.168.1.3`
2. **DNS (`bind9` on 192.168.1.3)**:
   - Forward zone: `isga.local` (`apache.isga.local` -> `10.0.0.4`, `nfs.isga.local` -> `10.0.0.2`)
   - Reverse zone: `1.168.192.in-addr.arpa`
3. **HTTP Server (`apache2` on 10.0.0.4)**:
   - Provides web portal tested via `curl http://apache.isga.local`
4. **NFS File Server (`nfs-kernel-server` on 10.0.0.2)**:
   - Shared directory: `/home/yasser/partage` exported to `192.168.1.0/24` and `10.0.0.0/24`
   - Client mount: `mount -t nfs 10.0.0.2:/home/yasser/partage /mnt`

## Traffic Control & QoS Algorithms

1. **First-In First-Out (FIFO)**:
   - Default Linux packet scheduler. No classification or rate limiting.
   - Under congestion, all flows suffer equally from queue bloat, packet drops, and high latency.
2. **Priority Queuing (PQ)**:
   - Configured using `tc htb` with classes assigned strict priorities (`prio 0` vs `prio 5`).
   - High-priority UDP traffic is transmitted first with zero drops, while TCP traffic experiences heavy packet loss (starvation).
3. **Weighted Queuing Sharing (WQS)**:
   - Proportional bandwidth allocation (70% UDP / 30% TCP) paired with Stochastic Fairness Queueing (`sfq perturb 10`).
   - Prevents starvation, guarantees minimal throughput for bulk TCP data, and stabilizes real-time UDP jitter.
