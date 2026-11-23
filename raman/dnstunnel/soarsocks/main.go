// soarsocks: a local SOCKS5 (TCP CONNECT only) server for Raman VPN's "DNS قطعی" tab that carries
// each connection through a Soar DNS tunnel (github.com/getlantern/soar, Apache-2.0, by the Lantern
// team). It listens on 127.0.0.1 only. Started by the app as an executable from its native library
// directory; the app's own package is excluded from its VPN, so the DNS queries leave directly.
//
// Usage: soarsocks -config <file.json> [-listen 127.0.0.1:18096] [-probe https://url]
//
// The config is the "profile" object of a soar:// link (schema whitedns.profile, version 1):
//
//	{"name":..., "resolvers":["1.1.1.1",...], "server":{"domain":..., "public_key":"<base64>"},
//	 "soarSettings":{"transport":"auto","discovery":true,"discoveryWant":2,...,"country":"IR"}}
package main

import (
	"context"
	"crypto/ed25519"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/getlantern/soar"
)

type settings struct {
	Transport            string `json:"transport"`
	Discovery            *bool  `json:"discovery"`
	DiscoveryWant        int    `json:"discoveryWant"`
	DiscoveryConcurrency int    `json:"discoveryConcurrency"`
	DiscoveryPaceMs      int    `json:"discoveryPaceMs"`
	SafeQName            int    `json:"safeQName"`
	MaxQName             int    `json:"maxQName"`
	MaxAnswer            int    `json:"maxAnswer"`
	HoldMs               int    `json:"holdMs"`
	MaxInflight          int    `json:"maxInflight"`
	MaxPathWindow        int    `json:"maxPathWindow"`
	MaxStreams           int    `json:"maxStreams"`
	StreamWindowKiB      int    `json:"streamWindowKiB"`
	SendBufferKiB        int    `json:"sendBufferKiB"`
	SessionIdleSeconds   int    `json:"sessionIdleSeconds"`
	DialTimeoutSeconds   int    `json:"dialTimeoutSeconds"`
	Country              string `json:"country"`
}

type profile struct {
	Name      string   `json:"name"`
	Resolvers []string `json:"resolvers"`
	Server    struct {
		Domain    string `json:"domain"`
		PublicKey string `json:"public_key"`
	} `json:"server"`
	Settings settings `json:"soarSettings"`
}

func decodeKey(s string) (ed25519.PublicKey, error) {
	s = strings.TrimSpace(s)
	for _, enc := range []*base64.Encoding{base64.StdEncoding, base64.RawStdEncoding, base64.URLEncoding, base64.RawURLEncoding} {
		if b, err := enc.DecodeString(s); err == nil && len(b) == ed25519.PublicKeySize {
			return ed25519.PublicKey(b), nil
		}
	}
	return nil, errors.New("server public_key is not a 32-byte base64 Ed25519 key")
}

// resolverAddr makes host:port from "1.2.3.4", "1.2.3.4:53", "2001:db8::1" or "[2001:db8::1]:53".
func resolverAddr(r string) (string, bool) {
	r = strings.TrimSpace(r)
	if r == "" {
		return "", false
	}
	if host, port, err := net.SplitHostPort(r); err == nil {
		if net.ParseIP(host) == nil {
			return "", false
		}
		return net.JoinHostPort(host, port), true
	}
	if net.ParseIP(strings.Trim(r, "[]")) == nil {
		return "", false
	}
	return net.JoinHostPort(strings.Trim(r, "[]"), "53"), true
}

