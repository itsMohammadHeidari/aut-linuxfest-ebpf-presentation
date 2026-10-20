# The verifier says no

[`verifier-no.bpf.c`](verifier-no.bpf.c) is a program that never ends
(`while (1) {}`). It would freeze the CPU it runs on, so it compiles fine but
the kernel's verifier refuses to load it:

```sh
just demos
sudo bpftool prog load demos/03-verifier/verifier-no.bpf.o /sys/fs/bpf/stuck
```

The load fails, and bpftool prints the verifier's log: it walks the program,
finds the jump back to itself (`goto pc-1`), and rejects it with an
"infinite loop detected" error. Nothing is loaded, so there is nothing to
clean up.
