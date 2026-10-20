<!-- jump_to_middle -->

4 · How eBPF Works
===

<!--
speaker_note: |
  ⏱ ≤ 0:27 · section 4 starts
  SAY   "Now the engine: how does it actually work?"
-->

<!-- end_slide -->

The big picture
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

direction: right
src: "prog.bpf.c" {class: box}
llvm: "clang / LLVM" {class: box}
obj: "bytecode\n(.o)" {class: ebpf}
k: "KERNEL" {
  class: kern
  direction: right
  ver: "verifier\nis it safe?" {class: box}
  jit: "JIT\n→ native code" {class: box}
  hook: "hook\n(event)" {class: good}
  map: "map" {class: ebpf}
  ver -> jit -> hook {class: flow}
  hook -> map: "write" {class: dim}
}
tool: "user-space\ntool" {class: box}
src -> llvm -> obj {class: flow}
obj -> k.ver: "bpf()" {class: flow}
tool -> k.map: "read" {class: dim}
```

<!-- pause -->

<!-- new_line -->

**Write** → **compile** → **load** → **verify** → **JIT** → **attach** → runs on every event → shares data through **maps**

<!--
speaker_note: |
  ⏱ ≤ 0:27
  WALK     write → compile → load (bpf()) →
           verifier "safe?" → JIT → hook → map → tool
  KITCHEN  recipe → chef checks it → kitchen speed
           → every order
  SAY      "Each next slide zooms into one box."
  NEXT     "Step 1: what does it compile into?"
-->

<!-- end_slide -->

Step 1: bytecode for a virtual CPU
===

D1's tracer written in C (left), compiled by `clang -target bpf` into **bytecode** (right, `llvm-objdump -d`):

<!-- column_layout: [3, 2] -->

<!-- column: 0 -->

```c
SEC("tracepoint/syscalls/sys_enter_execve")
int trace_execve(struct trace_event_raw_sys_enter *ctx)
{
  char comm[16], file[64];
  bpf_get_current_comm(&comm, 16);
  bpf_probe_read_user_str(&file, 64,
                          (void *)ctx->args[0]);
  bpf_printk("%s -> %s", comm, file);
  return 0;
}
```

<!-- column: 1 -->

```text {4|7|9|all}
 0: r6 = r1
 1: r7 = r10
    …              ; stack setup
 5: call 0x10      ; helper 16
 6: r3 = *(u64 *)(r6 + 0x10)
    …
11: call 0x72      ; helper 114
    …
