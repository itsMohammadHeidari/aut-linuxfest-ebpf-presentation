<!-- jump_to_middle -->

7 · eBPF in Production
===

<!--
speaker_note: |
  ⏱ ≤ 1:03 · section 7 starts
  SAY   "You won't write most of this.
        Here's what you can use."
-->

<!-- end_slide -->

The landscape
===

```d2 +render +width:85%
vars: {
  d2-config: {
    layout-engine: tala
    # gruvbox palette for d2's color codes (base theme 200 is set in talk.md)
    theme-overrides: {
      N1: "#ebdbb2"
      N2: "#a89984"
      N3: "#928374"
      N4: "#504945"
      N5: "#3c3836"
      N6: "#32302f"
      N7: "#3c3836"
      B1: "#a89984"
      B2: "#928374"
      B3: "#3c3836"
      B4: "#32302f"
      B5: "#32302f"
      B6: "#32302f"
      AA2: "#d3869b"
      AA4: "#3c3836"
      AA5: "#3c3836"
      AB4: "#3c3836"
      AB5: "#3c3836"
    }
  }
}

style.fill: "#282828"

classes: {
  box: {style: {fill: "#3c3836"; stroke: "#665c54"; stroke-width: 2; font-color: "#ebdbb2"; border-radius: 6; font-size: 26}}
  user: {style: {fill: "#32302f"; stroke: "#83a598"; stroke-width: 3; font-color: "#83a598"; font-size: 26; bold: true}}
  kern: {style: {fill: "#32302f"; stroke: "#fb4934"; stroke-width: 3; font-color: "#fb4934"; font-size: 26; bold: true}}
  ebpf: {style: {fill: "#3c3836"; stroke: "#d3869b"; stroke-width: 3; font-color: "#d3869b"; border-radius: 6; font-size: 26; bold: true}}
  good: {style: {fill: "#3c3836"; stroke: "#b8bb26"; stroke-width: 3; font-color: "#b8bb26"; border-radius: 6; font-size: 26; bold: true}}
  bad: {style: {fill: "#3c3836"; stroke: "#fb4934"; stroke-width: 3; font-color: "#fb4934"; border-radius: 6; font-size: 26}}
  flow: {style: {stroke: "#fabd2f"; stroke-width: 4; font-color: "#fabd2f"; font-size: 24}}
  dim: {style: {stroke: "#928374"; stroke-width: 3; stroke-dash: 4; font-color: "#928374"; font-size: 22}}
  note: {shape: text; style: {font-color: "#928374"; font-size: 22; italic: true}}
}

g: "" {
  grid-columns: 4
  grid-gap: 24
  style: {fill: transparent; stroke-width: 0}
  net: "Networking" {class: user; grid-columns: 1; c: "Cilium" {class: box}; k: "Katran" {class: box}; ca: "Calico eBPF" {class: box}}
  sec: "Security" {class: kern; grid-columns: 1; t: "Tetragon" {class: box}; f: "Falco" {class: box}; ka: "KubeArmor" {class: box}}
  obs: "Observability" {class: good; grid-columns: 1; h: "Hubble" {class: box}; p: "Pixie" {class: box}; b: "Grafana Beyla" {class: box}}
  prof: "Profiling" {class: ebpf; grid-columns: 1; pa: "Parca" {class: box}; py: "Pyroscope" {class: box}; bc: "BCC tools" {class: box}}
}
```

<!--
speaker_note: |
  ⏱ ≤ 1:03
  networking        Cilium, Katran, Calico eBPF
  security          Tetragon, Falco, KubeArmor
  observability     Hubble, Pixie, Beyla
  profiling         Parca, Pyroscope, BCC
  SAY               you probably run one already
  WHY K8S           containers isolated, KERNEL shared
                    → one tool per node sees every pod
  Pixie, Beyla      metrics and traces, no SDK
  Parca, Pyroscope  always-on CPU profiles
  NEXT              "The one you'll meet first: Cilium."
-->

<!-- end_slide -->

Cilium and Hubble
===

