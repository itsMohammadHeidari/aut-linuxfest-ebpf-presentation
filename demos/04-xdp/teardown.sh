#!/usr/bin/env bash
# Undo demo D5: stop the web server, delete the namespace (this also removes both veth ends).
set -uo pipefail
[ -f /run/d5-http.pid ] && kill "$(cat /run/d5-http.pid)" 2>/dev/null; rm -f /run/d5-http.pid
ip netns del demo 2>/dev/null
echo "D5 cleaned up"
