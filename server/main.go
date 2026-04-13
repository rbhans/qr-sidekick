package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
)

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

	fmt.Println("QR Sidekick Server")
	fmt.Printf("  Data: %s\n", *dataDir)
	fmt.Printf("  Port: %d\n", *port)
	fmt.Println()
	fmt.Println("Server will start after remaining tasks are implemented.")
}