func buildConfig(p profile, logger *slog.Logger) (soar.Config, time.Duration, error) {
	var cfg soar.Config
	zone := strings.TrimSuffix(strings.TrimSpace(p.Server.Domain), ".")
	if zone == "" {
		return cfg, 0, errors.New("server domain is empty")
	}
	key, err := decodeKey(p.Server.PublicKey)
	if err != nil {
		return cfg, 0, err
	}
	seen := map[string]bool{}
	var resolvers []string
	for _, r := range p.Resolvers {
		if a, ok := resolverAddr(r); ok && !seen[a] {
			seen[a] = true
			resolvers = append(resolvers, a)
		}
	}
	s := p.Settings
	discovery := s.Discovery != nil && *s.Discovery
	if len(resolvers) == 0 && !discovery {
		return cfg, 0, errors.New("no resolvers")
	}
	tcp := strings.ToLower(strings.TrimSpace(s.Transport))
	switch tcp {
	case "", "auto", "on", "only", "off":
	default:
		tcp = "auto"
	}
	cfg = soar.Config{
		Zone:          zone,
		ServerKey:     key,
		Resolvers:     resolvers,
		SafeQName:     s.SafeQName,
		MaxQName:      s.MaxQName,
		Hold:          time.Duration(s.HoldMs) * time.Millisecond,
		MaxInflight:   s.MaxInflight,
		MaxPathWindow: s.MaxPathWindow,
		MaxAnswer:     s.MaxAnswer,
		StreamWindow:  uint64(max(s.StreamWindowKiB, 0)) << 10,
		SendBuffer:    s.SendBufferKiB << 10,
		MaxStreams:    s.MaxStreams,
		SessionIdle:   time.Duration(s.SessionIdleSeconds) * time.Second,
		TCP:           tcp,
		Logger:        logger,
	}
	if discovery {
		cfg.Discovery = soar.Discovery{
			Enabled:     true,
			Country:     strings.ToUpper(strings.TrimSpace(s.Country)),
			Want:        s.DiscoveryWant,
			Concurrency: s.DiscoveryConcurrency,
			Pace:        time.Duration(s.DiscoveryPaceMs) * time.Millisecond,
		}
	}
	dial := time.Duration(s.DialTimeoutSeconds) * time.Second
	if dial <= 0 {
		dial = 90 * time.Second
	}
	return cfg, dial, nil
}

// ---- SOCKS5 (RFC 1928), no authentication, CONNECT only ----

func socksReply(c net.Conn, code byte) error {
	_, err := c.Write([]byte{5, code, 0, 1, 0, 0, 0, 0, 0, 0})
	return err
}

func readTarget(c net.Conn) (string, byte, error) {
	h := make([]byte, 2)
	if _, err := io.ReadFull(c, h); err != nil {
		return "", 0, err
	}
	if h[0] != 5 {
		return "", 0, errors.New("not SOCKS5")
	}
	methods := make([]byte, int(h[1]))
	if _, err := io.ReadFull(c, methods); err != nil {
		return "", 0, err
	}
	ok := false
	for _, m := range methods {
		if m == 0 {
			ok = true
		}
	}
	if !ok {
		_, _ = c.Write([]byte{5, 0xff})
		return "", 0, errors.New("client wants authentication")
	}
	if _, err := c.Write([]byte{5, 0}); err != nil {
		return "", 0, err
	}
	req := make([]byte, 4)
	if _, err := io.ReadFull(c, req); err != nil {
		return "", 0, err
	}
	var host string
	switch req[3] {
	case 1:
		b := make([]byte, 4)
		if _, err := io.ReadFull(c, b); err != nil {
			return "", 0, err
		}
		host = net.IP(b).String()
	case 4:
		b := make([]byte, 16)
		if _, err := io.ReadFull(c, b); err != nil {
			return "", 0, err
		}
		host = net.IP(b).String()
	case 3:
		l := make([]byte, 1)
		if _, err := io.ReadFull(c, l); err != nil {
			return "", 0, err
		}
		b := make([]byte, int(l[0]))
		if _, err := io.ReadFull(c, b); err != nil {
			return "", 0, err
		}
		host = string(b)
	default:
		return "", 8, errors.New("bad address type")
	}
	pb := make([]byte, 2)
	if _, err := io.ReadFull(c, pb); err != nil {
		return "", 0, err
	}
	if req[1] != 1 {
		return "", 7, fmt.Errorf("command %d not supported (TCP CONNECT only)", req[1])
	}
	return net.JoinHostPort(host, strconv.Itoa(int(binary.BigEndian.Uint16(pb)))), 0, nil
}

type closeWriter interface{ CloseWrite() error }

func pipe(a, b net.Conn) {
	var wg sync.WaitGroup
	cp := func(dst, src net.Conn) {
		defer wg.Done()
		_, _ = io.Copy(dst, src)
		if cw, ok := dst.(closeWriter); ok {
			_ = cw.CloseWrite()
		} else {
			_ = dst.Close()
		}
	}
	wg.Add(2)
	go cp(a, b)
	go cp(b, a)
	wg.Wait()
	_ = a.Close()
	_ = b.Close()
}

