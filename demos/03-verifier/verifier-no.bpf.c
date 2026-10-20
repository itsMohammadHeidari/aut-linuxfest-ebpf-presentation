// Slide "The verifier says no". A program that never ends would freeze
// the CPU it runs on. It compiles fine; the kernel refuses to load it.
#include "vmlinux.h" // IWYU pragma: keep (bpf_helpers.h needs its __u32/__u64)
#include <bpf/bpf_helpers.h>

char LICENSE[] SEC("license") = "GPL";

SEC("tracepoint/syscalls/sys_enter_execve")
int stuck(void *ctx)
{
    while (1) {
    } /* BUG: never ends */
    return 0;
}
