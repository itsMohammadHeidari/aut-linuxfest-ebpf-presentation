<!-- jump_to_middle -->

5 · Hook Points
===

<!--
speaker_note: |
  ⏱ ≤ 0:41 · section 5 starts · includes D3
  SAY   "We know how it's loaded. Now: WHERE can it run?"
-->

<!-- end_slide -->

Where can eBPF attach?
===

| Layer | Hook | What it is |
|---|---|---|
| Applications | **uprobe** (user probe) | any function in a program or library |
| | **USDT** (user statically-defined tracing) | trace points an app's developers built in |
| | | |
| System calls | **tracepoint** | official hooks placed by kernel developers |
| | **seccomp** (secure computing) | allow or block a process's syscalls |
| | | |
| Kernel functions | **kprobe** (kernel probe) | (almost) any kernel function |
| | **fentry / fexit** | same, faster: on function entry / exit |
| | | |
| Security | **LSM** (Linux Security Modules) | the kernel's "is this allowed?" checks |
| | | |
| Network stack | **socket filter** | the data of one socket (tcpdump's filter) |
| | **TC** (Traffic Control) | packets in both directions, after the driver |
| | **cgroup_skb** | packets of one service or container |
| | | |
| Network driver | **XDP** (eXpress Data Path) | packets inside the NIC driver, earliest point |

<!--
speaker_note: |
  ⏱ ≤ 0:41 · row by row, top to bottom
  SAY  "From the app down to the network card,
       there's a hook at every layer."
  uprobe      "any function in any program": bash's
              readline, later
  USDT        PostgreSQL, Python ship their own trace points
  tracepoint  D1 used one: "a program is starting"
  seccomp     Docker's default profile blocks dangerous
              syscalls; Chrome's sandbox too
  kprobe      any kernel function: every TCP connection
  fentry      the modern kprobe, faster
  LSM         where SELinux and AppArmor decide;
              Tetragon blocks things here (later)
  socket      tcpdump's filter from section 2
  TC          Cilium's pod networking lives here
  cgroup_skb  systemd's per-service firewall: running
              on my laptop right now
  XDP         the earliest point: next section
  RULE        lower = faster, less context;
              higher = slower, more context
  NEXT  "Three ways into the kernel itself."
-->

<!-- end_slide -->

Three ways into the kernel
===

| | Tracepoint | kprobe | fentry / fexit |
|---|---|---|---|
| What | hook **placed on purpose** by kernel developers | **any** kernel function, patched at runtime | any function, via a BPF trampoline |
| | | | |
| Stable across kernels? | ✔ yes | ✘ no | ✘ no |
| | | | |
| Overhead | low | higher | lowest |
| | | | |
| Since | Linux 4.7 | Linux 4.1 | Linux 5.5 |

<!-- pause -->

<!-- new_line -->

Kitchen: tracepoints are the **official doors**. kprobes are **any window** you can open.

<!--
speaker_note: |
  ⏱ ≤ 0:43:30
  tracepoint    placed ON PURPOSE; stable; D1 used one
  kprobe        runs WHEN almost any kernel function runs
                (it WATCHES; it can't call them)
                patched live; not stable across versions
  fentry/fexit  newer, faster ("BPF trampoline")
  PAUSE→        tracepoints = official doors
                kprobes = any window you can open
  EXAMPLE       kprobe on tcp_connect = every TCP
                connection, with IP and port
  NEXT          "Seeing events is good. Measuring TIME: better."
-->

<!-- end_slide -->

Measuring latency
===

<!--
speaker_note: |
  ⏱ ≤ 0:45
  issue     request sent to the disk → save the time
  complete  disk answered → find the start time
  delta     → a histogram, inside the kernel
  PAUSE→    "Two events, one map, a histogram
            in the kernel."
  NEXT      "Let's measure this laptop's disk."
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

issue: "block_rq_issue\n(request sent)" {class: box; top: 0; left: 0}
start: "@start[dev, sector] = now" {class: ebpf; top: 0; left: 560}
done: "block_rq_complete\n(request done)" {class: box; top: 280; left: 560}
hist: "@usecs = hist(now − start)" {class: good; top: 280; left: 1200}
issue -> start: "1. save time" {class: flow}
done -> start: "2. look up" {class: dim}
done -> hist: "3. delta" {class: flow}
```

<!-- pause -->

<!-- new_line -->

Two events, one map, and a **histogram computed inside the kernel**.

<!-- end_slide -->

Live: is the disk slow?
===

```bash
sudo bpftrace -e '
tracepoint:block:block_rq_issue { @start[args->dev, args->sector] = nsecs; }
tracepoint:block:block_rq_complete /@start[args->dev, args->sector]/ {
  @usecs = hist((nsecs - @start[args->dev, args->sector]) / 1000);
  delete(@start[args->dev, args->sector]);
}'
```

<!--
speaker_note: |
  ⏱ ≤ 0:46 · LIVE DEMO D3 (demo tab)
  DO      pane 0: the command on the slide
          pane 1: dd if=/dev/zero of=~/ddtest bs=1M \
            count=1000 oflag=direct status=progress;
            rm ~/ddtest
  SAY     oflag=direct skips the RAM cache → real disk
  DO      Ctrl-C in pane 0 → the histogram
  READ    buckets in µs: where's the bulk? the slow tail?
  MY RUN  bulk 64–512 µs (~75% of 8,977)
          bump 4–8 ms: 1 in 25, ~50× slower
          tail 16–64 ms: 12 requests, ~500× slower
          average ≈ 0.5 ms: hides all of that
  SAY     "The average hides the slow tail." Think p99.
  IF ASKED  BCC's biolatency tool does this, in 6 lines
  THE CODE
    line 1  block_rq_issue → @start[dev, sector] = nsecs
    line 2  block_rq_complete, filter: only if @start exists
    line 3  (nsecs − start) / 1000 = µs → hist()
    line 4  delete() the map entry
  NEXT    "From the kernel, up to user programs."
-->

<!-- end_slide -->

uprobes: every command, every user
===

kprobes hook the **kernel**. **uprobes** hook any function in any **binary or library**:
the kernel patches it in memory, and the program never knows.

```bash
LIB=$(ldd $(readlink -f $(which bash)) \
      | awk '/libreadline/ {print $3}')
sudo bpftrace -e 'uretprobe:'"$LIB"':readline {
  printf("pid %-7d typed: %s\n", pid, str(retval));
}'
```

<!-- pause -->

* `uretprobe` fires when `readline()` **returns**: its return value is the line just typed
* Every bash shell on the machine, **including root's**

<!--
speaker_note: |
  ⏱ ≤ 0:49 · not live; the code is real
  uprobe    any function in any binary or library
            patched in memory; the program never knows
  LINE 1    only finds the file: bash's readline library
  PAUSE→    uretprobe = when readline() RETURNS
            = the line just typed; every bash, even root's
  PAUSE     "Nobody can see this happening."
  RISK      an attacker's dream → why eBPF needs root
  PLATFORM  Grafana Beyla: app metrics, no SDK, same way
  THE CODE
    which · readlink · ldd · awk  find the library
    uretprobe:<file>:readline     when readline ends
    pid · retval                  process ID · typed line
    %-7d                          a number, 7 wide
  NEXT      "Why doesn't all this slow anything down?"
-->

<!-- end_slide -->

Why is it so cheap?
===

| | `strace` (section 1) | eBPF |
|---|---|---|
| Stops the process? | at every syscall | **never** |
| | | |
| Where the logic runs | user space, after a context switch | **inside the kernel**, native code |
| | | |
| What crosses to user space | every event | only **results** (maps) |

<!-- pause -->

<!-- new_line -->

**This is why eBPF can run in production, all the time.**

<!--
speaker_note: |
  ⏱ ≤ 0:50:30 · back to M1
  stops?   strace: every syscall · eBPF: never
  where    strace: user space · eBPF: kernel, native
  copies   strace: every event · eBPF: only results
  dd       strace made it ~80× slower (M1)
  PAUSE→   "This is why eBPF runs in production,
           all the time."
  NEXT     "The biggest production use of all: networking."
-->
