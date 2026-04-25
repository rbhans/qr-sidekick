# QR Sidekick - Agent Instructions

## Project Overview

QR Sidekick is a self-hosted Go server and browser PWA for BAS technicians. This repo now contains only the server, embedded PWA, and static marketing site.

Technicians scan QR codes with a phone camera and open equipment pages in the browser. The local server fetches live Niagara station data and stores configuration in SQLite.

## Tech Stack

- **Backend**: Go
- **HTTP**: `net/http`
- **Database**: SQLite via `modernc.org/sqlite`
- **QR generation**: `github.com/skip2/go-qrcode`
- **Network discovery**: `github.com/grandcat/zeroconf`
- **Frontend**: Plain HTML/CSS/JavaScript embedded in the Go binary
- **Marketing site**: Static HTML/CSS in `site/`, deployed by GitHub Pages Actions

## Project Structure

```
server/
├── main.go              # Entry point, flags, database init, HTTP server
├── database.go          # SQLite schema and CRUD
├── connector.go         # BAS connector interfaces and result types
├── niagara.go           # Niagara connector implementation
├── handlers.go          # HTTP API and page handlers
├── qr.go                # QR code generation
├── network.go           # LAN/mDNS helpers
└── web/                 # Embedded PWA assets
    ├── index.html
    ├── manifest.json
    ├── sw.js
    ├── css/
    └── js/

site/
├── index.html           # Public marketing/download page
└── style.css
```

## Development Commands

```bash
cd server
go run .
```

```bash
cd server
go test ./...
```

```bash
cd server
go build -trimpath -ldflags="-s -w" -o qr-sidekick-server .
```

## Runtime Notes

- Default web UI: `http://localhost:8080`
- Default data directory: `~/.qr-sidekick`
- Default database: `~/.qr-sidekick/qr_sidekick.db`
- Technicians do not authenticate; the LAN boundary is the intended security model.
- Station credentials are stored locally in SQLite and used only by the server when proxying BAS requests.

## GitHub Pages

The Pages workflow publishes `site/`. Configure GitHub Pages to use **GitHub Actions**, not branch/root publishing.
