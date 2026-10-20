#!/usr/bin/env bash
# vmlinux.h is shared by every demo.
# Run via `just demos`
set -euo pipefail
cd "$(dirname "$0")"

[ -s vmlinux.h ] || bpftool btf dump file /sys/kernel/btf/vmlinux format c > vmlinux.h

inc=$(pkg-config --variable=includedir libbpf)
# Nix's clang wrapper finds glibc/linux headers via NIX_CFLAGS_COMPILE; clangd needs them spelled out.
read -r -a nixflags <<< "${NIX_CFLAGS_COMPILE:-}"
flags=(--target=bpf -O2 -g -I"$inc" -I"$PWD" "${nixflags[@]}")

entries=()
# connsnoop's real build is bpf2go (`just connsnoop`); compiling it here too gives
# clangd an entry for it and catches errors early.
for f in 01-execve/execve 03-verifier/verifier-no 04-xdp/xdp 06-connsnoop/connsnoop; do
    clang "${flags[@]}" -Wno-unused-command-line-argument -c "$f.bpf.c" -o "$f.bpf.o"
    args=$(printf '"%s",' clang "${flags[@]}" -c "$f.bpf.c")
    entries+=("{\"directory\":\"$PWD\",\"file\":\"$f.bpf.c\",\"arguments\":[${args%,}]}")
    echo "built $f.bpf.o"
done
(IFS=,; echo "[${entries[*]}]") > compile_commands.json
echo "wrote compile_commands.json"