func serve(ctx context.Context, ln net.Listener, client *soar.Client, dialTimeout time.Duration, logger *slog.Logger) {
	for {
		c, err := ln.Accept()
		if err != nil {
			if ctx.Err() != nil {
				return
			}
			logger.Warn("accept", "err", err)
			time.Sleep(100 * time.Millisecond)
			continue
		}
		go func(c net.Conn) {
			_ = c.SetDeadline(time.Now().Add(30 * time.Second))
			target, code, err := readTarget(c)
			if err != nil {
				if code != 0 {
					_ = socksReply(c, code)
				}
				logger.Debug("socks", "err", err)
				_ = c.Close()
				return
			}
			_ = c.SetDeadline(time.Time{})
			dctx, cancel := context.WithTimeout(ctx, dialTimeout)
			start := time.Now()
			up, err := client.DialContext(dctx, "tcp", target)
			cancel()
			if err != nil {
				logger.Warn("dial", "target", target, "err", err)
				_ = socksReply(c, 1)
				_ = c.Close()
				return
			}
			logger.Debug("open", "target", target, "ms", time.Since(start).Milliseconds())
			if err := socksReply(c, 0); err != nil {
				_ = up.Close()
				_ = c.Close()
				return
			}
			pipe(c, up)
		}(c)
	}
}

func probe(client *soar.Client, url string, timeout time.Duration) {
	start := time.Now()
	tr := &http.Transport{
		DialContext:         client.DialContext,
		TLSHandshakeTimeout: timeout,
	}
	hc := &http.Client{Transport: tr, Timeout: timeout}
	resp, err := hc.Get(url)
	out := map[string]any{"ms": time.Since(start).Milliseconds()}
	if err != nil {
		out["ok"], out["error"] = false, err.Error()
	} else {
		_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 1<<20))
		_ = resp.Body.Close()
		out["ok"], out["status"] = resp.StatusCode < 500, resp.StatusCode
		out["ms"] = time.Since(start).Milliseconds()
	}
	b, _ := json.Marshal(out)
	fmt.Println(string(b))
}

func main() {
	configPath := flag.String("config", "", "profile JSON (the profile object of a soar:// link)")
	listen := flag.String("listen", "127.0.0.1:18096", "SOCKS5 listen address (127.0.0.1 only)")
	probeURL := flag.String("probe", "", "fetch this URL through the tunnel, print a JSON result and exit")
	verbose := flag.Bool("v", false, "debug logging")
	flag.Parse()

	level := slog.LevelInfo
	if *verbose {
		level = slog.LevelDebug
	}
	logger := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: level}))

	raw, err := os.ReadFile(*configPath)
	if err != nil {
		fmt.Fprintln(os.Stderr, "RAMAN_ERROR config:", err)
		os.Exit(2)
	}
	var p profile
	if err := json.Unmarshal(raw, &p); err != nil {
		fmt.Fprintln(os.Stderr, "RAMAN_ERROR config:", err)
		os.Exit(2)
	}
	cfg, dialTimeout, err := buildConfig(p, logger)
	if err != nil {
		fmt.Fprintln(os.Stderr, "RAMAN_ERROR config:", err)
		os.Exit(2)
	}
	client, err := soar.NewClient(cfg)
	if err != nil {
		fmt.Fprintln(os.Stderr, "RAMAN_ERROR client:", err)
		os.Exit(1)
	}
	defer client.Close()

	if *probeURL != "" {
		probe(client, *probeURL, dialTimeout)
		return
	}

	host, _, err := net.SplitHostPort(*listen)
	if err != nil || (host != "127.0.0.1" && host != "::1" && host != "localhost") {
		fmt.Fprintln(os.Stderr, "RAMAN_ERROR listen must be on 127.0.0.1")
		os.Exit(2)
	}
	ln, err := net.Listen("tcp", *listen)
	if err != nil {
		fmt.Fprintln(os.Stderr, "RAMAN_ERROR listen:", err)
		os.Exit(1)
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go func() { <-ctx.Done(); _ = ln.Close() }()
	fmt.Fprintf(os.Stderr, "RAMAN_READY soar %s zone=%s resolvers=%d\n", ln.Addr(), cfg.Zone, len(cfg.Resolvers))
	serve(ctx, ln, client, dialTimeout, logger)
}
