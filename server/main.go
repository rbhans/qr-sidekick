package main

import (
	"embed"
	"flag"
	"fmt"
	"io/fs"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
)

//go:embed web/*
var webFiles embed.FS

func main() {
	port := flag.Int("port", 8080, "Port to listen on")
	dataDir := flag.String("data-dir", "", "Directory for database (default: ~/.qr-sidekick)")
	flag.Parse()

	if *dataDir == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			log.Fatal(err)
		}
		*dataDir = filepath.Join(home, ".qr-sidekick")
	}

	if err := os.MkdirAll(*dataDir, 0755); err != nil {
		log.Fatal(err)
	}

	dbPath := filepath.Join(*dataDir, "qr_sidekick.db")
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

	addr := fmt.Sprintf(":%d", *port)
	localIP := getLocalIP()

	fmt.Println()
	fmt.Println("  QR Sidekick Server")
	fmt.Println("  ──────────────────")
	fmt.Printf("  Local:   http://localhost:%d\n", *port)
	fmt.Printf("  Network: http://%s:%d\n", localIP, *port)
	fmt.Printf("  Data:    %s\n", *dataDir)
	fmt.Println()

	log.Fatal(http.ListenAndServe(addr, srv))
}

func getLocalIP() string {
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		return "localhost"
	}
	for _, a := range addrs {
		if ipnet, ok := a.(*net.IPNet); ok && !ipnet.IP.IsLoopback() && ipnet.IP.To4() != nil {
			return ipnet.IP.String()
		}
	}
	return "localhost"
}
