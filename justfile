# "Beyond Syscalls" talk tasks. Run `just` to list them.
# On NixOS everything runs inside the flake's dev shell (flake.nix), which also loads talk/presenterm.yaml.
# Elsewhere run-env.sh checks each recipe's dependencies and uses the host's tools.

talk := "talk/talk.md"
build := "build"
flat := "build/talk-flat.md"

# Dependencies run-env.sh checks outside NixOS (see README.md for the full list)
slides := "kitty presenterm d2>=0.9.0"
snippets := "bash strace tcpdump bpftool dd"   # what the slides' +exec snippets run
bpfc := "clang llvm-strip bpftool pkg-config pc:libbpf"
live := "sudo bpftrace dd ping curl ip kubectl"  # what the demos' own commands run (demos/*/README.md)

# List recipes
default:
    @just --list

# Open a kitty window with the dev shell's environment (run the live demos' commands here)
kitty:
    ./run-env.sh "kitty" 'kitty --title linux-fest'

# Edit mode in its own kitty window: hot-reloads on save and jumps to the changed slide
dev:
    ./run-env.sh "{{ slides }} {{ snippets }}" 'kitty --title slides-dev presenterm {{ talk }}'

# Stage mode in its own kitty window (never inside tmux: it drops big titles). No hot reload.
present: flatten
    ./run-env.sh "{{ slides }} {{ snippets }}" 'kitty --title slides presenterm --present {{ flat }}'

# Speaker notes for the laptop screen in its own kitty window; follows `just present` (not `just dev`)
notes: flatten
    ./run-env.sh "{{ slides }}" 'kitty --title notes presenterm --listen-speaker-notes {{ flat }}'

# The 0.16.1 notes listener ignores includes, and both instances must open the same file.
# One-file copy of the talk for present/notes: includes inlined, notes moved above pauses
flatten:
    mkdir -p {{ build }}
    awk -f flatten.awk {{ talk }} > {{ flat }}

# Open the talk with overflow checking (note: falsely flags wrapped bullets in presenterm 0.16.1)
validate:
    ./run-env.sh "{{ slides }}" 'kitty --title slides-validate presenterm --validate-overflows {{ talk }}'

# Open the talk running every +exec/+validate snippet; errors if one fails (or a +expect:failure one succeeds)
snippets:
    ./run-env.sh "{{ slides }} {{ snippets }}" 'kitty --title slides-snippets presenterm --validate-snippets {{ talk }}'

# Parse and render every slide without opening the UI (fails on any slide error)
check:
    #!/usr/bin/env bash
    set -euo pipefail
    out=$(mktemp -d)
    trap 'rm -rf "$out"' EXIT
    ./run-env.sh "presenterm d2>=0.9.0" "presenterm --export-html -o $out/check.html {{ talk }}"
    echo "OK: all slides render"

# Self-contained HTML export (diagrams embedded) into build/
export-html:
    mkdir -p {{ build }}
    ./run-env.sh "presenterm d2>=0.9.0" 'presenterm --export-html -o {{ build }}/beyond-syscalls.html {{ talk }}'

# PDF for the organizers into build/ (presenterm renders it with weasyprint)
export-pdf:
    mkdir -p {{ build }}
    ./run-env.sh "presenterm d2>=0.9.0 weasyprint" 'presenterm --export-pdf -o {{ build }}/beyond-syscalls.pdf {{ talk }}'

# Preview presenterm's built-in themes
themes:
    ./run-env.sh "kitty presenterm" 'kitty --title themes presenterm --list-themes'

# Build the C demos, demos/*/*.bpf.c (+ vmlinux.h and compile_commands.json for clangd)
demos:
    ./run-env.sh "{{ bpfc }}" 'demos/build.sh'

# Demo D5 (demos/04-xdp): create the "demo" netns (10.0.0.2) + test web server, and build xdp.bpf.o (asks for sudo)
d5-setup: demos
    ./run-env.sh "sudo ip python3" 'sudo PYTHON="$(command -v python3)" demos/04-xdp/setup.sh'

# Demo D5 (demos/04-xdp): remove the netns and stop the web server (asks for sudo)
d5-teardown:
    ./run-env.sh "sudo ip" 'sudo demos/04-xdp/teardown.sh'

# Download the free DB-IP country database the Go demo reads (CC BY 4.0, ~8 MB; skipped if present)
geoip:
    #!/usr/bin/env bash
    set -euo pipefail
    f=demos/06-connsnoop/dbip-country-lite.mmdb
    [ -s "$f" ] && exit 0
    # this month's file; early in a month it may not be published yet, so fall back to last month's
    ./run-env.sh "curl gzip" '
      for m in "$(date +%Y-%m)" "$(date -d "$(date +%Y-%m-15) -1 month" +%Y-%m)"; do
        curl -fsSL "https://download.db-ip.com/free/dbip-country-lite-$m.mmdb.gz" -o "'"$f"'.gz" && break
      done
      gzip -dc "'"$f"'.gz" > "'"$f"'.tmp" && mv "'"$f"'.tmp" "'"$f"'" && rm "'"$f"'.gz"
      echo "downloaded '"$f"' ($m)"'

# Build the Go demo: bpf2go generates bpf_bpfe[lb].go (main.go needs them; also for your editor) + go build
connsnoop-build: demos geoip
    ./run-env.sh "go>=1.21 {{ bpfc }}" 'cd demos/06-connsnoop && BPF2GO_CFLAGS="-O2 -g -Wno-unused-command-line-argument -I$(pkg-config --variable=includedir libbpf) -I$PWD" go generate && go build -o connsnoop .'

# Extra args go to connsnoop, e.g. `just connsnoop -hide firefox -local`
# Go demo (demos/06-connsnoop): which process connects where, and to which country (asks for sudo)
connsnoop *args: connsnoop-build
    ./run-env.sh --host "sudo" 'cd demos/06-connsnoop && sudo ./connsnoop {{ args }}'

# Production demo (demos/05-tetragon): kind cluster "ebpf" (rootful podman) + Tetragon + a test pod (asks for sudo; ~1–2 GB of images)
k8s-up:
    ./run-env.sh "sudo podman kind kubectl helm" demos/05-tetragon/up.sh

# Production demo: Tetragon's live events for the demo pod (leave running in its own pane)
tetra-events:
    KUBECONFIG=$HOME/.kube/kind-ebpf ./run-env.sh "kubectl" 'kubectl exec -n kube-system ds/tetragon -c tetragon -- tetra getevents -o compact --pods demo'

# Delete the kind cluster (asks for sudo)
k8s-down:
    ./run-env.sh "sudo podman kind" demos/05-tetragon/down.sh

# Format the C demos with clang-format (style: demos/.clang-format)
fmt:
    ./run-env.sh "clang-format" 'clang-format -i demos/*/*.bpf.c'

# Enter the dev shell; outside NixOS: your shell, after checking every dependency the recipes use
shell:
    ./run-env.sh "{{ slides }} {{ snippets }} weasyprint {{ bpfc }} clang-format go>=1.21 python3 gzip {{ live }} podman kind helm"

# Remove everything the recipes generate (build/, compiled demos, vmlinux.h, GeoIP database)
clean:
    rm -rf {{ build }} demos/*/*.bpf.o demos/vmlinux.h demos/compile_commands.json demos/.cache
    rm -f demos/06-connsnoop/bpf_bpfe[bl].go demos/06-connsnoop/bpf_bpfe[bl].o demos/06-connsnoop/connsnoop demos/06-connsnoop/dbip-country-lite.mmdb*
