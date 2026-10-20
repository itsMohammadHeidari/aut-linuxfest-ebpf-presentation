<!-- jump_to_middle -->

1 · Why eBPF Exists
===

<!--
speaker_note: |
  ⏱ ≤ 0:02 · section 1 starts · includes M1
  SAY   "How apps have always run on Linux,
        and what that couldn't give us."
-->

<!-- end_slide -->

Two worlds
===

```d2 +render +width:55%
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

direction: down
style.fill: "#282828"

classes: {
  box: {
    style: {fill: "#3c3836"; stroke: "#665c54"; font-color: "#ebdbb2"; border-radius: 6; font-size: 20}
  }
}

user: "USER SPACE · unprivileged" {
  grid-columns: 4
  grid-gap: 30
  style: {fill: "#32302f"; stroke: "#83a598"; stroke-width: 3; font-color: "#83a598"; font-size: 22; bold: true}
  bash.class: box
  nginx.class: box
  postgres.class: box
  "your app".class: box
}

kernel: "KERNEL SPACE · full control" {
  grid-columns: 4
  grid-gap: 30
  style: {fill: "#32302f"; stroke: "#fb4934"; stroke-width: 3; font-color: "#fb4934"; font-size: 22; bold: true}
  processes.class: box
  memory.class: box
  filesystems.class: box
  network.class: box
}

user -> kernel: "system calls · the only door" {
  style: {stroke: "#fabd2f"; stroke-width: 4; font-color: "#fabd2f"; font-size: 22}
}
```

<!-- pause -->

<!-- new_line -->

Programs **cannot** touch hardware, disks, the network, or other processes.
They **ask** the kernel, through a **system call**.

<!--
speaker_note: |
  ⏱ ≤ 0:02
  user space    every program: bash, nginx, containers
  kernel space  hardware, memory, files, network
  syscall       the only door: you ASK the kernel
  bank          the teller window, not the vault
  menu          365 syscalls on my kernel
                every program = a sequence of them
  KEY LINE      "You can ORDER from the menu,
                but you can't CHANGE THE KITCHEN."
  containers    all share ONE kernel; matters later
                (uname -r: 6.18.54 on host and in Alpine)
  NEXT          "Two of these calls start every program."
-->

<!-- end_slide -->

How every program starts: fork + execve
===

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

direction: right
style.fill: "#282828"

classes: {
  proc: {
    style: {fill: "#3c3836"; stroke: "#83a598"; stroke-width: 4; font-color: "#ebdbb2"; border-radius: 6; font-size: 34}
  }
  step: {
    style: {stroke: "#fabd2f"; stroke-width: 4; font-color: "#fabd2f"; font-size: 30}
  }
}

parent: "bash\nPID 100" {class: proc; top: 0; left: 0}
copy: "bash\nPID 205" {class: proc; top: 0; left: 520}
ls: "ls\nPID 205" {class: proc; style.stroke: "#b8bb26"; top: 0; left: 1040}

