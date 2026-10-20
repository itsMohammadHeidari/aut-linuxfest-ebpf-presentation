# Demos

One directory per demo, in the order they appear in the talk. Each has a
README with the commands to run and what you should see.

| Directory | In the talk | What it shows |
|---|---|---|
| [`01-execve/`](01-execve/) | D1 · "Live: ask the kernel" | Every program that starts on the machine (bpftrace, plus the same tracer in C) |
| [`02-disk-latency/`](02-disk-latency/) | D3 · "Live: is the disk slow?" | A histogram of disk I/O latency (bpftrace) |
| [`03-verifier/`](03-verifier/) | "The verifier says no" | A program that never ends: it compiles, and the kernel refuses to load it |
| [`04-xdp/`](04-xdp/) | D5 · "Live: dropping packets" | Drop every ping in the network driver while TCP keeps working |
| [`05-tetragon/`](05-tetragon/) | "Tetragon: block it in the kernel" | Kill any process in a Kubernetes pod that reads `/etc/shadow` |
| [`06-connsnoop/`](06-connsnoop/) | "Live: write your own, in Go" | Which process connects where, and to which country (cilium/ebpf) |

Most demos load programs into the kernel, so they need `sudo`; run them on a
machine you own. Run the commands below from the repository root, in
`just kitty` or `just shell`, so every tool is on your `PATH` (see the
requirements in the [top-level README](../README.md#requirements)).

- `just demos` builds every C program (`*/*.bpf.c`). It also generates
  `vmlinux.h` (all the kernel's types, from `/sys/kernel/btf/vmlinux`),
  shared by every demo, and `compile_commands.json` for clangd. Neither is
  in the repository: until you run `just demos`.
  `'vmlinux.h' file not found` and a cascade of errors after it.
- `just fmt` formats the C code (style: `.clang-format`).
