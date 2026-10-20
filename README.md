# Beyond Syscalls: Inside the World of eBPF

Slides and live demos from my talk at the Linux Festival,
Amirkabir University of Technology, in October 2026.

The slides are plain Markdown, rendered in the terminal with
[presenterm](https://github.com/mfontanini/presenterm); the diagrams are
[d2](https://d2lang.com) blocks inside the slides. The abstract is in
[`abstract.md`](abstract.md).

## Layout

```text
talk/
  talk.md            the deck: front matter + includes of sections/
  sections/          the slides, one file per chapter (00-intro … 09-closing)
  presenterm.yaml    presenterm config (loaded automatically by the recipes)
demos/               one directory per demo, each with a README (index: demos/README.md)
  01-execve/         D1: every program that starts (bpftrace + the same tracer in C)
  02-disk-latency/   D3: disk I/O latency histogram (bpftrace)
  03-verifier/       a program the verifier rejects
  04-xdp/            D5: drop pings in the driver (XDP) + test network setup
  05-tetragon/       kind + Tetragon, and the policy that blocks reading /etc/shadow
  06-connsnoop/      Go demo (cilium/ebpf): who connects where, and to which country
  build.sh           builds every C demo (`just demos`)
justfile             every task; run `just` to list them
flake.nix            the whole toolchain on NixOS (dev shell; pinned by flake.lock)
run-env.sh           runs a recipe in the dev shell (NixOS) or on the host (other distros)
flatten.awk          one-file copy of the deck for presenting with speaker notes
```

## Quick start

```sh
just dev # edit mode: hot-reloads the slides in a new kitty window
just present # stage mode, in its own kitty window
just notes # speaker notes in a second kitty window (start after `just present`)
just check # render every slide without opening the UI
just # list everything else
```

- **NixOS:** every recipe runs inside the flake's dev shell (`nix develop`), which
  provides everything
  in the list below except the [system requirements](#system-requirements).
- **Other distros:** recipes run with the tools installed on your machine.
  Each recipe checks its requirements first and lists anything that is
  missing (or too old); install those with your package manager or from
  upstream, then run it again.
- Override the detection with `RUN_ENV=nix` (Nix on another distro, e.g.
  with nixGL for kitty) or `RUN_ENV=native`.
- `nix develop` (or direnv's `use flake`) gives you the same shell by hand;
  `nix flake update` moves the pin to a newer nixos-unstable.

## Requirements

On NixOS, everything in this section except the system requirements comes
from the flake. On other distros, install what you need for the recipes
you want to run. Versions are minimums where stated, otherwise any recent
version works (tested versions in brackets).

### Everywhere

| Requirement | Why |
|---|---|
| Linux | eBPF is a Linux kernel feature |
| [just](https://github.com/casey/just) | runs the recipes |
| bash, coreutils, grep, sed, awk | the recipes and helper scripts |
| Nix (NixOS only; flakes need not be enabled in `nix.conf`) | the dev shell: every package comes from the nixos-unstable commit pinned in `flake.lock` |

### System requirements

These need privileges or kernel support, so even on NixOS they come from the
system, not from the flake.

| Requirement | Needed by |
|---|---|
| sudo (root access) | every demo that loads eBPF programs: D1, D3, D5, Go demo, Tetragon |
| Kernel with BTF (`/sys/kernel/btf/vmlinux`) and BPF enabled; 5.8+ (ring buffer) | `just demos`, the Go demos, bpftrace, Tetragon. Any recent distro kernel has it [6.18] |
| ping | D5 |
| podman, usable as root | `just k8s-up` / `just k8s-down` (kind runs on rootful podman). On NixOS: `virtualisation.podman.enable = true;` |
| Internet access | first `go build` (Go modules), `just geoip`, `just k8s-up` (Helm chart + images, ~1–2 GB) |

### Slides

| Requirement | Needed by |
|---|---|
| presenterm [0.16.1] | every slide recipe |
| d2 **0.9.0 or newer** (TALA layout engine) | rendering the diagrams: `dev`, `present`, `notes`, `validate`, `snippets`, `check`, exports. Distro packages are often older; see [d2's install guide](https://d2lang.com/tour/install) |
| kitty [0.49.1] | `kitty`, `dev`, `present`, `notes`, `validate`, `snippets`, `themes` (the slides use kitty's image protocol) |
| weasyprint | `just export-pdf` |
| strace, tcpdump, bpftool, dd | the slides' runnable snippets (Ctrl+E on stage; all of them under `just snippets`) |

### Demos

| Requirement | Needed by |
|---|---|
| clang (with the BPF target) [21] | `just demos`, `just connsnoop` |
| llvm-strip (part of LLVM) | `just connsnoop` (bpf2go strips the object) |
| bpftool [6.18] | `just demos` (generates `vmlinux.h`) |
| pkg-config and libbpf development files (headers) | `just demos`, `just connsnoop` |
| clang-format | `just fmt` |
| bpftrace [0.25] | D1, D3 |
| dd | D3 |
| iproute2 (`ip`, with XDP support), python3 | D5: `just d5-setup` / `just d5-teardown` |
| curl | D5, the Go demo, `just geoip` |
| gzip | `just geoip` |
| Go **1.21 or newer** (fetches the 1.26 toolchain from `go.mod` automatically) | `just connsnoop` |
| kind, kubectl, Helm | `just k8s-up` / `just k8s-down`; kubectl also for `just tetra-events` and the Tetragon demo |
| tetra (Tetragon CLI) | optional: `just tetra-events` runs it inside the Tetragon pod |

## Demos

Each demo's directory has a README with its commands and what to expect;
start at [`demos/README.md`](demos/README.md). Most demos load programs into
the kernel, so they ask for `sudo`: run them on a machine you own, in
`just kitty` or `just shell` so the tools above are on your `PATH`.

| Recipe | What it does |
|---|---|
| `just demos` | Build the C demos, `demos/*/*.bpf.c` (+ `vmlinux.h`, `compile_commands.json` for clangd) |
| `just d5-setup` / `just d5-teardown` | A network namespace at 10.0.0.2 for the XDP packet-drop demo |
| `just connsnoop-build` | Build the Go demo without running it (also generates the Go code `main.go` needs, for your editor) |
| `just connsnoop [args]` | Go demo: every new TCP connection, with process and destination country |
| `just k8s-up` / `just k8s-down` | kind cluster on rootful podman with Tetragon |
| `just tetra-events` | Tetragon's live events for the demo pod |
| `just clean` | Remove everything the recipes generate |

## License

- Code (`demos/`, `justfile`, `*.sh`, `*.awk`, `*.nix`): [MIT](LICENSE).
- Slides and text (`talk/`, `abstract.md`, the READMEs):
  [CC BY 4.0](LICENSE-slides).
- The Go demo downloads DB-IP's free country database (`just geoip`):
  [IP Geolocation by DB-IP](https://db-ip.com), CC BY 4.0. It is not part
  of this repository.
- The eBPF C programs declare `GPL` to the kernel (required for the GPL-only
  helpers they use).
