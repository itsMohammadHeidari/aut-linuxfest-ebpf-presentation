// Slide "An XDP program: drop all ICMP" / demo D5: drop every ICMP (ping)
// packet, pass the rest.
#include "vmlinux.h"
#include <bpf/bpf_endian.h>
#include <bpf/bpf_helpers.h>

#define ETH_P_IP 0x0800 /* IPv4's EtherType; a #define, so not in vmlinux.h */

char LICENSE[] SEC("license") = "GPL";

SEC("xdp")
int drop_icmp(struct xdp_md *ctx)
{
    void *data = (void *)(long)ctx->data;
    void *data_end = (void *)(long)ctx->data_end;

    struct ethhdr *eth = data;
    if ((void *)(eth + 1) > data_end)
        return XDP_PASS;
    if (eth->h_proto != bpf_htons(ETH_P_IP))
        return XDP_PASS;

    struct iphdr *ip = (void *)(eth + 1);
    if ((void *)(ip + 1) > data_end)
        return XDP_PASS;

    return ip->protocol == IPPROTO_ICMP ? XDP_DROP : XDP_PASS;
}