<!--
speaker_note: |
  ⏱ ≤ 1:04 · your audience runs this
  CNI         Kubernetes networking on eBPF
  kube-proxy  replaced: Services via eBPF maps
  policies    by pod LABELS, not changing IPs
  Hubble      every flow, DNS, HTTP between pods
              no sidecar
  PAUSE→      GKE Dataplane V2 · CNCF graduated 2023
  ASK         "Who here runs Cilium?"
  NEXT        "Networking done. Now security."
-->

* A **Kubernetes network plugin (CNI)** built on eBPF
* Replaces `kube-proxy`: service routing through **eBPF maps**, not iptables
* Network policies based on **pod identity (labels)**, not IP addresses
* **Hubble**: see every flow, DNS query, and HTTP request between pods

<!-- pause -->

<!-- new_line -->

Used by **GKE Dataplane V2** and many managed Kubernetes platforms.
**Graduated in the CNCF** in 2023.

<!-- end_slide -->

Tetragon and Falco: runtime security
===

<!--
speaker_note: |
  ⏱ ≤ 1:06
  Falco     kernel events + rules ("shell in a container")
            → DETECTS, alerts
  Tetragon  same events + pod/namespace
            → detects AND ENFORCES in the kernel
  ONE LINE  "Alert after, vs block before."
  SAY       security used to cost performance;
            eBPF changed that
  NEXT      "Let's block something."
-->

<!-- column_layout: [1, 1] -->

<!-- column: 0 -->

### Falco

* Watches syscalls and kernel events
* **Rules** flag suspicious behavior: "a shell started in a container"
* **Detects** and alerts
* CNCF graduated (2024)

<!-- column: 1 -->

### Tetragon

* Watches process, file, and network events, **with Kubernetes context**
* **Detects and enforces** inside the kernel: can kill the process **before** the action completes
* From the Cilium team

<!-- reset_layout -->

<!-- end_slide -->

Tetragon: block it in the kernel
===

```yaml
apiVersion: cilium.io/v1alpha1
kind: TracingPolicyNamespaced
metadata:
  name: block-shadow
  namespace: default
spec:
  kprobes:
  - call: "security_file_permission"
    syscall: false
    args:
    - index: 0
      type: "file"
    - index: 1
      type: "int"
    selectors:
    - matchArgs:
      - index: 0
        operator: "Equal"
        values: ["/etc/shadow"]
      matchActions:
      - action: Sigkill
```

<!--
speaker_note: |
  ⏱ ≤ 1:07 · read the policy · live if cluster is up
  SAY      a Kubernetes resource: kubectl apply
  THE YAML (one sentence)
    kind: …Namespaced              a Tetragon rule for one
                                   namespace (default)
    call security_file_permission  WHEN the kernel asks
                                   "may it open this file?"
    args index 0, file             look at WHICH file
    values /etc/shadow             IF it's the password file
    action Sigkill                 THEN kill the process
  RESULT   any process in that namespace: killed before
           the read finishes. Not an alert: blocked.
  LIVE     tested Oct 15 · demo tab, 2 panes
  COPY PANE 0 (Tetragon's live events, leave running)
  cd ~/Projects/linux-fest-aut
  just tetra-events
  COPY PANE 1
  cd ~/Projects/linux-fest-aut
  export KUBECONFIG=~/.kube/kind-ebpf
  kubectl exec demo -- cat /etc/shadow
    → prints the file
  kubectl apply -f demos/05-tetragon/block-shadow.yaml
    → the policy is on
  kubectl exec demo -- cat /etc/shadow
    → "command terminated with exit code 137"
      137 = 128 + 9 = SIGKILL, from the kernel
  kubectl exec demo -- cat /etc/hostname
    → still works: only /etc/shadow is blocked
  kubectl delete -f demos/05-tetragon/block-shadow.yaml
    → the policy is off again
  POINT    pane 0: 🚀 process · 📚 read · 💥 exit SIGKILL,
           each with its pod name (default/demo)
  WHY NS   kind shares my kernel: a cluster-wide policy
           would also kill my laptop's sudo checks
  NEXT     "Before you deploy all this: the limits."
-->
