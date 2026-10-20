# Beyond Syscalls: Inside the World of eBPF

**Speaker:** Mohammad Heidari — DevOps / Platform Engineer
**Event:** Amirkabir University of Technology — Linux Festival

## Abstract

For decades, if you wanted to change how the Linux kernel behaved, you had two
options: get a patch merged upstream and wait years, or write a kernel module
and risk crashing the whole machine. Meanwhile, your applications could only
talk to the kernel through a narrow, fixed door: the system call.

eBPF changed that. It lets us run small, sandboxed programs *inside* the
kernel, safely and without rebooting or recompiling anything. They can attach
to almost any event: a syscall, a network packet arriving at the NIC, a
function call inside the kernel, or a function inside a user-space binary.
A built-in verifier checks every program before it is loaded, so it can't
crash the kernel, and a JIT compiler turns it into native machine code so it
runs at near-native speed.

This talk is a practical tour of eBPF from the point of view of a platform
engineer. We will cover:

- **Why eBPF exists:** the limits of syscalls, kernel modules, and traditional
  observability tools.
- **How it works under the hood:** the eBPF virtual machine, the verifier, the
  JIT, maps, helpers, and hook points (kprobes, tracepoints, uprobes, XDP, TC,
  LSM).
- **What it's used for in production:** Tools shaping modern cloud-native infrastructure, including Cilium for Kubernetes CNI and Tetragon for runtime security.
- **Live demos:** tracing every process started on a machine, finding slow
  disk I/O, and dropping packets before the kernel's network stack ever sees
  them, each in only a few lines of code.

You will leave with a clear mental model of what eBPF is, why it has become
part of how Linux infrastructure is built and observed, and how to start
writing your own eBPF programs with bpftrace, BCC, or libbpf.
