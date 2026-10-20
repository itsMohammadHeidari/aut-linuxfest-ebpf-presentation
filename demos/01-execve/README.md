# D1 · Every program that starts

Attach to the `sys_enter_execve` tracepoint ("a program is about to start")
and print who started what.

## With bpftrace

In one terminal (leave it running):

```sh
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_execve {
  printf("%s -> %s\n", comm, str(args->filename));
}'
```

In another, run a few commands:

```sh
ls
hostname
cd /tmp
pwd
echo hi
```

`comm` is **who** started it, `filename` is **what** started.
The new process is still called `bash` at that point (fork, then execve).
`cd`, `pwd` and `echo` never show up:
they are shell builtins, so no new program starts. Ctrl-C to stop.

## The same tracer in C

[`execve.bpf.c`](execve.bpf.c) does the same with libbpf and writes to the
kernel's trace buffer:

```sh
just demos
sudo bpftool prog load demos/01-execve/execve.bpf.o /sys/fs/bpf/execve autoattach
sudo cat /sys/kernel/tracing/trace_pipe
sudo rm /sys/fs/bpf/execve # unload it
```
