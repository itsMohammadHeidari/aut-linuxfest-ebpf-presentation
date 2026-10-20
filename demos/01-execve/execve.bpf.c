// D1's tracer, written in C (slide "Step 1: bytecode for a virtual CPU"): print
// "process -> program" for every execve. Output: sudo cat
// /sys/kernel/tracing/trace_pipe
#include "vmlinux.h"
#include <bpf/bpf_helpers.h>

char LICENSE[] SEC("license") = "GPL";

SEC("tracepoint/syscalls/sys_enter_execve")
int trace_execve(struct trace_event_raw_sys_enter *ctx)
{
    char comm[16], file[64];

    bpf_get_current_comm(&comm, 16);
    bpf_probe_read_user_str(&file, 64, (void *)ctx->args[0]);
    bpf_printk("%s -> %s", comm, file);
    return 0;
}
