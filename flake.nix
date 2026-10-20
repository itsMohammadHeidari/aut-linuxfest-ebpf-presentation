{
  description = "Beyond Syscalls: Inside the World of eBPF (slides + live demos)";

  # unstable is needed: d2 >= 0.9.0 (TALA layout engine) isn't in a stable release yet.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # Everything the justfile needs except what must come from the system itself
      # (setuid/capabilities): sudo, ping, and rootful podman. See README.md.
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            # slides
            presenterm
            d2            # renders the diagrams in the slides
            kitty         # the terminal the slides run in (talk/presenterm.yaml uses kitty-local images)
            python3Packages.weasyprint  # `just export-pdf`
            strace        # +exec snippet M1 (slide: the cost of strace)
            tcpdump       # +exec snippet M2 (tcpdump -d: classic BPF bytecode)

            # live demos and writing eBPF programs in C
            bpftrace      # D1, D3
            # unwrapped: Nix's cc-wrapper targets the host, not `--target bpf`
            # (BPF programs need no libc headers: only vmlinux.h and libbpf's).
            # Also provides clang-format (`just fmt`).
            llvmPackages.clang-unwrapped
            llvm          # llvm-strip, used by bpf2go
            libbpf
            bpftools      # bpftool: vmlinux.h, +exec snippet on helpers/kfuncs
            elfutils
            zlib
            pkg-config
            gnumake
            iproute2      # D5: network namespace + attaching XDP
            python3       # D5: test web server
            curl          # D5, Go demo, `just geoip`
            gzip          # `just geoip`

            # Go demo (cilium/ebpf + bpf2go)
            go

            # production demo: Tetragon on a local kind cluster (rootful podman, from the system)
            kind
            kubectl
            kubernetes-helm
            tetragon      # provides the `tetra` CLI
          ];

          # a flake path points at a store copy, so edits wouldn't show up.
          shellHook = ''
            export PRESENTERM_CONFIG_FILE="$PWD/talk/presenterm.yaml"
          '';
        };
      });
    };
}
