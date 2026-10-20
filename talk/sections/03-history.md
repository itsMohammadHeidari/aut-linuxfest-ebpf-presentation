<!-- jump_to_middle -->

2 · The Story of BPF
===

<!--
speaker_note: |
  ⏱ ≤ 0:15 · section 2 starts · includes M2
  SAY   "To understand eBPF, go back 30 years,
        to a packet filter."
-->

<!-- end_slide -->

1992: watching packets was too expensive
===

Van Jacobson's team at Lawrence Berkeley Lab built **tcpdump** (1988) to debug TCP on the early Internet.
But the OS copied **every** packet to it: too slow, and packets were lost.

```d2 +render +width:50%
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

before: "BEFORE (Sun NIT, CSPF)" {
  direction: right
  class: bad
  style.font-color: "#fb4934"
  nic: "network card" {class: box}
  kern: "kernel" {class: box}
  tcpdump: "tcpdump\n(filters in user space)" {class: box}
  nic -> kern: "every packet" {class: dim}
  kern -> tcpdump: "copy EVERY packet" {class: flow; style.stroke: "#fb4934"; style.font-color: "#fb4934"}
}
```

<!-- pause -->

```d2 +render +width:50%
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

after: "AFTER (BPF, 1992)" {
  direction: right
  class: good
  nic: "network card" {class: box}
  kern: "kernel" {
    class: box
    filter: "BPF filter\n(tiny VM)" {class: ebpf}
  }
  tcpdump: "tcpdump" {class: box}
  nic -> kern.filter: "every packet" {class: dim}
  kern.filter -> tcpdump: "copy only matches" {class: flow; style.stroke: "#b8bb26"; style.font-color: "#b8bb26"}
}
```

