// User side (cilium/ebpf): load the program, attach it to the tracepoint, read
// connection events from the ring buffer, and look up each destination's country
// in an offline GeoIP database (DB-IP "IP to Country Lite", CC BY 4.0).
package main

//go:generate go run github.com/cilium/ebpf/cmd/bpf2go -tags linux -type event bpf connsnoop.bpf.c

import (
	"bytes"
	"encoding/binary"
	"errors"
	"flag"
	"fmt"
	"log"
	"net/netip"
	"os"
	"os/signal"
	"strings"
	"syscall"

	"github.com/cilium/ebpf/link"
	"github.com/cilium/ebpf/ringbuf"
	"github.com/oschwald/maxminddb-golang/v2"
)

func main() {
	hide := flag.String("hide", "", "comma-separated process names to hide (e.g. tor,lyrebird)")
	showLocal := flag.Bool("local", false, "also show loopback (127.0.0.1, ::1) connections")
	flag.Parse()
	hidden := map[string]bool{}
	for _, n := range strings.Split(*hide, ",") {
		if n = strings.TrimSpace(n); n != "" {
			hidden[n] = true
		}
	}

	geo, err := maxminddb.Open("dbip-country-lite.mmdb")
	if err != nil {
		log.Fatalf("opening GeoIP database: %v", err)
	}
	defer geo.Close()

	// 1. Load the eBPF program and its ring buffer map (verifier + JIT happen here).
	var objs bpfObjects
	if err := loadBpfObjects(&objs, nil); err != nil {
		log.Fatalf("loading eBPF objects: %v", err)
	}
	defer objs.Close()

	// 2. Attach it to the hook.
	tp, err := link.Tracepoint("sock", "inet_sock_set_state", objs.TraceConnect, nil)
	if err != nil {
		log.Fatalf("attaching tracepoint: %v", err)
	}
	defer tp.Close()

	// 3. Read events from the ring buffer.
	rd, err := ringbuf.NewReader(objs.Events)
	if err != nil {
		log.Fatalf("opening ring buffer: %v", err)
	}
	defer rd.Close()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	go func() { <-stop; rd.Close() }()

	fmt.Println("tracing new TCP connections (country data: IP Geolocation by DB-IP.com, CC BY 4.0) · Ctrl-C to stop")
	fmt.Printf("%-8s %-16s %-40s %s\n", "PID", "PROCESS", "DESTINATION", "COUNTRY")
	for {
		rec, err := rd.Read()
		if errors.Is(err, ringbuf.ErrClosed) {
			return
		}
		if err != nil {
			continue
		}
		var e bpfEvent
		if err := binary.Read(bytes.NewReader(rec.RawSample), binary.NativeEndian, &e); err != nil {
			continue
		}
		ip := destIP(e)
		comm := cstr(e.Comm[:])
		if hidden[comm] || (!*showLocal && ip.IsLoopback()) {
			continue
		}
		port := e.Dport
		dest := netip.AddrPortFrom(ip, port).String()
		fmt.Printf("%-8d %-16s %-40s %s\n", e.Pid, comm, dest, country(geo, ip))
	}
}

func destIP(e bpfEvent) netip.Addr {
	if e.Family == 2 { // AF_INET
		return netip.AddrFrom4([4]byte(e.Daddr[:4]))
	}
	return netip.AddrFrom16(e.Daddr).Unmap()
}

func country(geo *maxminddb.Reader, ip netip.Addr) string {
	if ip.IsPrivate() || ip.IsLoopback() || ip.IsLinkLocalUnicast() {
		return "(local network)"
	}
	var rec struct {
		Country struct {
			ISOCode string            `maxminddb:"iso_code"`
			Names   map[string]string `maxminddb:"names"`
		} `maxminddb:"country"`
	}
	if err := geo.Lookup(ip).Decode(&rec); err != nil || rec.Country.ISOCode == "" {
		return "?"
	}
	return rec.Country.ISOCode + "  " + rec.Country.Names["en"]
}

// cstr turns a NUL-terminated C char array into a Go string.
func cstr(b []int8) string {
	out := make([]byte, 0, len(b))
	for _, c := range b {
		if c == 0 {
			break
		}
		out = append(out, byte(c))
	}
	return string(out)
}
