<!-- jump_to_middle -->

6 · Networking
===

<!--
speaker_note: |
  ⏱ ≤ 0:52 · section 6 starts · includes D5
  SAY   "eBPF was born in networking. Let's go back."
-->

<!-- end_slide -->

A packet's journey
===

<!--
speaker_note: |
  ⏱ ≤ 0:52 · the XDP paper's own map (2018)
  WALK    left → right: hardware → driver → network
          stack → userspace
  XDP     in the driver, before sk_buff exists:
          DROP · TX (back out) · REDIRECT · PASS
  REDIRECT  to AF_XDP (user space), or a VM / container
  PASS    → build sk_buff → queueing + TC BPF →
          IP → TCP/UDP → socket → app
  COLORS  pink = XDP/eBPF parts · green = sockets ·
          blue = apps · dotted = control data
  MAPS    the control plane (e.g. Cilium's agent) writes
          BPF maps; XDP and TC programs read them
  PAUSE→  the caption: the paper's own summary
  SOURCE  Høiland-Jørgensen et al., CoNEXT 2018
  NEXT    "XDP: decide at the door."
-->

```d2 +render +width:95%
vars: {
  d2-config: {
    layout-engine: tala
    # gruvbox palette for d2's color codes (base theme 200 is set in talk.md)
    theme-overrides: {
      N1: "#ebdbb2"
      N2: "#a89984"
      N3: "#928374"
      N4: "#504945"
      N5: "#3c3836"
      N6: "#32302f"
      N7: "#3c3836"
      B1: "#a89984"
      B2: "#928374"
      B3: "#3c3836"
      B4: "#32302f"
      B5: "#32302f"
      B6: "#32302f"
      AA2: "#d3869b"
      AA4: "#3c3836"
      AA5: "#3c3836"
      AB4: "#3c3836"
      AB5: "#3c3836"
    }
  }
}

style.fill: "#282828"

classes: {
  area: {style: {fill: "#32302f"; stroke: "#665c54"; stroke-width: 2; font-color: "#a89984"; font-size: 24; border-radius: 8}}
  step: {style: {fill: "#3c3836"; stroke: "#665c54"; stroke-width: 2; font-color: "#ebdbb2"; border-radius: 6; font-size: 24}}
  sock: {style: {fill: "#3c3836"; stroke: "#8ec07c"; stroke-width: 3; font-color: "#8ec07c"; border-radius: 6; font-size: 24; bold: true}}
  ebpf: {style: {fill: "#3c3836"; stroke: "#d3869b"; stroke-width: 4; font-color: "#d3869b"; border-radius: 6; font-size: 24; bold: true}}
  app: {style: {fill: "#32302f"; stroke: "#83a598"; stroke-width: 3; font-color: "#83a598"; border-radius: 6; font-size: 24; bold: true}}
  bad: {style: {fill: "#3c3836"; stroke: "#fb4934"; stroke-width: 2; font-color: "#fb4934"; border-radius: 6; font-size: 24}}
  flow: {style: {stroke: "#fabd2f"; stroke-width: 3; font-color: "#fabd2f"; font-size: 20}}
  ctl: {style: {stroke: "#928374"; stroke-width: 2; stroke-dash: 4; font-color: "#928374"; font-size: 20}}
}

# The paper's Figure 1, turned sideways: hardware (left) → kernel → userspace (right)
grid-columns: 3
horizontal-gap: 80

hw: "Network\nhardware" {class: step; width: 150; height: 640}

kernel: "Linux kernel" {
  class: area
  grid-columns: 2
  horizontal-gap: 80

  driver: "Device driver" {
    class: area
    grid-rows: 3
    vertical-gap: 60
    drop: "Drop" {class: bad; width: 170}
    xdp: "XDP" {class: ebpf; width: 170; height: 90}
    skb: "Build sk_buff" {class: step; width: 170}
  }

  upper: "" {
    style: {fill: transparent; stroke-width: 0}
    grid-rows: 3
    vertical-gap: 40

    afxdp: "AF_XDP" {class: sock; width: 620}

    stack: "Network stack" {
      class: area
      grid-columns: 2
      horizontal-gap: 40
      qf: "Queueing and\nforwarding\n+ TC BPF" {class: ebpf; height: 250}
      right: "" {
        style: {fill: transparent; stroke-width: 0}
        grid-rows: 3
        vertical-gap: 20
        vdev: "Virtual devices" {class: step; width: 380}
        inet_path: "" {
          style: {fill: transparent; stroke-width: 0}
          grid-columns: 3
          horizontal-gap: 20
          ip: "IP layer" {class: step}
          tcp: "TCP/UDP" {class: step}
          inet: "AF_INET" {class: sock}
        }
        raw: "AF_RAW" {class: sock; width: 380}
      }
    }

    maps: "BPF maps" {class: ebpf; width: 620}
  }
}

user: "Userspace" {
  class: area
  grid-rows: 3
  vertical-gap: 60
  vms: "VMs and\ncontainers" {class: app; width: 220}
  apps: "Applications" {class: app; width: 220}
  cp: "Control plane" {class: ebpf; width: 220}
}

# packet data flow
hw -> kernel.driver.xdp {class: flow}
kernel.driver.xdp -> kernel.driver.drop: "DROP" {class: flow; style.stroke: "#fb4934"; style.font-color: "#fb4934"}
kernel.driver.xdp -> kernel.driver.skb: "PASS" {class: flow}
kernel.driver.xdp -> hw: "TX" {class: flow}
kernel.driver.xdp -> kernel.upper.afxdp: "REDIRECT" {class: flow}
kernel.driver.xdp -> kernel.upper.stack.right.vdev: "REDIRECT" {class: flow}
kernel.driver.skb -> kernel.upper.stack.qf {class: flow}
kernel.upper.stack.qf -> kernel.upper.stack.right.inet_path.ip {class: flow}
kernel.upper.stack.right.inet_path.ip -> kernel.upper.stack.right.inet_path.tcp -> kernel.upper.stack.right.inet_path.inet {class: flow}
kernel.upper.stack.qf -> kernel.upper.stack.right.raw {class: flow}
kernel.upper.afxdp -> user.vms {class: flow}
kernel.upper.stack.right.vdev -> user.vms {class: flow}
kernel.upper.stack.right.inet_path.inet -> user.apps {class: flow}
kernel.upper.stack.right.raw -> user.apps {class: flow}

# control data flow
user.cp <-> kernel.upper.maps {class: ctl}
user.cp <-> kernel.upper.stack {class: ctl}
kernel.upper.maps <-> kernel.upper.stack.qf {class: ctl}
kernel.upper.maps <-> kernel.driver.xdp {class: ctl}
```

<!-- new_lines: 1 -->

<!-- pause -->

On packet arrival, **before touching the packet data**, the driver runs an eBPF program in the **XDP** hook.
It can **drop** the packet, send it back out the same interface (**TX**), **redirect** it (another interface,
a VM, or user space via **AF_XDP**), or **pass** it to the normal stack, where a **TC BPF** hook can process it further.
eBPF programs and user space share data through **BPF maps**. (Receive path only.)

_Based on Figure 1, "The eXpress Data Path" (Høiland-Jørgensen et al., CoNEXT 2018)_

<!-- end_slide -->

XDP: decide at the door
===

<!--
speaker_note: |
  ⏱ ≤ 0:54 · verdicts already on the map
  SAY       one verdict per packet:
  DROP      gone (DDoS)
  PASS      normal stack
  TX        back out the same card (load balancers)
  REDIRECT  another card, CPU, or socket
  ABORTED   dropped with an error (bugs)
  KITCHEN   the bouncer at the door
  PAUSE→    Katran: every packet to facebook.com
            15M packets/s, ~50 ns each, 10× IPVS
  NEXT      "What does such a program look like?"
-->

Your program returns **one verdict** for every packet:

| Verdict | What happens | Used for |
|---|---|---|
| `XDP_DROP` | dropped immediately | DDoS protection |
| | | |
| `XDP_PASS` | continues to the normal stack | everything else |
| | | |
| `XDP_TX` | sent back out the same card | load balancers |
| | | |
| `XDP_REDIRECT` | sent to another card, CPU, or socket | fast forwarding, AF_XDP |
| | | |
| `XDP_ABORTED` | dropped, with an error trace | bugs |

<!-- pause -->

<!-- new_line -->

Meta's **Katran** load balancer: every packet to facebook.com goes through XDP.
**15 million packets/s**, about **50 ns** per packet, 10× faster than IPVS.

<!-- end_slide -->

An XDP program: drop all ICMP
===

```c {5-6|8-9|13-14|16|all}
SEC("xdp")
int drop_icmp(struct xdp_md *ctx)
{
    void *data     = (void *)(long)ctx->data;
    void *data_end = (void *)(long)ctx->data_end;

    struct ethhdr *eth = data;
    if ((void *)(eth + 1) > data_end)
        return XDP_PASS;
    if (eth->h_proto != bpf_htons(ETH_P_IP))
        return XDP_PASS;

    struct iphdr *ip = (void *)(eth + 1);
    if ((void *)(ip + 1) > data_end)
        return XDP_PASS;

    return ip->protocol == IPPROTO_ICMP ? XDP_DROP : XDP_PASS;
}
```

<!--
speaker_note: |
  ⏱ ≤ 0:55 · step through the highlights
  SAY     "tcpdump's filter logic, in C: IPv4? ICMP? drop."
  CHECKS  the "> data_end" ifs are for the VERIFIER:
          never read past the packet
  THE CODE
    SEC("xdp")            an XDP program, per packet
    data / data_end       packet start / end
    eth = data            Ethernet header first
    if eth+1 > data_end   too short? pass (safety)
    if h_proto != IP      not IPv4? pass
    ip = eth + 1          IP header comes next
    if ip+1 > data_end    too short? pass (safety)
    protocol == ICMP ?    ping → DROP, else PASS
    a ? b : c             if a then b, else c
  RULE    when in doubt: PASS
  NEXT    "Let's drop some pings."
-->

<!-- end_slide -->

Live: dropping packets
===

```bash
ping -c 2 10.0.0.2                                    # works
sudo ip -n demo link set veth1 xdp obj xdp.bpf.o sec xdp
ping -c 2 -W 1 10.0.0.2                               # silence
curl -s http://10.0.0.2:8000 | head -1                # still works
sudo ip -n demo link set veth1 xdp off
```

<!-- pause -->

ICMP dies **in the driver**. TCP passes untouched. No firewall rules, no restart.

<!--
speaker_note: |
  Copy-paste the commands one by one.
  Before each one, say what you expect (the → part):
  cd ~/Projects/linux-fest-aut/demos
  ping -c 2 10.0.0.2                                        # → replies
  sudo ip -n demo link set veth1 xdp obj xdp.bpf.o sec xdp  # → load XDP
  ping -c 2 -W 1 10.0.0.2                                   # → silence
  curl -s http://10.0.0.2:8000                              # → still works (TCP)
  sudo ip -n demo link set veth1 xdp off                    # → detach
  ping -c 2 10.0.0.2                                        # → replies again
-->

<!-- end_slide -->

XDP vs TC vs DPDK
===

<!--
speaker_note: |
  ⏱ ≤ 1:00 · back to "Networking the old way"
  XDP    in the kernel's NIC driver · incoming only
         → DDoS drop, load balancing
  TC     after sk_buff · both directions
         → policies, NAT, Cilium's pod networking
  DPDK   user space · takes the NIC from the kernel
         → telco data planes (5G UPF, VNFs)
  NIC    XDP native: driver support (most server NICs)
         XDP generic: any NIC, slower
         DPDK: a DPDK driver + hugepages + VFIO
  CPU    XDP/TC: only when packets arrive
         DPDK: cores polling at 100%
  SAY    "XDP: close to DPDK speed, without leaving
         the kernel or losing its tools."
  IF ASKED  my D5 demo uses veth: native XDP
  NEXT   "Which brings us to Kubernetes."
-->

| | XDP | TC | DPDK |
|---|---|---|---|
| Runs in | the kernel's NIC driver | the kernel, after `sk_buff` | **user space** |
| | | | |
| NIC needs | XDP-capable driver (most); generic mode: any NIC | any NIC | a DPDK driver; NIC **leaves** the kernel |
| | | | |
| Kernel stack & tools | kept | kept | **gone** |
| | | | |
| Directions | incoming only | both | both |
| | | | |
| CPU | only when packets arrive | only when packets arrive | cores **polling at 100%** |
| | | | |
| Typical use | DDoS drop, load balancing | policies, NAT, pods | telco: 5G UPF, VNFs |

<!-- end_slide -->

iptables vs eBPF in Kubernetes
===

```d2 +render +width:85%
vars: {
  d2-config: {
    layout-engine: tala
    # gruvbox palette for d2's color codes (base theme 200 is set in talk.md)
    theme-overrides: {
      N1: "#ebdbb2"
      N2: "#a89984"
      N3: "#928374"
      N4: "#504945"
      N5: "#3c3836"
      N6: "#32302f"
      N7: "#3c3836"
      B1: "#a89984"
      B2: "#928374"
      B3: "#3c3836"
      B4: "#32302f"
      B5: "#32302f"
      B6: "#32302f"
      AA2: "#d3869b"
      AA4: "#3c3836"
      AA5: "#3c3836"
      AB4: "#3c3836"
      AB5: "#3c3836"
    }
  }
}

style.fill: "#282828"

classes: {
  box: {style: {fill: "#3c3836"; stroke: "#665c54"; stroke-width: 2; font-color: "#ebdbb2"; border-radius: 6; font-size: 26}}
  user: {style: {fill: "#32302f"; stroke: "#83a598"; stroke-width: 3; font-color: "#83a598"; font-size: 26; bold: true}}
  kern: {style: {fill: "#32302f"; stroke: "#fb4934"; stroke-width: 3; font-color: "#fb4934"; font-size: 26; bold: true}}
  ebpf: {style: {fill: "#3c3836"; stroke: "#d3869b"; stroke-width: 3; font-color: "#d3869b"; border-radius: 6; font-size: 26; bold: true}}
  good: {style: {fill: "#3c3836"; stroke: "#b8bb26"; stroke-width: 3; font-color: "#b8bb26"; border-radius: 6; font-size: 26; bold: true}}
  bad: {style: {fill: "#3c3836"; stroke: "#fb4934"; stroke-width: 3; font-color: "#fb4934"; border-radius: 6; font-size: 26}}
  flow: {style: {stroke: "#fabd2f"; stroke-width: 4; font-color: "#fabd2f"; font-size: 24}}
  dim: {style: {stroke: "#928374"; stroke-width: 3; stroke-dash: 4; font-color: "#928374"; font-size: 22}}
  note: {shape: text; style: {font-color: "#928374"; font-size: 22; italic: true}}
}

direction: down
old: "kube-proxy (iptables): check rules one by one" {
  class: bad
  direction: right
  style.font-color: "#fb4934"
  p: "packet" {class: box}
  r1: "rule 1" {class: box}
  r2: "rule 2" {class: box}
  rn: "… rule N" {class: box}
  b: "backend" {class: box}
  p -> r1 -> r2 -> rn -> b {class: flow; style.stroke: "#fb4934"; style.font-color: "#fb4934"}
}
new: "Cilium (eBPF): one lookup" {
  class: good
  direction: right
  p: "packet" {class: box}
  m: "hash map\nlookup" {class: ebpf}
  b: "backend" {class: box}
  p -> m -> b {class: flow; style.stroke: "#b8bb26"; style.font-color: "#b8bb26"}
}
```

<!-- pause -->

<!-- new_line -->

Remember slide "Networking the old way": more services → more rules to walk.
With eBPF, a lookup costs **the same for 10 services or 10,000**.

<!--
speaker_note: |
  ⏱ ≤ 1:01:30 · back to "Networking the old way"
  TOP       kube-proxy (iptables): walk the rule chain
            every Service change rewrites tables
  BOTTOM    Cilium: one hash-map lookup
            a change = one map entry
  PAUSE→    "Same cost for 10 services or 10,000."
  IF ASKED  IPVS/nftables modes exist; eBPF also
            skips the whole iptables path
  NEXT      "So who runs this in production?"
-->