17: call 0x6       ; helper 6
18: w0 = 0x0
19: exit
```

<!-- reset_layout -->

A **virtual CPU**: 11 registers, a 512-byte stack · `call N` = call helper N (numbers in **hex**: `0x72` = 114) · **20 instructions**

<!--
speaker_note: |
  ⏱ ≤ 0:29 · keep it light
  LEFT   D1's tracer, written in C
  RIGHT  its bytecode: clang -target bpf → llvm-objdump -d
  SAY    "Same program: left in C, right as bytecode.
         Don't read it; look at the shape."
         every eBPF program ends up as bytecode
         for a VIRTUAL CPU: interpreted or JIT-ed
  POINT  the call lines = calls to kernel helpers
  WHY    portable (x86, ARM) + simple enough to PROVE safe
  THE CODE
    r0–r10     11 registers, 64-bit
    r6 = r1    save r1 (event context) in r6
    0x…        hexadecimal: 0x10 = 16, 0x72 = 114
    call 0x10  0x10 = 16: bpf_get_current_comm
    call 0x72  0x72 = 114: bpf_probe_read_user_str
    call 0x6   6: bpf_trace_printk
    exit       done
  NEXT   "The verifier."
-->

<!-- end_slide -->

Step 2: the verifier, the head chef inspects the recipe
===

<!--
speaker_note: |
  ⏱ ≤ 0:31 · the key slide of the section
  SAY       before it runs ONCE, the kernel checks
            every possible path
  ONE EACH  ends? · memory in bounds? · NULL checked?
            allowed helpers? · initialized? · size?
  PAUSE→    "Can't PROVE it's safe → rejected.
            No exceptions."
  LINK      Alexei's crash: don't trust the compiler
            July 19: a kernel module gets no check
  NEXT      "Let's make it say no."
-->

Before your program runs **even once**, the kernel simulates **every possible path** through it:

<!-- incremental_lists: true -->

* Does **every path end**? (no infinite loops)
* Is **every memory access in bounds**? (stack, maps, packets)
* Is every pointer **checked for NULL** before use?
* Does it only call **helpers allowed** for this program type?
* Does it read **only initialized** memory?
* Is it within the **size and complexity limits**?

<!-- incremental_lists: false -->

<!-- pause -->

<!-- new_line -->

**If the verifier can't prove it's safe, the program is rejected. No exceptions.**

<!-- end_slide -->

The verifier says no
===

```c {4}
SEC("tracepoint/syscalls/sys_enter_execve")
int stuck(void *ctx)
{
    while (1) { }      /* BUG: never ends */
    return 0;
}
```

<!-- pause -->

```text
$ sudo bpftool prog load verifier-no.bpf.o /sys/fs/bpf/stuck
0: (05) goto pc-1
...
infinite loop detected at insn 0
cur state: R1=ctx() R10=fp0
old state: R1=ctx() R10=fp0
```

<!-- pause -->

Loops are fine if the verifier can **prove** they end: `for (int i = 0; i < 10; i++)`.
A program in the kernel must **always finish**.

<!--
speaker_note: |
  ⏱ ≤ 0:33 · static, real log from my laptop
  SAY       "Every time a program starts, loop forever."
            compiler: fine · kernel: refused
  WHY       a never-ending program in the kernel
            freezes that CPU
  PAUSE→    the real log: it ran insn 0 (goto pc-1)
            again and again; cur state = old state
            → nothing changes → "infinite loop detected"
            (stopped after 9 of its 1,000,000 insn limit)
  PAUSE→    loops are OK only if provably bounded
  LINK      the first rule on the last slide:
            "does every path end?"
  CONTRAST  kernel module: a frozen machine · here: a message
  THE CODE
    SEC(...execve)  runs on every program start (like D1)
    while (1) { }   loop forever
  NEXT      "Once it's accepted: the JIT."
-->

<!-- end_slide -->

Step 3: JIT, cooked at kitchen speed
===

<!--
speaker_note: |
  ⏱ ≤ 0:35
  interpreter  decodes every instruction, every time: slow
  JIT          translates once to native code
               (like JavaScript in your browser)
  PAUSE→       my laptop: 768 B eBPF → 448 B real x86
  xlated       "translated": the verified bytecode,
               as the kernel stores it (768 B = 96 insns)
  jited        that program as native x86 code
  ARM          same bytecode → ARM code on a Pi or cloud
  NEXT         "How does a program hand results back? Maps."
-->

| | Interpreter | JIT compiler |
|---|---|---|
| How | decodes each instruction, every time it runs | translates the whole program **once** |
| | | |
| Speed | slow | **native machine code** |

<!-- pause -->

<!-- new_line -->

From my laptop (`bpftool prog list`):

```text
xlated 768B  jited 448B
```

96 verified eBPF instructions → 448 bytes of real **x86-64** code.
The same bytecode becomes **ARM64** code on a Raspberry Pi or a cloud ARM server.

<!-- end_slide -->

Maps: sharing data with user space
===

```d2 +render +width:48%
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
k: "KERNEL" {
  class: kern
  direction: right
  ev: "execve\nevent" {class: box}
  prog: "eBPF program\n@[comm]++" {class: ebpf}
  m: "@ (hash map)" {
    shape: sql_table
    style: {fill: "#d3869b"; stroke: "#3c3836"; font-color: "#282828"; font-size: 24}
    bash: "16"
    sudo: "7"
    unix_chkpwd: "3"
  }
  ev -> prog: "fires" {class: dim}
  prog -> m: "+1" {class: flow}
}
u: "USER SPACE" {
  class: user
  bt: "bpftrace\nprints at Ctrl-C" {class: box}
}
u.bt -> k.m: "read once" {class: flow}
```

<!-- new_lines: 1 -->

<!-- pause -->

**Aggregate inside the kernel, copy out only the result.**
Types: hash · array · per-CPU · LRU · ring buffer · LPM trie (IP prefixes) · …

<!--
speaker_note: |
  ⏱ ≤ 0:36
  map      key/value store, shared by kernel + user space
  DIAGRAM  every execve → +1 under the process name
  REAL     bash 16 · sudo 7 · unix_chkpwd 3
           nothing crossed over until Ctrl-C
  PAUSE→   "Aggregate inside the kernel,
           copy out only the result."
           (strace copied every event)
  TYPES    hash · array · per-CPU · LRU ·
           ring buffer (events out) · LPM trie (IPs)
  NEXT     "But a program can't do anything it likes."
-->

<!-- end_slide -->

Helpers and kfuncs: the kernel's API for eBPF
===

<!--
speaker_note: |
  ⏱ ≤ 0:38
  helpers  the approved kernel API
           like REST instead of direct DB access
  READ 3   process name · safe copy · map lookup
  PAUSE→   "Let's ask the kernel." DO: Ctrl+E → 211, 250
  LINE 1   list the kernel's helper IDs (BPF_FUNC_*),
           drop 'unspec' (ID 0, not a helper), count
  LINE 2   count functions tagged bpf_kfunc
  BTF      the kernel's description of its own types;
           /sys/kernel/btf/vmlinux, readable by anyone
  PER TYPE sudo bpftool feature probe kernel
  SUBSET   packet programs can't read process memory
           tracing programs can't drop packets
  IF ASKED "but kprobes reach any function?"
           kprobe = WATCH any function (trigger)
           helpers = CALL only approved ones
           a camera on any door; it can't open doors
  NEXT     "So where can these programs attach?"
-->

An eBPF program **can't call any kernel function it likes**. It gets an approved list:

| Helper | Does |
|---|---|
| `bpf_get_current_comm` | name of the current process |
| | |
| `bpf_probe_read_user_str` | safely copy a string from user memory |
| | |
| `bpf_map_lookup_elem` | read from a map |
| | |
| `bpf_ktime_get_ns` | current time |
| | |
| `bpf_ringbuf_output` | send an event to user space |
| | |
| `bpf_redirect` | send a packet to another interface |

<!-- pause -->

Ask the kernel itself (its type info, BTF; no root needed):

```bash +exec
/// exec 2>/dev/null
bpftool btf dump file /sys/kernel/btf/vmlinux | grep "'BPF_FUNC_" | grep -vc unspec
bpftool btf dump file /sys/kernel/btf/vmlinux | grep -c "DECL_TAG 'bpf_kfunc'"
```

My kernel (6.18): **211 helpers** and **250 kfuncs**. Each program type may use only its own subset.
