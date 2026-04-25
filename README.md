# QR Sidekick

Self-hosted QR equipment pages for BAS teams. Run one small server on the local network, add Niagara stations, print QR codes for equipment, and let technicians scan with a phone camera to see live point data in the browser.

No app store. No cloud backend. No technician logins.

## What Is In This Repo

```
server/              Go server, embedded PWA, SQLite storage, Niagara connector
site/                Static marketing/download site for GitHub Pages
docs/superpowers/    Implementation planning notes
.github/workflows/   Pages deployment and release builds
```

## Quick Start

```bash
cd server
go run .
```

Open `http://localhost:8080`, add a station from Admin, configure equipment, then print QR codes.

The server stores data in `~/.qr-sidekick/qr_sidekick.db` by default. Use flags to change runtime behavior:

```bash
go run . -port 8080 -data-dir ~/.qr-sidekick
```

## Build

```bash
cd server
go build -trimpath -ldflags="-s -w" -o qr-sidekick-server .
```

Cross-platform release builds are handled by `.github/workflows/release.yml` when pushing a `v*` tag.

## Test

```bash
cd server
go test ./...
```

## Marketing Site

The public GitHub Pages site lives in `site/`. The Pages workflow publishes that directory through GitHub Actions.

In GitHub Pages settings, use **GitHub Actions** as the source. If Pages is pointed at the repository root instead, the root `index.html` redirects to `site/` as a fallback, but the intended deployment path is the workflow.