Their fix: Steven McCanne & Van Jacobson, *The BSD Packet Filter* (USENIX, 1993): run the filter **inside the kernel**.
The filter is a program for a **made-up CPU**, a "virtual machine" like Java's JVM (not like KVM):
a few simple instructions, executed by a small loop of kernel code.
Result: up to **100 times faster** than copying every packet to user space (Sun's NIT).

<!--
speaker_note: |
  ⏱ ≤ 0:15
  WHY       Berkeley Lab built tcpdump (1988) to debug TCP
            the OS copied EVERY packet: slow, packets lost
  BEFORE    kernel copies everything; tcpdump filters later
  PAUSE→    AFTER + "Their fix" appear together
  AFTER     send the filter INTO the kernel;
            only matches are copied out
  VM        "Not KVM. Think JVM: a tiny made-up CPU,
            a few instructions, run by a small kernel loop.
            Simple enough to CHECK before running."
  RESULT    up to 100× faster than copying everything
  ANALOGY   a WHERE clause inside the database
  IF ASKED  ~20× vs CSPF, an older in-kernel filter
  NEXT      "It's still in your tcpdump. Let me prove it."
-->

<!-- end_slide -->

BPF is still inside your tcpdump
===

<!-- column_layout: [2, 1] -->

<!-- column: 0 -->

```bash +exec +id:m2
/// exec 2>/dev/null
tcpdump -d 'icmp'
```

<!-- snippet_output: m2 -->

<!-- column: 1 -->

How to read it (syntax from the kernel docs, `networking/filter.rst`):
`[12]` = byte 12 of the packet · `#` = a number · `0x` = hexadecimal

| Virtual CPU instruction | Meaning |
|---|---|
| `ldh [12]` | EtherType |
| | |
| `jeq #0x800` | IPv4? |
| | |
| `ldb [23]` | protocol |
| | |
| `jeq #0x1` | ICMP? |
| | |
| `ret #262144` | **keep** |
| | |
| `ret #0` | **drop** |

<!-- reset_layout -->

<!-- new_line -->

BPF shipped inside the **BSD** kernel. **Linux** adopted the same instruction set in **1997** (Linux Socket Filter),
so the filters tcpdump compiles run unchanged on both.

<!--
speaker_note: |
  ⏱ ≤ 0:16 · MINI-DEMO M2
  1 DOCS    "Defined in the kernel docs, filter.rst.
            ~35 instructions; this filter needs 4."
  2 LEGEND  point top right:
            [12]   a position: byte 12 of the packet
            #      a number
            0x     hexadecimal (0x800 = 2048)
  3 RUN     "-d prints the program, captures nothing,
            no root" · Ctrl+E
  4 READ    ldh [12]     load 2 bytes at 12: packet type
            jeq #0x800   IPv4? no → drop
            ldb [23]     load 1 byte at 23: protocol
            jeq #0x1     ping? no → drop
            ret #262144  keep
            ret #0       drop
  NAMES     ldh load half-word · ldb load byte
            jeq jump if equal · ret return
            jt / jf = go here if true / false
  PUNCHLINE "Every tcpdump filter you typed became
            a program like this."
  LINUX     BSD first; Linux took the same set in 1997
  IF ASKED  trusted? jumps only go forward: always ends
            0x800 = IPv4 · 1 = ICMP (/etc/protocols)
            seccomp (2012): same VM, filters syscalls
  NEXT      "In 2014, someone rebuilt it from scratch."
-->

<!-- end_slide -->

2014: eBPF, "extended" BPF
===

**Why:** at PLUMgrid, a software-defined networking startup, Alexei Starovoitov wanted to load
**networking programs into the kernel**, safely, without kernel modules. He rebuilt BPF as a general engine:

| | Classic BPF (1992) | eBPF (2014) |
|---|---|---|
| Registers | 2 × 32-bit | **11 × 64-bit** |
| | | |
| Loops | none | bounded loops (2019) |
| | | |
| State between runs | none | **maps** |
| | | |
| Calls into the kernel | none | **helper functions** |
| | | |
| Safety | simple rules | the **verifier** |
| | | |
| Runs | packet filters | **almost any kernel event** |

<!-- pause -->

> "You cannot trust the compiler… When something gets loaded in the kernel,
> it shouldn't be trusting the user space. So that's how the verifier came about."
> — Alexei Starovoitov, *eBPF: Unlocking the Kernel* (2023)

<!--
speaker_note: |
  ⏱ ≤ 0:17:30 · tell it as a story
  WHY      ~2013, software-defined networking;
           the kernel's tools didn't fit
  ALEXEI   PLUMgrid: networking programs INSIDE the kernel
  CRASH    trusted the compiler → hosts crashed after
           hours of traffic → the kernel must check
  TABLE    11 registers · loops · maps · helpers ·
           verifier · any kernel event
  PAUSE→   read the quote slowly: why the verifier exists
  NEXT     "Writing it was easy. Getting it INTO Linux…"
-->

<!-- end_slide -->

How eBPF got into Linux
===

<!-- incremental_lists: true -->

* **2013:** first patch: a brand-new instruction set plus an LLVM backend, a "huge patch bomb". **Nobody looked.**
* Advice from Red Hat: *"make it similar to what already exists"* → reshaped as **extended BPF**
* With **Daniel Borkmann** (Red Hat): step one only **replaces the old tcpdump interpreter**, so existing filters run **faster**
* Networking maintainer David Miller: *"Applied, thanks."* (Linux 3.15, 2014)
* Networking still pushed back (*"Open vSwitch already does this"*) → a second user: **tracing**, with Netflix
* **Linux 3.18 (December 2014):** the `bpf()` syscall. Then **"Lego brick by Lego brick"**

<!-- incremental_lists: false -->

<!-- pause -->

<!-- new_line -->

A revolutionary idea, merged as **small, useful, boring steps**. Today "BPF" means eBPF; the old one is "cBPF".

<!--
speaker_note: |
  ⏱ ≤ 0:19 · items appear one by one
  1 PATCH    new instruction set + LLVM: "a patch bomb"
             nobody looked
  2 RED HAT  "make it look like what exists"
             → "extended BPF, because… what else?"
  3 DANIEL   step 1: only replace the old tcpdump
             interpreter → existing filters get faster
  4 MERGED   David Miller: "Applied, thanks." (3.15)
  5 TRACING  networking said no (Open vSwitch)
             → Netflix: Alexei adds kprobes,
             Brendan Gregg writes the tools
  6 3.18     the bpf() syscall; then brick by brick
  PAUSE→     "Revolutionary idea, boring steps."
  NEXT       "And then it exploded."
-->

<!-- end_slide -->

Then it exploded
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

t: "" {
  grid-rows: 2
  grid-columns: 5
  grid-gap: 24
  style: {fill: transparent; stroke-width: 0}
  y1: "1992\nBPF paper\n(tcpdump)" {class: box}
  y2: "1997\nLinux Socket\nFilter" {class: box}
  y3: "2011\nBPF JIT" {class: box}
  y4: "2012\nseccomp-bpf" {class: box}
  y5: "2014\neBPF\nbpf() in 3.18" {class: ebpf}
  y6: "2015\nkprobes · BCC" {class: box}
  y7: "2016\nXDP" {class: box}
  y8: "2018\nBTF · bpftrace\nKatran" {class: box}
  y9: "2020\nBPF LSM\nring buffer" {class: box}
  y10: "2021+\neBPF Foundation\nCilium graduates" {class: good}
}
```

<!--
speaker_note: |
  ⏱ ≤ 0:20:30 · don't read every box
  2015   kprobes + BCC (the Netflix deal)
  LATER  2016 XDP · 2018 BTF, bpftrace · 2020 BPF LSM
  GREEN  2021 eBPF Foundation · 2023 Cilium graduates
  SAY    you run it now: systemd firewalls,
         every Android phone
  NEXT   "So what does this actually change?"
-->
