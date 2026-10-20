When kernel code goes wrong
===

<!-- new_lines: 2 -->

**July 19, 2024**: a faulty update to a security product's **kernel driver**
crashed about **8.5 million** Windows machines.

Airlines, hospitals, and banks went down.

<!-- pause -->

<!-- new_lines: 2 -->

Kernel code is powerful, and one mistake takes down everything.

**What if the kernel could _check_ your code before running it?**

<!--
speaker_note: |
  ⏱ ≤ 0:13
  SAY       July 19, 2024: a security product's kernel
            driver crashed ~8.5M Windows machines
            (CrowdStrike): airlines, hospitals, banks
  LESSON    kernel code = unlimited power; one bug = all down
  PAUSE→    slowly: "What if the kernel could CHECK your
            code before running it?" Let it hang.
  IF ASKED  Windows, yes; a Linux module is the same risk
  NEXT      "We already did this once, somewhere you use daily."
-->

<!-- end_slide -->

The idea: a programmable kernel
===

<!-- column_layout: [1, 1] -->

<!-- column: 0 -->

### Your browser

* Runs untrusted **JavaScript** from any website
* **Sandboxed**, **checked**, **JIT-compiled**
* Changed what a web page can be

<!-- column: 1 -->

### Linux with eBPF

* Runs your small programs **inside the kernel**
* **Verified** before loading, **JIT-compiled** to native code
* Attached to events, with **no reboot**

<!-- reset_layout -->

<!-- pause -->

> "eBPF does to Linux what JavaScript does to HTML. (Sort of.)"
> — Brendan Gregg, 2019

<!--
speaker_note: |
  ⏱ ≤ 0:14
  LEFT     browser: untrusted JavaScript, sandboxed,
           checked, JIT-compiled → pages became apps
  RIGHT    eBPF: small programs IN the kernel,
           verified, JIT-compiled, on events, no reboot
  PAUSE→   read the quote; keep "(Sort of.)": a laugh
  KITCHEN  hand in your recipe, the chef checks it,
           cooked at kitchen speed
  WHO      Meta, Google, Netflix, Microsoft, Cisco
  NEXT     "This didn't start in 2014. It started in 1992."
-->