parent -> copy: "1. clone()\nmake a copy of me" {class: step}
copy -> ls: "2. execve(\"/bin/ls\")\nbecome a different program" {class: step}
ls -> parent: "exit" {style: {stroke: "#928374"; stroke-dash: 4; font-color: "#928374"; font-size: 26}}
```

<!-- pause -->

<!-- new_line -->

Remember this: at `execve` entry, the child is **still called bash**.
We'll see it live soon.

<!--
speaker_note: |
  ⏱ ≤ 0:03
  1 clone()   bash (PID 100) copies itself → PID 205
  2 execve()  the copy BECOMES ls, same PID
  3 exit      ls ends, bash is back
  EVERY       program starts like this:
              entrypoints, kubectl exec, cron
  EXCEPTION   builtins like cd: no clone, no execve
  PAUSE→      at execve it's STILL named bash;
              we'll see it live
  IF ASKED    why copy first? execve REPLACES the caller
              no copy = bash is gone (exec ls)
              why entrypoints end with exec "$@"
  NEXT        "Everything goes through the kernel.
              How do we SEE it?"
-->

<!-- end_slide -->

Watching through the window
===

To **see** what the kernel is doing, we had four families of tools:

| Tool | How it sees | The catch |
|---|---|---|
| `/proc`, `/sys` | reads counters the kernel exports | only what's exported, only when you look |
| | | |
| `strace` | stops the process at every syscall | painfully slow |
| | | |
| `tcpdump` | copies packets to user space | lots of copying |
| | | |
| `perf`, `ftrace`, SystemTap, DTrace | kernel-developer tools | hard, risky, or not on Linux |

<!--
speaker_note: |
  ⏱ ≤ 0:05 · 1–2 sentences per row
  SAY          can't enter the kitchen → watch the windows
  /proc, /sys  counters on a timer: a snapshot, not a story
               a 5 ms process between polls: never seen
  strace       every syscall, very slow (next slide)
  tcpdump      copies packets out; has a trick
               (comes back in section 2)
  perf/ftrace  powerful, raw
  SystemTap    becomes a kernel module: can crash
  DTrace       safe + programmable; license kept it off Linux
  NEXT         "Let me show you how expensive watching is."
-->

<!-- end_slide -->

`strace`: stop the world at every syscall
===

```bash +exec +id:m1
/// TIMEFORMAT="%R seconds"; cd /dev; exec </dev/zero
echo "without strace:"
time dd of=null bs=1 count=200K status=none
echo "with strace:"
time strace -o null dd of=null bs=1 count=200K status=none
```

<!-- snippet_output: m1 -->

<!-- pause -->

The kernel **stops** the process at every syscall entry **and** exit, wakes up `strace`, waits, resumes.

<!--
speaker_note: |
  ⏱ ≤ 0:07 · MINI-DEMO M1
  SAY FIRST  dd copies 1 byte at a time
             = 400,000 syscalls; output thrown away
  DO         Ctrl+E · ~5 s: stay silent, let them wait
  RESULT     ~0.05 s vs ~4–6 s → "about 80× slower"
  WHY        every syscall: kernel STOPS dd, wakes strace,
             waits, resumes
  PUNCHLINE  great for one process; unusable in production
  IF FAILS   don't debug: "0.05 s vs 4 s, 80× slower"
  THE CODE
    time            measure it
    dd              copy data
    bs=1            one byte at a time
    count=200K      200,000 times
    of=null         throw the output away
    status=none     quiet
    strace -o null  same, under strace; drop its log
  NEXT       "That's watching. What about CHANGING it?"
-->

<!-- end_slide -->

Want to change the kitchen?
===

<!--
speaker_note: |
  ⏱ ≤ 0:09 · bullets appear one by one
  SAY       to CHANGE the kernel, two ways:
  upstream  convince maintainers → release → your distro
            = years
  module    your own cook, no supervision
            one bug = machine down; breaks on upgrades
  NEXT      "Networking is where this hurts platform teams."
-->

To **change** how the kernel behaves, you had two options:

<!-- pause -->

<!-- incremental_lists: true -->

* **Patch the kernel upstream**: ask the head chef to change the recipe
  → it takes **years** to reach your servers
* **Write a kernel module**: sneak your own cook into the kitchen, unsupervised
  → one bug **crashes the whole machine**, and it breaks on every kernel upgrade

<!-- incremental_lists: false -->

<!-- end_slide -->

Networking the old way
===

<!-- column_layout: [1, 1] -->

<!-- column: 0 -->

### iptables / netfilter

* Rules in chains, checked **one by one**
* Kubernetes `kube-proxy` writes rules **per service**
* Thousands of services → thousands of rules on every node

<!-- column: 1 -->

### Kernel bypass (DPDK)

* Take the network card **away from the kernel**
* Very fast, but you **lose** the kernel's TCP/IP stack and tools
* Burns CPU cores just polling the card

<!-- reset_layout -->

<!--
speaker_note: |
  ⏱ ≤ 0:10
  iptables     rules in chains, checked one by one
  kube-proxy   rules per Service → thousands per node
  DPDK         take the card away from the kernel
               fast, but no TCP/IP stack, no tools,
               CPU cores burned polling
  SAY          inside and slow, or fast but outside
  WORKAROUNDS  sidecars, LD_PRELOAD, /proc agents:
               all AROUND the kernel, not inside
  NEXT         "Let's put every option side by side."
-->

<!-- end_slide -->

Every option has a ✘
===

| | Safe | Fast | Runtime change | Sees all | Upgrades |
|---|:-:|:-:|:-:|:-:|:-:|
| `/proc` polling | ✔ | ✔ | ✔ | ✘ | ✔ |
| | | | | | |
| `strace` | ✔ | ✘ | ✔ | ✘ | ✔ |
| | | | | | |
| `tcpdump` | ✔ | ✘ | ✔ | ✘ | ✔ |
| | | | | | |
| Kernel patch | ✔ | ✔ | ✘ | ✔ | ✔ |
| | | | | | |
| Kernel module / SystemTap | ✘ | ✔ | ✔ | ✔ | ✘ |
| | | | | | |
| DPDK bypass | ✔ | ✔ | ✘ | ✘ | ✔ |
| | | | | | |
| Sidecars / `LD_PRELOAD` | ✔ | ✘ | ✔ | ✘ | ✔ |

<!-- pause -->

<!-- new_line -->

**We wanted all five ✔ at the same time.**

<!--
speaker_note: |
  ⏱ ≤ 0:11
  COLUMNS  safe · fast · runtime · sees all · upgrades
  ROWS     pick 3: strace safe but slow ·
           kernel patch years · module fast but unsafe
  SAY      every row has at least one ✘
  PAUSE→   "We wanted all five ✔ at the same time."
           stop 2–3 s: the problem statement
  NEXT     "When kernel code goes wrong, it goes very wrong."
-->
