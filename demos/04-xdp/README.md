# D5 · Dropping packets

[`xdp.bpf.c`](xdp.bpf.c) runs at XDP, in the network driver, before the
kernel's network stack sees the packet: it drops every ICMP (ping) packet and
passes the rest.

To try it safely, `setup.sh` builds a small test network: a network namespace
`demo` at 10.0.0.2 (like a tiny container), connected to the host
(10.0.0.1) by a veth pair, with a test web server on port 8000.

```sh
# build xdp.bpf.o, create the namespace + web server (requires sudo)
just d5-setup
cd demos/04-xdp
```

Then, one by one:

```sh
ping -c 2 10.0.0.2 # replies
sudo ip -n demo link set veth1 xdp obj xdp.bpf.o sec xdp  # load XDP (verifier + JIT run now)
ping -c 2 -W 1 10.0.0.2 # silence
curl -s http://10.0.0.2:8000 # still works (TCP)
sudo ip -n demo link set veth1 xdp off # detach
ping -c 2 10.0.0.2 # replies again
```

ICMP dies in the driver, TCP is untouched: no firewall rules, no restart.

When you're done:

```sh
# stop the web server, delete the namespace (requires sudo)
just d5-teardown
```
