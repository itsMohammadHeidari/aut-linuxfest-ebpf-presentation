# Write your own, in Go

`connsnoop` prints every new outgoing TCP connection: which process, where
to, and which country that address is registered in.

- **Kernel side** ([`connsnoop.bpf.c`](connsnoop.bpf.c)): the
  `inet_sock_set_state` tracepoint; on `SYN_SENT`, send an event through a
  ring buffer.
- **User side** ([`main.go`](main.go), [cilium/ebpf](https://github.com/cilium/ebpf)):
  load the program (verifier + JIT), attach it, read the events, look up the
  country in an offline GeoIP database.
- `bpf2go` (`go generate`) compiles the C and embeds it, so the result is one
  Go binary with the eBPF program inside.

## Run it

```sh
just connsnoop # builds it, downloads the GeoIP database once (`just geoip`), runs it (requires sudo)
just connsnoop -hide firefox # hide some process names (comma-separated)
just connsnoop -local # also show loopback connections
```

Then make some connections in another terminal, for example:

```sh
curl -s https://example.com >/dev/null
```

`curl` often shows up twice: it tries IPv6 and IPv4 in parallel. Anycast
addresses show where they are registered, not where you reached them
(1.1.1.1 shows `AU`).

`just connsnoop-build` only builds it. It runs `go generate` (bpf2go), which
writes `bpf_bpfel.go` / `bpf_bpfeb.go`: they aren't in the repository, so
until then your editor reports `bpfObjects` and `loadBpfObjects` as undefined.

`go test -v` (in this directory) prints the country for a few known
addresses, to check the database.

Country data: [IP Geolocation by DB-IP](https://db-ip.com) (CC BY 4.0),
downloaded by `just geoip`; not part of this repository.
