package main

import (
	"crypto/tls"
	"embed"
	"flag"
	"fmt"
	"io/fs"
	"log"
	"net/http"
	"os"
	"path/filepath"
)

//go:embed web/*
var webFiles embed.FS

func main() {
	port := flag.Int("port", 8080, "HTTP port to listen on")
	httpsPort := flag.Int("https-port", 8443, "HTTPS port to listen on (0 to disable)")
	enableMDNS := flag.Bool("mdns", true, "Advertise qrbas.local via mDNS/Bonjour")
	dataDir := flag.String("data-dir", "", "Directory for database + cert (default: ~/.qrbas)")
	flag.Parse()

	if *dataDir == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			log.Fatal(err)
		}
		*dataDir = filepath.Join(home, ".qrbas")
	}

	if err := os.MkdirAll(*dataDir, 0755); err != nil {
		log.Fatal(err)
	}

	dbPath := filepath.Join(*dataDir, "qrbas.db")
	db, err := NewDatabase(dbPath)
	if err != nil {
		log.Fatalf("Failed to open database: %v", err)
	}
	defer db.Close()

	connectors := NewConnectorRegistry()
	connectors.Register(&NiagaraConnector{})

	webFS, err := fs.Sub(webFiles, "web")
	if err != nil {
		log.Fatal(err)
	}

	srv := NewServer(db, connectors, webFS)
	srv.HTTPPort = *port
	srv.HTTPSPort = *httpsPort
	srv.MDNSHost = MDNSFullHost

	// mDNS: advertise qrbas.local. Non-fatal if it fails (firewall, etc).
	if *enableMDNS {
		shutdown, err := StartMDNS(*port)
		if err != nil {
			log.Printf("mDNS: failed to start (%v) — falling back to IP only", err)
		} else {
			defer shutdown()
		}
	}

	// HTTPS: generate self-signed cert on first run. Non-fatal.
	if *httpsPort > 0 {
		cert, certPath, err := LoadOrGenerateCert(*dataDir)
		if err != nil {
			log.Printf("HTTPS: cert error (%v) — disabled", err)
		} else {
			srv.CertPath = certPath
			go func() {
				addr := fmt.Sprintf(":%d", *httpsPort)
				httpsSrv := &http.Server{
					Addr:      addr,
					Handler:   srv,
					TLSConfig: &tls.Config{Certificates: []tls.Certificate{cert}},
				}
				log.Printf("HTTPS listening on %s", addr)
				if err := httpsSrv.ListenAndServeTLS("", ""); err != nil {
					log.Printf("HTTPS: %v", err)
				}
			}()
		}
	}

	localIP := PrimaryLocalIP()

	fmt.Println()
	fmt.Println("  QRBAS Server")
	fmt.Println("  ──────────────────")
	fmt.Printf("  Local:    http://localhost:%d\n", *port)
	fmt.Printf("  Network:  http://%s:%d\n", localIP, *port)
	if *enableMDNS {
		fmt.Printf("  mDNS:     http://%s:%d\n", MDNSFullHost, *port)
	}
	if *httpsPort > 0 {
		fmt.Printf("  HTTPS:    https://%s:%d\n", localIP, *httpsPort)
	}
	fmt.Printf("  Data:     %s\n", *dataDir)
	fmt.Println()

	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%d", *port), srv))
}
