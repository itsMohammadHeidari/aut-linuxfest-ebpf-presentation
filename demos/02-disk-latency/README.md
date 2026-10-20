# D3 · Is the disk slow?

Time every block I/O request from the moment it is issued until it
completes, and print a latency histogram.

In one terminal, start the tracer and wait for `Attached 2 probes`:

```sh
sudo bpftrace -e '
tracepoint:block:block_rq_issue { @start[args->dev, args->sector] = nsecs; }
tracepoint:block:block_rq_complete /@start[args->dev, args->sector]/ {
  @usecs = hist((nsecs - @start[args->dev, args->sector]) / 1000);
  delete(@start[args->dev, args->sector]);
}'
```

In another, write 1 GB straight to the disk (`oflag=direct` skips the page
cache, so every write is real disk I/O):

```sh
dd if=/dev/zero of=~/ddtest bs=1M count=1000 oflag=direct status=progress; rm ~/ddtest
```

When `dd` finishes, press Ctrl-C in the first terminal: bpftrace prints the
`@usecs` histogram. bpftrace prints a warning or two first ("being cast to type: int64",
"Return value discarded"): they are harmless.

How it works:

1. `block_rq_issue`: save the start time in `@start[device, sector]`.
2. `block_rq_complete`: only if we saw the start (the `/.../` filter),
3. add `now − start` in µs to the histogram,
4. and delete the map entry.

On an SSD most requests land in the hundreds of µs, with a slow tail a few
buckets to the right: the average hides it, the histogram doesn't.
