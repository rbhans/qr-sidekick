package main

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"log"
	"math/big"
	"net"
	"os"
	"path/filepath"
	"time"

	"github.com/grandcat/zeroconf"
)

// MDNSHostname is the short name advertised via mDNS.
// The full resolvable name is MDNSHostname + ".local".
const MDNSHostname = "qrsidekick"
const MDNSFullHost = MDNSHostname + ".local"

// GetLocalIPs returns routable IPv4 addresses bound to local interfaces.
// Loopback and link-local (169.254.x.x) addresses are skipped — techs can't
// reach those from their phones anyway.
func GetLocalIPs() []string {
	var out []string
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		return out
	}
	for _, a := range addrs {
		ipnet, ok := a.(*net.IPNet)
		if !ok {
			continue
		}
		ip4 := ipnet.IP.To4()
		if ip4 == nil || ipnet.IP.IsLoopback() || ipnet.IP.IsLinkLocalUnicast() {
			continue
		}
		out = append(out, ip4.String())
	}
	return out
}

// PrimaryLocalIP returns the first non-loopback IPv4, or "localhost".
func PrimaryLocalIP() string {
	ips := GetLocalIPs()
	if len(ips) == 0 {
		return "localhost"
	}
	return ips[0]
}

// StartMDNS advertises qrsidekick.local on the local network via mDNS/Bonjour.
// Returns a shutdown function (safe to call even on error).
func StartMDNS(port int) (func(), error) {
	server, err := zeroconf.RegisterProxy(
		"QR Sidekick",  // instance
		"_http._tcp",   // service
		"local.",       // domain
		port,           // port
		MDNSHostname,   // host (becomes qrsidekick.local)
		nil,            // ifaces (all)
		[]string{"path=/"},
		nil, // ips (auto)
	)
	if err != nil {
		return func() {}, err
	}
	log.Printf("mDNS: advertising %s on port %d", MDNSFullHost, port)
	return server.Shutdown, nil
}

// LoadOrGenerateCert loads an existing TLS cert from dataDir, or generates a
// new self-signed one. The cert is marked CA=true so users can install it as
// a trusted root on phones to silence HTTPS warnings.
//
// Returns the loaded certificate and the path to the cert.pem file.
func LoadOrGenerateCert(dataDir string) (tls.Certificate, string, error) {
	certPath := filepath.Join(dataDir, "cert.pem")
	keyPath := filepath.Join(dataDir, "key.pem")

	if cert, err := tls.LoadX509KeyPair(certPath, keyPath); err == nil {
		return cert, certPath, nil
	}

	log.Printf("Generating self-signed TLS cert at %s", certPath)

	priv, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		return tls.Certificate{}, "", err
	}

	serial, err := rand.Int(rand.Reader, new(big.Int).Lsh(big.NewInt(1), 128))
	if err != nil {
		return tls.Certificate{}, "", err
	}

	tmpl := x509.Certificate{
		SerialNumber: serial,
		Subject: pkix.Name{
			CommonName:   MDNSFullHost,
			Organization: []string{"QR Sidekick"},
		},
		NotBefore: time.Now().Add(-time.Hour),
		// Stay under iOS 13+ 825-day cap for maximum client acceptance.
		NotAfter:              time.Now().Add(800 * 24 * time.Hour),
		KeyUsage:              x509.KeyUsageDigitalSignature | x509.KeyUsageCertSign,
		ExtKeyUsage:           []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth, x509.ExtKeyUsageClientAuth},
		BasicConstraintsValid: true,
		IsCA:                  true,
		DNSNames:              []string{MDNSFullHost, "localhost"},
	}
	if h, err := os.Hostname(); err == nil && h != "" {
		tmpl.DNSNames = append(tmpl.DNSNames, h+".local", h)
	}
	tmpl.IPAddresses = []net.IP{net.ParseIP("127.0.0.1"), net.ParseIP("::1")}
	for _, ip := range GetLocalIPs() {
		if parsed := net.ParseIP(ip); parsed != nil {
			tmpl.IPAddresses = append(tmpl.IPAddresses, parsed)
		}
	}

	derBytes, err := x509.CreateCertificate(rand.Reader, &tmpl, &tmpl, &priv.PublicKey, priv)
	if err != nil {
		return tls.Certificate{}, "", err
	}

	certOut, err := os.Create(certPath)
	if err != nil {
		return tls.Certificate{}, "", err
	}
	if err := pem.Encode(certOut, &pem.Block{Type: "CERTIFICATE", Bytes: derBytes}); err != nil {
		certOut.Close()
		return tls.Certificate{}, "", err
	}
	certOut.Close()

	privBytes, err := x509.MarshalECPrivateKey(priv)
	if err != nil {
		return tls.Certificate{}, "", err
	}
	keyOut, err := os.OpenFile(keyPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0600)
	if err != nil {
		return tls.Certificate{}, "", err
	}
	if err := pem.Encode(keyOut, &pem.Block{Type: "EC PRIVATE KEY", Bytes: privBytes}); err != nil {
		keyOut.Close()
		return tls.Certificate{}, "", err
	}
	keyOut.Close()

	cert, err := tls.LoadX509KeyPair(certPath, keyPath)
	if err != nil {
		return tls.Certificate{}, "", err
	}
	return cert, certPath, nil
}
