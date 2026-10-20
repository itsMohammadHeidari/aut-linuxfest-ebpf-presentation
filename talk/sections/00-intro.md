About me
===

<!-- new_lines: 2 -->

**Mohammad Heidari**

Started as a **Go developer**, now a **Platform Engineer**

Multi-tenant production Kubernetes in private clouds:
telecom, fintech, health tech

<!-- pause -->

<!-- new_lines: 1 -->

_Not a kernel developer._ That's the point:
eBPF is no longer only for kernel developers.

<!--
speaker_note: |
  ⏱ ≤ 0:01 here
  TITLE     Salam, welcome. "Beyond Syscalls"
            how apps run on Linux → why not enough →
            eBPF: small safe programs INSIDE the kernel
            90 min: talk + live demos + Q&A
  ABOUT ME  started as a Go developer, now a platform
            engineer: multi-tenant Kubernetes,
            private clouds: telecom, fintech, health tech
            not a kernel developer: that's the point
  NEXT      "Here's the road we'll take."
-->

<!-- end_slide -->

Agenda
===

<!--
speaker_note: |
  ⏱ ≤ 0:01 · don't read every line
  SAY    a practical tour, a platform engineer's view
  LEFT   WHY: the limits, the history, what changes
  RIGHT  HOW: inside, hooks, networking, production
  DEMOS  3 live + 2 mini, on this laptop
  Q&A    8 min at the end
  NEXT   "Let's start with why eBPF exists."
-->

<!-- new_lines: 3 -->

<!-- column_layout: [1, 2, 1] -->

<!-- column: 1 -->

1. **Why eBPF exists**
2. **The story of BPF**
3. **Beyond syscalls**
4. **How eBPF works**
5. **Hook points**
6. **Networking**
7. **eBPF in production**
8. **Getting started**

<!-- reset_layout -->
