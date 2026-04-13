# QR Sidekick Server

Self-hosted companion for QR Sidekick. Runs on your network — technicians scan QR codes on equipment and see live BAS data in their browser. No app store, no cloud, no logins.

## Quick Start

1. Download for your OS from Releases
2. Run: `./qr-sidekick-server`
3. Open `http://localhost:8080`
4. Go to Admin → add a Niagara station (enter host + credentials)
5. Browse equipment, configure points, print QR codes
6. Stick QR codes on equipment — techs scan and see live data

## Build from Source

```bash
cd server
go build -o qr-sidekick-server
./qr-sidekick-server
```

## Cross-compile

```bash
GOOS=windows GOARCH=amd64 go build -o qr-sidekick.exe
GOOS=darwin  GOARCH=arm64 go build -o qr-sidekick-mac
GOOS=linux   GOARCH=amd64 go build -o qr-sidekick-linux
```

## Options

| Flag | Default | Description |
|------|---------|-------------|
| `-port` | 8080 | Port to listen on |
| `-data-dir` | ~/.qr-sidekick | Database directory |

## How It Works

The server stores Niagara station credentials and proxies all BAS requests. Technicians never need to log in — they scan a QR code, the server fetches live data from the station, and returns it to the browser.

```
Tech scans QR → Phone browser opens URL → Server fetches from Niagara → Live data displayed
```

## Supported BAS Systems

- **Niagara 4** — station tree browsing, live point values, status colors
- Architecture supports adding new protocols via the `Connector` interface

## Adding a New BAS Connector

Implement the `Connector` interface in a new `.go` file:

```go
type MyConnector struct{}

func (c *MyConnector) DisplayName() string { return "My BAS" }
func (c *MyConnector) TypeID() string      { return "my-bas" }
func (c *MyConnector) TestConnection(host string, port int, protocol, username, password string) ConnResult { ... }
func (c *MyConnector) FetchTree(host string, port int, protocol, username, password string) TreeResult { ... }
func (c *MyConnector) FetchSnapshot(host string, port int, protocol, username, password, equipmentPath string) SnapResult { ... }
```

Register it in `main.go`:
```go
connectors.Register(&MyConnector{})
```

The admin UI will automatically show the new connector type in the station form dropdown.

## License

Open source.
