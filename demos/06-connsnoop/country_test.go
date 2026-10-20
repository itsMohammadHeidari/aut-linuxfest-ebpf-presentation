package main

import (
	"net/netip"
	"testing"

	"github.com/oschwald/maxminddb-golang/v2"
)

func TestCountry(t *testing.T) {
	geo, err := maxminddb.Open("dbip-country-lite.mmdb")
	if err != nil {
		t.Fatal(err)
	}
	defer geo.Close()
	for _, s := range []string{"8.8.8.8", "1.1.1.1", "185.143.233.120", "151.101.1.140", "192.168.1.10", "2a00:1450:4001:80b::200e"} {
		t.Logf("%-26s %s", s, country(geo, netip.MustParseAddr(s)))
	}
}
