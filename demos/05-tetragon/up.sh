#!/usr/bin/env bash
# Create the kind cluster "ebpf" on rootful podman and install Tetragon.
# Run via the justfile, as your user (it calls sudo itself):  just k8s-up
set -euo pipefail
export KUBECONFIG="$HOME/.kube/kind-ebpf"
KIND="$(command -v kind)"; PODMAN="$(command -v podman)"

# Root's podman needs an image signature policy
if ! sudo test -f /etc/containers/policy.json && ! sudo test -f /root/.config/containers/policy.json; then
  sudo mkdir -p /root/.config/containers
  echo '{"default":[{"type":"insecureAcceptAnything"}]}' | sudo tee /root/.config/containers/policy.json >/dev/null
  echo "created /root/.config/containers/policy.json"
fi

if ! sudo KIND_EXPERIMENTAL_PROVIDER=podman PATH="$(dirname "$PODMAN"):$PATH" "$KIND" get clusters 2>/dev/null | grep -qx ebpf; then
  sudo KIND_EXPERIMENTAL_PROVIDER=podman PATH="$(dirname "$PODMAN"):$PATH" "$KIND" create cluster --name ebpf --wait 120s
elif [ "$(sudo "$PODMAN" inspect -f '{{.State.Running}}' ebpf-control-plane)" != true ]; then
  sudo "$PODMAN" start ebpf-control-plane >/dev/null
  echo "started the stopped kind node ebpf-control-plane"
  restarted=1
fi
mkdir -p "$(dirname "$KUBECONFIG")"
sudo KIND_EXPERIMENTAL_PROVIDER=podman PATH="$(dirname "$PODMAN"):$PATH" "$KIND" get kubeconfig --name ebpf > "$KUBECONFIG"
if [ -n "${restarted:-}" ]; then
  for _ in $(seq 60); do kubectl get --raw /readyz >/dev/null 2>&1 && break; sleep 2; done
  kubectl wait --for=condition=Ready node --all --timeout 3m
fi

helm repo add cilium https://helm.cilium.io >/dev/null 2>&1 || true
helm repo update cilium >/dev/null
helm upgrade --install tetragon cilium/tetragon -n kube-system --version 1.6.1 --wait --timeout 10m
kubectl rollout status -n kube-system ds/tetragon --timeout 5m

if [ "$(kubectl get pod demo -o jsonpath='{.status.phase}' 2>/dev/null)" != Running ]; then
  kubectl delete pod demo --ignore-not-found --wait
  kubectl run demo --image=alpine:3.20 --restart=Never -- sleep 1d
fi
kubectl wait --for=condition=Ready pod/demo --timeout 3m
echo "cluster ready. export KUBECONFIG=$KUBECONFIG"
