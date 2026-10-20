# Tetragon · Block it in the kernel

[Tetragon](https://tetragon.io) enforces a policy in the kernel:
[`block-shadow.yaml`](block-shadow.yaml) kills any process in the `default`
namespace that tries to read `/etc/shadow`, before the read finishes.

The policy is namespaced on purpose: kind runs on your machine's kernel, so a
cluster-wide policy would also kill your own system's password checks (and
with them, sudo).

## Setup

```sh
# kind cluster "ebpf" on rootful podman + Tetragon + a test pod "demo" (requires sudo; ~1–2 GB of images)
just k8s-up
```

## Run it

In one terminal, follow Tetragon's events for the pod (leave it running):

```sh
just tetra-events
```

In another:

```sh
export KUBECONFIG=~/.kube/kind-ebpf
kubectl exec demo -- cat /etc/shadow # prints the file
kubectl apply -f demos/05-tetragon/block-shadow.yaml # policy on
kubectl exec demo -- cat /etc/shadow # exit code 137
kubectl exec demo -- cat /etc/hostname  # still works
kubectl delete -f demos/05-tetragon/block-shadow.yaml # policy off
```

Exit code 137 = 128 + 9: SIGKILL, sent by the kernel. The events terminal
shows the process start, the read, and the kill, each with the pod name
`default/demo`. Not an alert after the fact: blocked.

## Clean up

```sh
# delete the kind cluster (requires sudo)
just k8s-down
```
