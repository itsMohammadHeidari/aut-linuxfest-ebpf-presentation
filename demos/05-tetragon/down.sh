#!/usr/bin/env bash
# Delete the kind cluster "ebpf".
set -euo pipefail
sudo KIND_EXPERIMENTAL_PROVIDER=podman PATH="$(dirname "$(command -v podman)"):$PATH" "$(command -v kind)" delete cluster --name ebpf
rm -f "$HOME/.kube/kind-ebpf"
