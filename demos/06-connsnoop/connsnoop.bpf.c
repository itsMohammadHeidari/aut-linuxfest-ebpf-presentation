//go:build ignore

// Kernel side: one event every time a process starts an outgoing TCP
// connection. Hook: the stable tracepoint sock/inet_sock_set_state, when a
// socket enters SYN_SENT.
#include "vmlinux.h"
#include <bpf/bpf_helpers.h>

#define AF_INET 2
#define AF_INET6 10

char LICENSE[] SEC("license") = "GPL";

struct event {
    u32 pid;
    u16 family;
    u16 dport;
    u8 daddr[16]; // IPv4 uses the first 4 bytes
    char comm[16];
};

// Force struct event into BTF so bpf2go can generate the matching Go type.
const struct event *unused __attribute__((unused));

struct {
    __uint(type, BPF_MAP_TYPE_RINGBUF);
    __uint(max_entries, 256 * 1024);
} events SEC(".maps");

SEC("tracepoint/sock/inet_sock_set_state")
int trace_connect(struct trace_event_raw_inet_sock_set_state *ctx)
{
    if (ctx->protocol != IPPROTO_TCP || ctx->newstate != TCP_SYN_SENT)
        return 0; // only new outgoing TCP connections

    struct event *e = bpf_ringbuf_reserve(&events, sizeof(*e), 0);
    if (!e)
        return 0;

    e->pid = bpf_get_current_pid_tgid() >> 32;
    e->family = ctx->family;
    e->dport = ctx->dport;
    // Copy the address with a helper: the verifier forbids reading ctx
    // through a computed pointer (ctx + offset), which memcpy would do.
    if (ctx->family == AF_INET)
        bpf_probe_read_kernel(e->daddr, 4, ctx->daddr);
    else
        bpf_probe_read_kernel(e->daddr, 16, ctx->daddr_v6);
    bpf_get_current_comm(&e->comm, sizeof(e->comm));
    bpf_ringbuf_submit(e, 0);
    return 0;
}
