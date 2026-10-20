Limits & risks
===

<!--
speaker_note: |
  ⏱ ≤ 1:09 · honest, brisk
  verifier   strict: rewrite until it can prove safety
  kernels    new features need new kernels
  debugging  harder: verifier logs, bpftool
  PAUSE→     attackers too: remember the bash example
             ebpfkit rootkit (DEF CON 2021)
             BPFDoor malware (2022)
  SAY        "Whoever has root decides."
  DEFEND     unprivileged eBPF off (mine: 2) ·
             CAP_BPF, not full root ·
             audit: bpftool prog list
  NEXT       "So how do you start?"
-->

* **Strict verifier**: valid-looking code gets rejected until it can prove safety
* **Kernel versions matter**: new hooks and helpers need new kernels
* **Harder to debug** than user space: verifier logs, `bpf_printk`, `bpftool`

<!-- pause -->

<!-- new_line -->

* **The same power for attackers**: eBPF rootkits (*ebpfkit*, DEF CON 2021), malware (*BPFDoor*, 2022)
* **Defend**: unprivileged eBPF off, `CAP_BPF` instead of full root, audit with `bpftool prog list`

<!-- end_slide -->

<!-- jump_to_middle -->

8 · Getting Started
===

<!--
speaker_note: |
  ⏱ ≤ 1:11 · section 8 starts · includes the Go demo
  SAY   "You don't need to be a kernel developer.
        Here's where to start."
-->

<!-- end_slide -->

Your learning path
===

<!--
speaker_note: |
  ⏱ ≤ 1:11 · items appear one by one
  1 bpftrace  one-liners on your laptop, today
              "you, at 3 AM"
  2 BCC       ~100 ready tools
              (execsnoop = D1, biolatency = D3)
  3 your own  libbpf (C) or cilium/ebpf (Go)
              "platform engineers, Go is your friend"
  4 read      Cilium, Tetragon, Falco
  PAUSE→      "All of this ran on a normal laptop.
              You don't need a lab."
  NEXT        "Let's write one. In Go."
-->

<!-- incremental_lists: true -->

1. **bpftrace one-liners**: answer real questions on your own laptop today
2. **BCC tools**: `execsnoop`, `opensnoop`, `biolatency`, `tcplife`
3. **Write your own**: libbpf-bootstrap (C) or cilium/ebpf (Go)
4. **Read real projects**: Cilium, Tetragon, Falco

<!-- incremental_lists: false -->

<!-- pause -->

<!-- new_line -->

Everything in this talk ran on a **normal laptop**. You don't need a lab.

<!-- end_slide -->

Live: write your own, in Go
===

<!--
speaker_note: |
  ⏱ ≤ 1:13 · LIVE DEMO (demo tab)
  SAY     "Step 3 of the path: write your own. In Go."
  LEFT    kernel side, C: runs when a TCP connection
          starts; sends PID, process, destination
          through a ring buffer
  RIGHT   user side, Go (cilium/ebpf): load (verifier
          + JIT) · attach · read events · find country
  COPY PANE 0 (the Go program, sudo)
  cd ~/Projects/linux-fest-aut
  just connsnoop
  COPY PANE 1 (make some connections)
  curl -s https://example.com >/dev/null
    → also: open a site · ask the AI agent something
  POINT   the COUNTRY column: "Do you know who your
          laptop talks to?"
  NOTE    GeoIP = where an IP is registered
          (1.1.1.1 shows AU: anycast)
  PAUSE→  bpf2go: one Go binary, eBPF program inside
  DO      Ctrl-C · Ctrl+Shift+← back to the slides
  STORY   the verifier rejected my first version:
          "dereference of modified ctx ptr" (memcpy
          from ctx) → fixed with bpf_probe_read_kernel
  NEXT    resources
-->

<!-- column_layout: [1, 1] -->

<!-- column: 0 -->

**Kernel side** (C)

```c
SEC("tracepoint/sock/inet_sock_set_state")
int trace_connect(
    struct trace_event_raw_inet_sock_set_state *ctx)
{
    if (ctx->newstate != TCP_SYN_SENT)
        return 0;
    /* reserve a ring buffer slot, fill in:
       PID, process, destination IP + port */
    bpf_ringbuf_submit(e, 0);
    return 0;
}
```

<!-- column: 1 -->

**User side** (Go, cilium/ebpf)

```go
loadBpfObjects(&objs, nil)      // load
link.Tracepoint("sock",         // attach
    "inet_sock_set_state",
    objs.TraceConnect, nil)
rd, _ := ringbuf.NewReader(objs.Events)
rec, _ := rd.Read()   // one event
country(geo, ip)      // → country
```

<!-- reset_layout -->

<!-- pause -->

`bpf2go` compiles the C and embeds it: **one Go binary**. Country data: IP Geolocation by DB-IP.com (CC BY 4.0).

<!-- end_slide -->

Resources
===

<!--
speaker_note: |
  ⏱ ≤ 1:15:30 · let them photograph it
  START  ebpf.io + the bpftrace tutorial
  THEN   Liz Rice, "Learning eBPF" (free PDF)
  STORY  the documentary, 30 min on YouTube
-->

* **ebpf.io**: the official starting point
* ***Learning eBPF***, Liz Rice (O'Reilly, 2023)
* ***BPF Performance Tools***, Brendan Gregg (2019)
* ***eBPF: Unlocking the Kernel***: the documentary (2023, YouTube)
* **bpftrace one-liner tutorial**: github.com/bpftrace/bpftrace
* **libbpf-bootstrap**: github.com/libbpf/libbpf-bootstrap

<!-- end_slide -->

<!-- jump_to_middle -->

Thank you!
===

<!-- alignment: center -->

> "Now a hundred thousand people in the world can program the kernel thanks to BPF."
> — *eBPF: Unlocking the Kernel* (2023)

<!-- new_line -->

**Mohammad Heidari**

`{t.me,github.com}/itsMohammadHeidari`

itsMohammadHeidari@gmail.com

<!--
speaker_note: |
  ⏱ ≤ 1:16:15 · ~5 min buffer before 1:22
  QUOTE   "…now a hundred thousand people can program
          the kernel thanks to BPF."
  PAUSE   then: "After today, a few more."
  THANKS  Linux Festival, Amirkabir University, the room
  REACH   Telegram + GitHub: itsMohammadHeidari
          (the {…} on the slide = both sites) · email
-->

<!-- end_slide -->

<!-- jump_to_middle -->

Questions?
===

<!--
speaker_note: |
  ⏱ ≤ 1:17 (1:22 at the latest) · Q&A until 1:30 · answers ≤ 30 s
  RULE          repeat each question out loud
  OVERHEAD      native code per event, no stop
                cost = how often × how much
  KERNEL        any current distro (5.15+, 6.x)
  MANY KERNELS  BTF + CO-RE: offsets fixed at load
                → tools ship as container images
  vs strace,    not enemies: one process / packets /
  tcpdump, perf profiles; eBPF = system-wide, custom
  CONTAINERS    one shared kernel → a DaemonSet per node
  WINDOWS       eBPF for Windows exists
  DON'T KNOW    "Good question; let's talk after."
  1:29          "One last question." Then thank them.
-->
