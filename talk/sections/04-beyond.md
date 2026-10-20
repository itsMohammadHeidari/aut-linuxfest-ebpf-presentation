<!-- jump_to_middle -->

3 · Beyond Syscalls
===

<!--
speaker_note: |
  ⏱ ≤ 0:21 · section 3 starts · includes D1
  SAY   "This section is the title of the talk."
-->

<!-- end_slide -->

From calling the kernel to extending it
===

```d2 +render +width:60%
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

direction: right
before: "BEFORE · call the kernel" {
  class: user
  direction: down
  style.stroke: "#928374"
  style.font-color: "#928374"
  app: "your app" {class: box}
  k: "kernel\nfixed behavior" {class: box}
  app -> k: "syscall" {class: flow}
}
after: "AFTER · extend the kernel" {
  class: user
  direction: down
  style.stroke: "#d3869b"
  style.font-color: "#d3869b"
  app: "your app" {class: box}
  k: "kernel" {
    class: kern
    grid-rows: 2
    grid-columns: 3
    grid-gap: 20
    sys: "syscalls" {class: box}
    net: "network" {class: box}
    disk: "disk I/O" {class: box}
    p1: "+ your eBPF" {class: ebpf}
    p2: "+ your eBPF" {class: ebpf}
    p3: "+ your eBPF" {class: ebpf}
  }
  app -> k: "syscall" {class: flow}
}
```

<!-- pause -->

<!-- new_line -->

<!-- alignment: center -->

**You don't just _call_ the kernel anymore. You _extend_ it, safely, at runtime.**

<!--
speaker_note: |
  ⏱ ≤ 0:21
  BEFORE  your app calls the kernel; fixed behavior
          = order from the menu
  AFTER   syscalls still the door; now small VERIFIED
          programs run inside, on kernel events:
          a syscall, a packet, the disk
  PAUSE→  slowly: "You don't just CALL the kernel anymore.
          You EXTEND it, safely, at runtime."
  NEXT    "Let's see it. But first, a question."
-->

<!-- end_slide -->

<!-- jump_to_middle -->

So… do you know what is running on your laptop right now?
===

<!-- pause -->

<!-- alignment: center -->

<!--
speaker_note: |
  ⏱ ≤ 0:22
  ASK     the room; wait 2–3 s in silence
  PAUSE→  "…what about your AI coding agent?"
  SAY     "Do we know what they run? Let's ask the kernel."
  DO      Ctrl+Shift+→ to the demo tab
-->

<!-- end_slide -->

Live: ask the kernel
===

```bash
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_execve {
  printf("%s -> %s\n", comm, str(args->filename));
}'
```

One line. **Every program started on this machine**, by any user, shows up.

<!--
speaker_note: |
  ⏱ ≤ 0:22 · LIVE DEMO D1 (demo tab)
  EXPLAIN  tracepoint = official hook:
           "a program is about to start"
  DO       pane 0: the command (sudo)
           pane 1: ls · hostname · cd /tmp · pwd · echo hi
  ASK      "Why didn't cd show up?" → builtins: no execve
  POINT    "bash -> ls": still named bash
           prompt helpers (sed, basename): "never typed"
  AGENT    let the AI agent run something
  DO       Ctrl-C · Ctrl+Shift+← back to the slides
  CLOSE    "Nothing can hide from the kernel. One line.
           No reboot, no module, nothing restarted."
  THE CODE (WHEN { WHAT })
    sudo                 loading into the kernel needs root
    bpftrace -e          run this tiny program
    tracepoint:…execve   WHEN any program starts
    printf "%s -> %s"    print "who -> what"
    comm                 who started it
    str(args->filename)  what started, as text
  NEXT     "How is this possible, and why is it safe?"
-->
