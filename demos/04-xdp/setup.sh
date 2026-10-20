#!/usr/bin/env bash
# Demo D5 setup (see README.md): a "server" in its own network namespace, reachable at 10.0.0.2.
#   host (10.0.0.1, d5-host) <── virtual cable ──> netns "demo" (10.0.0.2, veth1)
# (the host side is not called veth0: podman/kind already use veth0, veth1, …)
# Run as root:  just d5-setup      Undo:  just d5-teardown
set -euo pipefail
PYTHON=${PYTHON:-python3}
cd "$(dirname "$0")"

ip netns del demo 2>/dev/null || true # start clean
ip netns add demo
ip link del d5-host 2>/dev/null || true
ip link add d5-host type veth peer name veth1 netns demo
ip addr add 10.0.0.1/24 dev d5-host
ip link set d5-host up
ip -n demo addr add 10.0.0.2/24 dev veth1
ip -n demo link set veth1 up
ip -n demo link set lo up

# a tiny web server inside the namespace (TCP port 8000)
www=$(mktemp -d)
echo "hello from 10.0.0.2 (inside the demo namespace)" > "$www/index.html"
ip netns exec demo "$PYTHON" -m http.server 8000 --directory "$www" >/dev/null 2>&1 &
echo $! > /run/d5-http.pid
sleep 1

echo "ready: ping -c 2 10.0.0.2   |   curl -s http://10.0.0.2:8000"
