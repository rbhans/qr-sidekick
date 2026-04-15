# Go Server + PWA Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a self-hosted Go companion server with PWA frontend that lets HVAC technicians scan QR codes on equipment and see live BAS data — no app store, no cloud, no logins.

**Architecture:** A single Go binary serves a REST API and static PWA files. SQLite stores station configs, equipment, and credentials. A `Connector` interface abstracts BAS communication (Niagara first). The PWA has three sections: QR Scanner (camera), Equipment Viewer (live data), and Admin (station/equipment management). No authentication — network boundary is the security model.

**Tech Stack:** Go 1.26, `modernc.org/sqlite`, `net/http` (stdlib), `github.com/google/uuid`, `github.com/skip2/go-qrcode`. Frontend: plain HTML/CSS/JS, `html5-qrcode` library for camera scanning.

---

## File Structure

```
server/
├── go.mod
├── go.sum
├── main.go                              # Entry point: parse flags, init DB, start HTTP server
├── database.go                          # SQLite schema, CRUD for stations/equipment/notes/settings
├── database_test.go                     # Database tests
├── connector.go                         # Connector interface + result types
├── niagara.go                           # Niagara 4 connector (ported from niagara_client.dart)
├── niagara_test.go                      # Niagara CSV parsing tests
├── handlers.go                          # All HTTP route handlers
├── handlers_test.go                     # API integration tests
├── qr.go                               # QR code PNG generation
├── web/                                 # Static PWA files (embedded in binary via go:embed)
│   ├── index.html                       # Single-page app shell
│   ├── manifest.json                    # PWA manifest
│   ├── sw.js                            # Service worker
│   ├── css/
│   │   └── style.css                    # Dark basidekick theme
│   └── js/
│       ├── app.js                       # SPA router, shared state, API helpers
│       ├── scanner.js                   # QR camera scanner (html5-qrcode)
│       ├── equipment.js                 # Equipment live data view
│       ├── admin.js                     # Admin: stations + equipment CRUD
│       └── tree-browser.js              # Station tree browser modal
└── README.md
```

**Key design decisions:**
- Single `main` package (no internal packages) — this is a small, focused program
- `go:embed` bakes web files into the binary — single file distribution, no separate web dir needed
- No auth middleware — every route is open (LAN security model)
- Station credentials stored in SQLite alongside station config (server proxies all Niagara requests)

---

## Task 1: Go Project Scaffold

**Files:**
- Create: `server/go.mod`
- Create: `server/main.go`

- [ ] **Step 1: Initialize Go module**

```bash
mkdir -p server && cd server
go mod init github.com/user/qr-sidekick-server
```

- [ ] **Step 2: Create server/main.go**

```go
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
```

- [ ] **Step 3: Verify it builds and runs**

Run: `cd server && go build -o qr-sidekick-server && ./qr-sidekick-server --help`
Expected: Prints usage with --port and --data-dir flags.

- [ ] **Step 4: Commit**

```bash
git add server/go.mod server/main.go
git commit -m "feat: scaffold Go server project"
```

---

## Task 2: SQLite Database Layer

**Files:**
- Create: `server/database.go`
- Create: `server/database_test.go`

- [ ] **Step 1: Add sqlite dependency**

Run: `cd server && go get modernc.org/sqlite && go get github.com/google/uuid`

- [ ] **Step 2: Write database_test.go**

```go
package main

import (
	"os"
	"path/filepath"
	"testing"
)

func testDB(t *testing.T) *Database {
	t.Helper()
	dir := t.TempDir()
	db, err := NewDatabase(filepath.Join(dir, "test.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	return db
}

func TestSettings(t *testing.T) {
	db := testDB(t)

	// Missing key returns empty
	val, _ := db.GetSetting("missing")
	if val != "" {
		t.Fatalf("expected empty, got %q", val)
	}

	// Set and get
	db.SetSetting("key1", "value1")
	val, _ = db.GetSetting("key1")
	if val != "value1" {
		t.Fatalf("expected value1, got %q", val)
	}

	// Overwrite
	db.SetSetting("key1", "value2")
	val, _ = db.GetSetting("key1")
	if val != "value2" {
		t.Fatalf("expected value2, got %q", val)
	}
}

func TestStationsCRUD(t *testing.T) {
	db := testDB(t)

	// Create
	id, err := db.CreateStation(Station{
		Name: "Test JACE", Host: "192.168.1.100", Port: 443,
		Protocol: "https", ConnectorType: "niagara",
		Username: "admin", Password: "pass",
	})
	if err != nil {
		t.Fatal(err)
	}

	// Get
	s, err := db.GetStation(id)
	if err != nil {
		t.Fatal(err)
	}
	if s.Name != "Test JACE" || s.Host != "192.168.1.100" {
		t.Fatalf("unexpected station: %+v", s)
	}

	// List
	stations, _ := db.ListStations()
	if len(stations) != 1 {
		t.Fatalf("expected 1 station, got %d", len(stations))
	}
	// Verify credentials NOT in list response
	if stations[0].Username != "" || stations[0].Password != "" {
		t.Fatal("ListStations should not return credentials")
	}

	// Delete cascades to equipment
	db.CreateEquipment(Equipment{
		StationID:     id,
		EquipmentName: "AHU-01",
		EquipmentPath: "/Drivers/AHU01",
		BQLQuery:      "bql:...",
		PointPaths:    []string{"/points/Temp"},
	})
	db.DeleteStation(id)
	equips, _ := db.ListEquipmentByStation(id)
	if len(equips) != 0 {
		t.Fatal("expected cascade delete")
	}
}

func TestEquipmentCRUD(t *testing.T) {
	db := testDB(t)

	stationID, _ := db.CreateStation(Station{
		Name: "S1", Host: "10.0.0.1", Port: 443,
		Protocol: "https", ConnectorType: "niagara",
		Username: "u", Password: "p",
	})

	// Create generates qrId
	qrID, err := db.CreateEquipment(Equipment{
		StationID:     stationID,
		EquipmentName: "AHU-01",
		EquipmentPath: "/Drivers/AHU01",
		BQLQuery:      "bql:...",
		PointPaths:    []string{"/points/Temp", "/points/Humidity"},
	})
	if err != nil {
		t.Fatal(err)
	}
	if qrID == "" {
		t.Fatal("expected generated qrId")
	}

	// Get by QR ID
	equip, err := db.GetEquipmentByQRID(qrID)
	if err != nil {
		t.Fatal(err)
	}
	if equip.EquipmentName != "AHU-01" {
		t.Fatalf("unexpected: %+v", equip)
	}
	if len(equip.PointPaths) != 2 {
		t.Fatalf("expected 2 point paths, got %d", len(equip.PointPaths))
	}
}

func TestNotesCRUD(t *testing.T) {
	db := testDB(t)

	stationID, _ := db.CreateStation(Station{
		Name: "S1", Host: "10.0.0.1", Port: 443,
		Protocol: "https", ConnectorType: "niagara",
		Username: "u", Password: "p",
	})
	qrID, _ := db.CreateEquipment(Equipment{
		StationID: stationID, EquipmentName: "AHU-01",
		EquipmentPath: "/Drivers/AHU01", BQLQuery: "bql:...",
		PointPaths: []string{"/points/Temp"},
	})

	// Add notes
	id1, _ := db.AddNote(qrID, "First note")
	db.AddNote(qrID, "Second note")

	// Get (newest first)
	notes, _ := db.GetNotes(qrID)
	if len(notes) != 2 {
		t.Fatalf("expected 2 notes, got %d", len(notes))
	}
	if notes[0].Content != "Second note" {
		t.Fatalf("expected newest first, got %q", notes[0].Content)
	}

	// Delete
	db.DeleteNote(id1)
	notes, _ = db.GetNotes(qrID)
	if len(notes) != 1 {
		t.Fatalf("expected 1 note after delete, got %d", len(notes))
	}
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd server && go test -v -run TestSettings`
Expected: Fails — `Database` type doesn't exist.

- [ ] **Step 4: Create database.go**

```go
package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	_ "modernc.org/sqlite"
)

type Station struct {
	ID            int64  `json:"id"`
	Name          string `json:"name"`
	Host          string `json:"host"`
	Port          int    `json:"port"`
	Protocol      string `json:"protocol"`
	ConnectorType string `json:"connectorType"`
	Username      string `json:"username,omitempty"`
	Password      string `json:"password,omitempty"`
	CreatedAt     string `json:"createdAt"`
}

type Equipment struct {
	QRID          string   `json:"qrId"`
	StationID     int64    `json:"stationId"`
	EquipmentName string   `json:"equipmentName"`
	EquipmentPath string   `json:"equipmentPath"`
	BQLQuery      string   `json:"bqlQuery"`
	PointPaths    []string `json:"pointPaths"`
	Location      string   `json:"location,omitempty"`
	CreatedAt     string   `json:"createdAt"`
}

type Note struct {
	ID        int64  `json:"id"`
	QRID      string `json:"qrId"`
	Content   string `json:"content"`
	CreatedAt string `json:"createdAt"`
}

type Database struct {
	db *sql.DB
}

func NewDatabase(path string) (*Database, error) {
	db, err := sql.Open("sqlite", path+"?_pragma=foreign_keys(1)&_pragma=journal_mode(wal)")
	if err != nil {
		return nil, err
	}

	d := &Database{db: db}
	if err := d.migrate(); err != nil {
		db.Close()
		return nil, err
	}
	return d, nil
}

func (d *Database) Close() error {
	return d.db.Close()
}

func (d *Database) migrate() error {
	_, err := d.db.Exec(`
		CREATE TABLE IF NOT EXISTS settings (
			key   TEXT PRIMARY KEY,
			value TEXT NOT NULL
		);
		CREATE TABLE IF NOT EXISTS stations (
			id             INTEGER PRIMARY KEY AUTOINCREMENT,
			name           TEXT NOT NULL,
			host           TEXT NOT NULL,
			port           INTEGER NOT NULL DEFAULT 443,
			protocol       TEXT NOT NULL DEFAULT 'https',
			connector_type TEXT NOT NULL DEFAULT 'niagara',
			username       TEXT NOT NULL,
			password       TEXT NOT NULL,
			created_at     TEXT NOT NULL DEFAULT (datetime('now'))
		);
		CREATE TABLE IF NOT EXISTS equipment (
			qr_id          TEXT PRIMARY KEY,
			station_id     INTEGER NOT NULL REFERENCES stations(id) ON DELETE CASCADE,
			equipment_name TEXT NOT NULL,
			equipment_path TEXT NOT NULL,
			bql_query      TEXT NOT NULL,
			point_paths    TEXT NOT NULL DEFAULT '[]',
			location       TEXT NOT NULL DEFAULT '',
			created_at     TEXT NOT NULL DEFAULT (datetime('now'))
		);
		CREATE TABLE IF NOT EXISTS notes (
			id         INTEGER PRIMARY KEY AUTOINCREMENT,
			qr_id      TEXT NOT NULL REFERENCES equipment(qr_id) ON DELETE CASCADE,
			content    TEXT NOT NULL,
			created_at TEXT NOT NULL DEFAULT (datetime('now'))
		);
	`)
	return err
}

// -- Settings --

func (d *Database) GetSetting(key string) (string, error) {
	var val string
	err := d.db.QueryRow("SELECT value FROM settings WHERE key = ?", key).Scan(&val)
	if err == sql.ErrNoRows {
		return "", nil
	}
	return val, err
}

func (d *Database) SetSetting(key, value string) error {
	_, err := d.db.Exec(
		"INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = ?",
		key, value, value,
	)
	return err
}

// -- Stations --

func (d *Database) CreateStation(s Station) (int64, error) {
	if s.Port == 0 {
		s.Port = 443
	}
	if s.Protocol == "" {
		s.Protocol = "https"
	}
	if s.ConnectorType == "" {
		s.ConnectorType = "niagara"
	}
	res, err := d.db.Exec(
		"INSERT INTO stations (name, host, port, protocol, connector_type, username, password) VALUES (?,?,?,?,?,?,?)",
		s.Name, s.Host, s.Port, s.Protocol, s.ConnectorType, s.Username, s.Password,
	)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

func (d *Database) GetStation(id int64) (Station, error) {
	var s Station
	err := d.db.QueryRow(
		"SELECT id, name, host, port, protocol, connector_type, username, password, created_at FROM stations WHERE id = ?", id,
	).Scan(&s.ID, &s.Name, &s.Host, &s.Port, &s.Protocol, &s.ConnectorType, &s.Username, &s.Password, &s.CreatedAt)
	return s, err
}

func (d *Database) ListStations() ([]Station, error) {
	rows, err := d.db.Query("SELECT id, name, host, port, protocol, connector_type, created_at FROM stations ORDER BY id")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var stations []Station
	for rows.Next() {
		var s Station
		if err := rows.Scan(&s.ID, &s.Name, &s.Host, &s.Port, &s.Protocol, &s.ConnectorType, &s.CreatedAt); err != nil {
			return nil, err
		}
		stations = append(stations, s)
	}
	return stations, nil
}

func (d *Database) UpdateStation(id int64, s Station) error {
	_, err := d.db.Exec(
		"UPDATE stations SET name=?, host=?, port=?, protocol=?, connector_type=?, username=?, password=? WHERE id=?",
		s.Name, s.Host, s.Port, s.Protocol, s.ConnectorType, s.Username, s.Password, id,
	)
	return err
}

func (d *Database) DeleteStation(id int64) error {
	_, err := d.db.Exec("DELETE FROM stations WHERE id = ?", id)
	return err
}

// -- Equipment --

func (d *Database) CreateEquipment(e Equipment) (string, error) {
	qrID := uuid.New().String()
	pathsJSON, _ := json.Marshal(e.PointPaths)
	_, err := d.db.Exec(
		"INSERT INTO equipment (qr_id, station_id, equipment_name, equipment_path, bql_query, point_paths, location) VALUES (?,?,?,?,?,?,?)",
		qrID, e.StationID, e.EquipmentName, e.EquipmentPath, e.BQLQuery, string(pathsJSON), e.Location,
	)
	return qrID, err
}

func (d *Database) GetEquipmentByQRID(qrID string) (Equipment, error) {
	var e Equipment
	var pathsJSON string
	err := d.db.QueryRow(
		"SELECT qr_id, station_id, equipment_name, equipment_path, bql_query, point_paths, location, created_at FROM equipment WHERE qr_id = ?", qrID,
	).Scan(&e.QRID, &e.StationID, &e.EquipmentName, &e.EquipmentPath, &e.BQLQuery, &pathsJSON, &e.Location, &e.CreatedAt)
	if err != nil {
		return e, err
	}
	json.Unmarshal([]byte(pathsJSON), &e.PointPaths)
	return e, nil
}

func (d *Database) ListEquipmentByStation(stationID int64) ([]Equipment, error) {
	return d.queryEquipment("SELECT qr_id, station_id, equipment_name, equipment_path, bql_query, point_paths, location, created_at FROM equipment WHERE station_id = ? ORDER BY equipment_name", stationID)
}

func (d *Database) ListAllEquipment() ([]Equipment, error) {
	return d.queryEquipment("SELECT qr_id, station_id, equipment_name, equipment_path, bql_query, point_paths, location, created_at FROM equipment ORDER BY equipment_name")
}

func (d *Database) queryEquipment(query string, args ...any) ([]Equipment, error) {
	rows, err := d.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var equips []Equipment
	for rows.Next() {
		var e Equipment
		var pathsJSON string
		if err := rows.Scan(&e.QRID, &e.StationID, &e.EquipmentName, &e.EquipmentPath, &e.BQLQuery, &pathsJSON, &e.Location, &e.CreatedAt); err != nil {
			return nil, err
		}
		json.Unmarshal([]byte(pathsJSON), &e.PointPaths)
		equips = append(equips, e)
	}
	return equips, nil
}

func (d *Database) UpdateEquipment(qrID string, e Equipment) error {
	pathsJSON, _ := json.Marshal(e.PointPaths)
	_, err := d.db.Exec(
		"UPDATE equipment SET equipment_name=?, equipment_path=?, bql_query=?, point_paths=?, location=? WHERE qr_id=?",
		e.EquipmentName, e.EquipmentPath, e.BQLQuery, string(pathsJSON), e.Location, qrID,
	)
	return err
}

func (d *Database) DeleteEquipment(qrID string) error {
	_, err := d.db.Exec("DELETE FROM equipment WHERE qr_id = ?", qrID)
	return err
}

// -- Notes --

func (d *Database) AddNote(qrID, content string) (int64, error) {
	res, err := d.db.Exec("INSERT INTO notes (qr_id, content) VALUES (?, ?)", qrID, content)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

func (d *Database) GetNotes(qrID string) ([]Note, error) {
	rows, err := d.db.Query("SELECT id, qr_id, content, created_at FROM notes WHERE qr_id = ? ORDER BY id DESC", qrID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var notes []Note
	for rows.Next() {
		var n Note
		if err := rows.Scan(&n.ID, &n.QRID, &n.Content, &n.CreatedAt); err != nil {
			return nil, err
		}
		notes = append(notes, n)
	}
	return notes, nil
}

func (d *Database) DeleteNote(id int64) error {
	_, err := d.db.Exec("DELETE FROM notes WHERE id = ?", id)
	return err
}
```

- [ ] **Step 5: Run tests**

Run: `cd server && go test -v -run "Test(Settings|Stations|Equipment|Notes)"`
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add server/database.go server/database_test.go server/go.mod server/go.sum
git commit -m "feat: add SQLite database with stations, equipment, notes CRUD"
```

---

## Task 3: Connector Interface + Niagara Implementation

**Files:**
- Create: `server/connector.go`
- Create: `server/niagara.go`
- Create: `server/niagara_test.go`

- [ ] **Step 1: Create connector.go (interface + types)**

```go
package main

// Connector abstracts communication with a BAS station.
// Implement this interface to add support for new protocols.
type Connector interface {
	// Human-readable name (e.g., "Niagara 4")
	DisplayName() string
	// Machine ID matching station.ConnectorType (e.g., "niagara")
	TypeID() string
	// Test connectivity and auth
	TestConnection(host string, port int, protocol, username, password string) ConnResult
	// Fetch equipment tree for admin browsing
	FetchTree(host string, port int, protocol, username, password string) TreeResult
	// Fetch live point values for an equipment path
	FetchSnapshot(host string, port int, protocol, username, password, equipmentPath string) SnapResult
}

// -- Result types --

type ConnResult struct {
	OK    bool   `json:"ok"`
	Error string `json:"error,omitempty"`
}

type TreeResult struct {
	OK    bool      `json:"ok"`
	Root  *TreeNode `json:"root,omitempty"`
	Error string    `json:"error,omitempty"`
}

type SnapResult struct {
	OK     bool         `json:"ok"`
	Points []PointValue `json:"points,omitempty"`
	Error  string       `json:"error,omitempty"`
}

// -- Data types --

type PointValue struct {
	Path   string `json:"path"`
	Name   string `json:"name"`
	Value  string `json:"value"`
	Status string `json:"status,omitempty"`
}

type TreeNode struct {
	Name         string      `json:"name"`
	Path         string      `json:"path"`
	IsEquipment  bool        `json:"isEquipment"`
	HasEquipment bool        `json:"hasEquipment"`
	PointCount   int         `json:"pointCount"`
	Children     []*TreeNode `json:"children"`
}

type DiscoveredEquipment struct {
	Name   string
	Path   string
	Points []DiscoveredPoint
}

type DiscoveredPoint struct {
	Name string
	Path string
	Type string
}

// -- Registry --

type ConnectorRegistry struct {
	connectors map[string]Connector
}

func NewConnectorRegistry() *ConnectorRegistry {
	return &ConnectorRegistry{connectors: make(map[string]Connector)}
}

func (r *ConnectorRegistry) Register(c Connector) {
	r.connectors[c.TypeID()] = c
}

func (r *ConnectorRegistry) Get(typeID string) Connector {
	return r.connectors[typeID]
}

func (r *ConnectorRegistry) All() []Connector {
	out := make([]Connector, 0, len(r.connectors))
	for _, c := range r.connectors {
		out = append(out, c)
	}
	return out
}
```

- [ ] **Step 2: Create niagara.go (ported from niagara_client.dart)**

```go
package main

import (
	"crypto/tls"
	"encoding/base64"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"
)

type NiagaraConnector struct{}

func (n *NiagaraConnector) DisplayName() string { return "Niagara 4" }
func (n *NiagaraConnector) TypeID() string      { return "niagara" }

func (n *NiagaraConnector) client() *http.Client {
	return &http.Client{
		Timeout: 30 * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
		},
	}
}

func (n *NiagaraConnector) basicAuth(username, password string) string {
	return base64.StdEncoding.EncodeToString([]byte(username + ":" + password))
}

func (n *NiagaraConnector) baseURL(host string, port int, protocol string) string {
	return fmt.Sprintf("%s://%s:%d", protocol, host, port)
}

func (n *NiagaraConnector) TestConnection(host string, port int, protocol, username, password string) ConnResult {
	client := n.client()
	client.Timeout = 10 * time.Second

	req, _ := http.NewRequest("GET", n.baseURL(host, port, protocol)+"/ord", nil)
	req.Header.Set("Authorization", "Basic "+n.basicAuth(username, password))
	req.Header.Set("Accept", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return ConnResult{Error: fmt.Sprintf("Cannot connect to %s: %v", host, err)}
	}
	defer resp.Body.Close()

	switch {
	case resp.StatusCode == 200 || resp.StatusCode == 404:
		return ConnResult{OK: true}
	case resp.StatusCode == 401:
		return ConnResult{Error: "Invalid username or password"}
	case resp.StatusCode == 403:
		return ConnResult{Error: "Access forbidden - check user permissions"}
	default:
		return ConnResult{Error: fmt.Sprintf("Unexpected response: %d", resp.StatusCode)}
	}
}

var formatOptions = []string{
	"&format=csv",
	"&export=csv",
	"&view=csv",
	"|view:web:CsvView",
	"|view:web:TextView",
	"|view:web:TableToCsv",
	"", // fallback: parse HTML
}

const baseBQL = "station:|slot:/Drivers|bql:select%20slotPath,%20type%20as%20'Point%20Type',%20facets%20from%20control:ControlPoint"

func (n *NiagaraConnector) FetchTree(host string, port int, protocol, username, password string) TreeResult {
	client := n.client()
	base := n.baseURL(host, port, protocol)
	auth := n.basicAuth(username, password)

	var csvContent string
	var lastResp *http.Response

	for _, fmt := range formatOptions {
		testURL := base + "/ord?" + baseBQL + fmt
		req, _ := http.NewRequest("GET", testURL, nil)
		req.Header.Set("Authorization", "Basic "+auth)
		req.Header.Set("Accept", "text/csv, text/plain, application/xml, */*")

		resp, err := client.Do(req)
		if err != nil {
			continue
		}

		lastResp = resp
		if resp.StatusCode != 200 {
			resp.Body.Close()
			continue
		}

		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()
		data := string(body)

		if !strings.Contains(data, "<!DOCTYPE") && !strings.Contains(data, "<html") {
			csvContent = data
			break
		}

		if fmt == "" {
			if csv := n.fetchIframeContent(data, base, auth, client); csv != "" {
				csvContent = csv
				break
			}
		}
	}

	if csvContent != "" {
		tree := n.parseStationTree(csvContent)
		return TreeResult{OK: true, Root: tree.Root}
	}

	if lastResp == nil {
		return TreeResult{Error: "No response from station"}
	}

	if lastResp.StatusCode == 401 {
		return TreeResult{Error: "Authentication failed"}
	}

	return TreeResult{Error: "Could not parse station response"}
}

func (n *NiagaraConnector) FetchSnapshot(host string, port int, protocol, username, password, equipmentPath string) SnapResult {
	client := n.client()
	client.Timeout = 15 * time.Second
	base := n.baseURL(host, port, protocol)
	auth := n.basicAuth(username, password)

	bql := fmt.Sprintf("station:|slot:%s|bql:select%%20slotPath,%%20out.value%%20as%%20'Value',%%20status%%20as%%20'Status'%%20from%%20control:ControlPoint", equipmentPath)

	req, _ := http.NewRequest("GET", base+"/ord?"+bql, nil)
	req.Header.Set("Authorization", "Basic "+auth)
	req.Header.Set("Accept", "text/csv, text/plain, */*")

	resp, err := client.Do(req)
	if err != nil {
		return SnapResult{Error: fmt.Sprintf("Cannot connect: %v", err)}
	}
	defer resp.Body.Close()

	if resp.StatusCode == 401 {
		return SnapResult{Error: "Authentication failed"}
	}
	if resp.StatusCode != 200 {
		return SnapResult{Error: fmt.Sprintf("Failed: %d", resp.StatusCode)}
	}

	body, _ := io.ReadAll(resp.Body)
	data := string(body)

	var csv string
	if strings.Contains(data, "<!DOCTYPE") || strings.Contains(data, "<html") {
		csv = n.fetchIframeContent(data, base, auth, client)
	} else {
		csv = data
	}

	if csv == "" {
		return SnapResult{Error: "Could not parse snapshot response"}
	}

	points := n.parseSnapshot(csv)
	return SnapResult{OK: true, Points: points}
}

// -- Private helpers (ported from niagara_client.dart) --

func (n *NiagaraConnector) fetchIframeContent(html, baseURL, auth string, client *http.Client) string {
	re := regexp.MustCompile(`(?i)<iframe[^>]+id=['"]servletViewWidget['"][^>]+src=['"]([^'"]+)['"]`)
	m := re.FindStringSubmatch(html)

	if len(m) > 1 {
		iframeURL := m[1]
		iframeURL = strings.NewReplacer(
			"&#x27;", "'", "&#39;", "'", "&quot;", `"`,
			"&amp;", "&", "&lt;", "<", "&gt;", ">",
		).Replace(iframeURL)

		if strings.HasPrefix(iframeURL, "/") {
			iframeURL = baseURL + iframeURL
		}
		decoded, err := url.QueryUnescape(iframeURL)
		if err == nil {
			iframeURL = decoded
		}

		req, _ := http.NewRequest("GET", iframeURL, nil)
		req.Header.Set("Authorization", "Basic "+auth)
		req.Header.Set("Accept", "text/html, */*")

		resp, err := client.Do(req)
		if err == nil && resp.StatusCode == 200 {
			body, _ := io.ReadAll(resp.Body)
			resp.Body.Close()
			if csv := parseHTMLTableToCSV(string(body)); csv != "" {
				return csv
			}
		}
		if resp != nil {
			resp.Body.Close()
		}
	}

	return parseHTMLTableToCSV(html)
}

func parseHTMLTableToCSV(html string) string {
	tableRe := regexp.MustCompile(`(?is)<table[^>]*>(.*?)</table>`)
	tableMatch := tableRe.FindStringSubmatch(html)

	if tableMatch == nil {
		preRe := regexp.MustCompile(`(?s)<pre[^>]*>(.*?)</pre>`)
		if preMatch := preRe.FindStringSubmatch(html); len(preMatch) > 1 {
			return strings.TrimSpace(preMatch[1])
		}
		return ""
	}

	rowRe := regexp.MustCompile(`(?is)<tr[^>]*>(.*?)</tr>`)
	cellRe := regexp.MustCompile(`(?is)<t[hd][^>]*>(.*?)</t[hd]>`)
	tagRe := regexp.MustCompile(`<[^>]+>`)

	rows := rowRe.FindAllStringSubmatch(tableMatch[1], -1)
	var csvLines []string

	for _, row := range rows {
		cells := cellRe.FindAllStringSubmatch(row[1], -1)
		var values []string
		for _, cell := range cells {
			text := tagRe.ReplaceAllString(cell[1], "")
			text = strings.NewReplacer(
				"&nbsp;", " ", "&amp;", "&", "&lt;", "<",
				"&gt;", ">", "&#39;", "'", "&quot;", `"`,
			).Replace(text)
			text = strings.TrimSpace(text)

			if strings.ContainsAny(text, ",\"\n") {
				text = `"` + strings.ReplaceAll(text, `"`, `""`) + `"`
			}
			values = append(values, text)
		}
		if len(values) > 0 {
			csvLines = append(csvLines, strings.Join(values, ","))
		}
	}

	if len(csvLines) == 0 {
		return ""
	}
	return strings.Join(csvLines, "\n")
}

func parseCsvLine(line string) []string {
	var result []string
	var current strings.Builder
	inQuotes := false

	for i := 0; i < len(line); i++ {
		ch := line[i]
		if ch == '"' {
			if inQuotes && i+1 < len(line) && line[i+1] == '"' {
				current.WriteByte('"')
				i++
			} else {
				inQuotes = !inQuotes
			}
		} else if ch == ',' && !inQuotes {
			result = append(result, current.String())
			current.Reset()
		} else {
			current.WriteByte(ch)
		}
	}
	result = append(result, current.String())
	return result
}

type stationTree struct {
	Equipment []DiscoveredEquipment
	Root      *TreeNode
}

func (n *NiagaraConnector) parseStationTree(csvContent string) stationTree {
	lines := splitNonEmpty(csvContent)
	if len(lines) == 0 {
		return stationTree{Root: &TreeNode{Name: "Station", Path: "/", Children: []*TreeNode{}}}
	}

	header := parseCsvLine(lines[0])
	slotIdx := findColumnIndex(header, "object", "slot path", "slotpath")
	if slotIdx == -1 {
		return stationTree{Root: &TreeNode{Name: "Station", Path: "/", Children: []*TreeNode{}}}
	}

	typeIdx := findColumnIndex(header, "point type", "type")

	var pointPaths []string
	pointTypes := map[string]string{}

	for _, line := range lines[1:] {
		cols := parseCsvLine(line)
		if len(cols) <= slotIdx {
			continue
		}
		path := strings.TrimSpace(cols[slotIdx])
		if !strings.HasPrefix(path, "slot:/Drivers/") {
			continue
		}
		path = strings.TrimPrefix(path, "slot:")
		pointPaths = append(pointPaths, path)

		if typeIdx != -1 && len(cols) > typeIdx {
			pointTypes[path] = strings.TrimSpace(cols[typeIdx])
		}
	}

	equipMap := map[string]*DiscoveredEquipment{}
	for _, pp := range pointPaths {
		segs := splitPath(pp)
		if len(segs) == 0 {
			continue
		}
		pointName := segs[len(segs)-1]
		segs = segs[:len(segs)-1]
		_ = pointName

		if len(segs) > 0 && segs[len(segs)-1] == "points" {
			segs = segs[:len(segs)-1]
		}
		if len(segs) == 0 {
			continue
		}

		equipName := segs[len(segs)-1]
		equipPath := "/" + strings.Join(segs, "/")

		if _, ok := equipMap[equipPath]; !ok {
			equipMap[equipPath] = &DiscoveredEquipment{Name: equipName, Path: equipPath}
		}

		pt := extractSimpleType(pointTypes[pp])
		equipMap[equipPath].Points = append(equipMap[equipPath].Points, DiscoveredPoint{
			Name: pp[strings.LastIndex(pp, "/")+1:],
			Path: pp,
			Type: pt,
		})
	}

	equipment := make([]DiscoveredEquipment, 0, len(equipMap))
	for _, eq := range equipMap {
		equipment = append(equipment, *eq)
	}

	root := buildTree(equipment)
	return stationTree{Equipment: equipment, Root: root}
}

func (n *NiagaraConnector) parseSnapshot(csv string) []PointValue {
	lines := splitNonEmpty(csv)
	if len(lines) == 0 {
		return nil
	}

	header := parseCsvLine(lines[0])
	pathIdx := findColumnIndex(header, "slot", "path", "object")
	valueIdx := findColumnIndex(header, "value")
	statusIdx := findColumnIndex(header, "status")

	if pathIdx == -1 {
		return nil
	}

	var points []PointValue
	for _, line := range lines[1:] {
		cols := parseCsvLine(line)
		if len(cols) <= pathIdx {
			continue
		}
		path := strings.TrimSpace(strings.TrimPrefix(cols[pathIdx], "slot:"))
		name := path
		if i := strings.LastIndex(path, "/"); i >= 0 {
			name = path[i+1:]
		}
		val := "--"
		if valueIdx >= 0 && len(cols) > valueIdx {
			val = strings.TrimSpace(cols[valueIdx])
		}
		status := ""
		if statusIdx >= 0 && len(cols) > statusIdx {
			status = strings.TrimSpace(cols[statusIdx])
		}
		points = append(points, PointValue{Path: path, Name: name, Value: val, Status: status})
	}
	return points
}

// -- Utility helpers --

func splitNonEmpty(s string) []string {
	var out []string
	for _, line := range strings.Split(s, "\n") {
		if strings.TrimSpace(line) != "" {
			out = append(out, line)
		}
	}
	return out
}

func splitPath(p string) []string {
	var out []string
	for _, s := range strings.Split(p, "/") {
		if s != "" {
			out = append(out, s)
		}
	}
	return out
}

func findColumnIndex(header []string, keywords ...string) int {
	for i, col := range header {
		lower := strings.ToLower(col)
		for _, kw := range keywords {
			if strings.Contains(lower, kw) {
				return i
			}
		}
	}
	return -1
}

func extractSimpleType(fullType string) string {
	re := regexp.MustCompile(`:(\w+)`)
	m := re.FindStringSubmatch(fullType)
	if m == nil {
		return "Unknown"
	}
	t := m[1]
	switch {
	case strings.Contains(t, "Boolean"):
		return "Boolean"
	case strings.Contains(t, "Numeric"):
		return "Numeric"
	case strings.Contains(t, "Enum"):
		return "Enum"
	case strings.Contains(t, "String"):
		return "String"
	default:
		return "Unknown"
	}
}

func buildTree(equipment []DiscoveredEquipment) *TreeNode {
	root := &TreeNode{Name: "Station", Path: "/", Children: []*TreeNode{}}

	allPaths := map[string]bool{}
	for _, eq := range equipment {
		allPaths[eq.Path] = true
		segs := splitPath(eq.Path)
		var build string
		for _, seg := range segs {
			build += "/" + seg
			allPaths[build] = true
		}
	}

	for path := range allPaths {
		parts := splitPath(path)
		filtered := make([]string, 0, len(parts))
		for _, p := range parts {
			if p != "points" {
				filtered = append(filtered, p)
			}
		}

		cur := root
		for _, part := range filtered {
			var child *TreeNode
			for _, c := range cur.Children {
				if c.Name == part {
					child = c
					break
				}
			}
			if child == nil {
				child = &TreeNode{Name: part, Path: "", Children: []*TreeNode{}}
				cur.Children = append(cur.Children, child)
			}
			cur = child
		}
	}

	markEquipmentNodes(root, "", equipment)
	return root
}

func markEquipmentNodes(node *TreeNode, parentPath string, equipment []DiscoveredEquipment) {
	currentPath := parentPath + "/" + node.Name
	if node.Name == "Station" {
		node.Path = "/"
		for _, child := range node.Children {
			markEquipmentNodes(child, "", equipment)
		}
		return
	}

	node.Path = currentPath

	for _, eq := range equipment {
		if eq.Path == currentPath || strings.ReplaceAll(eq.Path, "/points", "") == currentPath {
			node.IsEquipment = true
			node.PointCount = len(eq.Points)
			break
		}
	}

	for _, child := range node.Children {
		markEquipmentNodes(child, currentPath, equipment)
	}

	if node.IsEquipment {
		node.HasEquipment = true
	} else {
		for _, c := range node.Children {
			if c.HasEquipment {
				node.HasEquipment = true
				break
			}
		}
	}
}
```

- [ ] **Step 3: Write niagara_test.go (CSV parsing tests)**

```go
package main

import (
	"testing"
)

func TestNiagaraConnectorInterface(t *testing.T) {
	var c Connector = &NiagaraConnector{}
	if c.TypeID() != "niagara" {
		t.Fatal("expected niagara")
	}
	if c.DisplayName() != "Niagara 4" {
		t.Fatal("expected Niagara 4")
	}
}

func TestParseCsvLine(t *testing.T) {
	tests := []struct {
		input string
		want  int
	}{
		{"a,b,c", 3},
		{`"a,b",c,d`, 3},
		{`a,"b""c",d`, 3},
	}
	for _, tt := range tests {
		got := parseCsvLine(tt.input)
		if len(got) != tt.want {
			t.Errorf("parseCsvLine(%q) = %d fields, want %d", tt.input, len(got), tt.want)
		}
	}
}

func TestParseHTMLTableToCSV(t *testing.T) {
	html := `<table><tr><th>Name</th><th>Value</th></tr><tr><td>Temp</td><td>72.5</td></tr></table>`
	csv := parseHTMLTableToCSV(html)
	if csv == "" {
		t.Fatal("expected CSV output")
	}
	lines := splitNonEmpty(csv)
	if len(lines) != 2 {
		t.Fatalf("expected 2 lines, got %d", len(lines))
	}
}

func TestParseStationTree(t *testing.T) {
	csv := "slotPath,Point Type,facets\n" +
		"slot:/Drivers/Network/Building/AHU01/points/SpaceTemp,control:NumericWritable,\n" +
		"slot:/Drivers/Network/Building/AHU01/points/DamperCmd,control:NumericWritable,\n" +
		"slot:/Drivers/Network/Building/VAV01/points/ZoneTemp,control:NumericWritable,\n"

	n := &NiagaraConnector{}
	tree := n.parseStationTree(csv)

	if len(tree.Equipment) != 2 {
		t.Fatalf("expected 2 equipment, got %d", len(tree.Equipment))
	}

	if tree.Root == nil || len(tree.Root.Children) == 0 {
		t.Fatal("expected non-empty tree")
	}
}

func TestParseSnapshot(t *testing.T) {
	csv := "slotPath,Value,Status\n" +
		"slot:/Drivers/AHU01/points/SpaceTemp,72.5,{ok}\n" +
		"slot:/Drivers/AHU01/points/DamperCmd,45.0,{ok}\n"

	n := &NiagaraConnector{}
	points := n.parseSnapshot(csv)

	if len(points) != 2 {
		t.Fatalf("expected 2 points, got %d", len(points))
	}
	if points[0].Value != "72.5" {
		t.Fatalf("expected 72.5, got %s", points[0].Value)
	}
	if points[0].Name != "SpaceTemp" {
		t.Fatalf("expected SpaceTemp, got %s", points[0].Name)
	}
}

func TestConnectorRegistry(t *testing.T) {
	reg := NewConnectorRegistry()
	reg.Register(&NiagaraConnector{})

	if c := reg.Get("niagara"); c == nil {
		t.Fatal("expected niagara connector")
	}
	if c := reg.Get("missing"); c != nil {
		t.Fatal("expected nil for missing")
	}
	if len(reg.All()) != 1 {
		t.Fatal("expected 1 connector")
	}
}
```

- [ ] **Step 4: Run all tests**

Run: `cd server && go test -v`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add server/connector.go server/niagara.go server/niagara_test.go
git commit -m "feat: add Connector interface with Niagara 4 implementation"
```

---

## Task 4: HTTP Handlers + QR Generation

**Files:**
- Create: `server/handlers.go`
- Create: `server/handlers_test.go`
- Create: `server/qr.go`

- [ ] **Step 1: Add QR dependency**

Run: `cd server && go get github.com/skip2/go-qrcode`

- [ ] **Step 2: Create qr.go**

```go
package main

import qrcode "github.com/skip2/go-qrcode"

func generateQRPNG(data string, size int) ([]byte, error) {
	return qrcode.Encode(data, qrcode.Medium, size)
}
```

- [ ] **Step 3: Create handlers.go**

```go
package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
)

type Server struct {
	db         *Database
	connectors *ConnectorRegistry
	mux        *http.ServeMux
}

func NewServer(db *Database, connectors *ConnectorRegistry) *Server {
	s := &Server{db: db, connectors: connectors, mux: http.NewServeMux()}
	s.routes()
	return s
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// CORS
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
	if r.Method == "OPTIONS" {
		w.WriteHeader(200)
		return
	}
	s.mux.ServeHTTP(w, r)
}

func (s *Server) routes() {
	// Public: live equipment data
	s.mux.HandleFunc("GET /api/equipment/{qrId}", s.handleGetLiveData)
	s.mux.HandleFunc("GET /api/equipment/{qrId}/notes", s.handleGetNotes)
	s.mux.HandleFunc("POST /api/equipment/{qrId}/notes", s.handleAddNote)

	// Admin: stations
	s.mux.HandleFunc("GET /api/stations", s.handleListStations)
	s.mux.HandleFunc("GET /api/stations/{id}", s.handleGetStation)
	s.mux.HandleFunc("POST /api/stations", s.handleCreateStation)
	s.mux.HandleFunc("PUT /api/stations/{id}", s.handleUpdateStation)
	s.mux.HandleFunc("DELETE /api/stations/{id}", s.handleDeleteStation)
	s.mux.HandleFunc("POST /api/stations/{id}/test", s.handleTestStation)
	s.mux.HandleFunc("GET /api/stations/{id}/tree", s.handleStationTree)

	// Admin: equipment
	s.mux.HandleFunc("GET /api/admin/equipment", s.handleListEquipment)
	s.mux.HandleFunc("GET /api/admin/equipment/{qrId}", s.handleGetEquipment)
	s.mux.HandleFunc("POST /api/admin/equipment", s.handleCreateEquipment)
	s.mux.HandleFunc("PUT /api/admin/equipment/{qrId}", s.handleUpdateEquipment)
	s.mux.HandleFunc("DELETE /api/admin/equipment/{qrId}", s.handleDeleteEquipment)
	s.mux.HandleFunc("GET /api/admin/equipment/{qrId}/qr.png", s.handleQRCode)

	// Admin: connectors
	s.mux.HandleFunc("GET /api/connectors", s.handleListConnectors)
}

func jsonResp(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func jsonError(w http.ResponseWriter, status int, msg string) {
	jsonResp(w, status, map[string]string{"error": msg})
}

func readJSON(r *http.Request, v any) error {
	return json.NewDecoder(r.Body).Decode(v)
}

// -- Live data (public) --

func (s *Server) handleGetLiveData(w http.ResponseWriter, r *http.Request) {
	qrID := r.PathValue("qrId")
	equip, err := s.db.GetEquipmentByQRID(qrID)
	if err != nil {
		jsonError(w, 404, "Equipment not found")
		return
	}

	station, err := s.db.GetStation(equip.StationID)
	if err != nil {
		jsonError(w, 404, "Station not found")
		return
	}

	conn := s.connectors.Get(station.ConnectorType)
	if conn == nil {
		jsonError(w, 500, "Unknown connector: "+station.ConnectorType)
		return
	}

	result := conn.FetchSnapshot(station.Host, station.Port, station.Protocol,
		station.Username, station.Password, equip.EquipmentPath)

	var points []map[string]string
	if result.OK {
		for _, configPath := range equip.PointPaths {
			found := false
			for _, p := range result.Points {
				if p.Path == configPath || strings.HasSuffix(p.Path, configPath) {
					points = append(points, map[string]string{
						"path": p.Path, "name": p.Name, "value": p.Value, "status": p.Status,
					})
					found = true
					break
				}
			}
			if !found {
				name := configPath
				if i := strings.LastIndex(configPath, "/"); i >= 0 {
					name = configPath[i+1:]
				}
				points = append(points, map[string]string{
					"path": configPath, "name": name, "value": "--",
				})
			}
		}
	} else {
		for _, configPath := range equip.PointPaths {
			name := configPath
			if i := strings.LastIndex(configPath, "/"); i >= 0 {
				name = configPath[i+1:]
			}
			points = append(points, map[string]string{
				"path": configPath, "name": name, "value": "--", "status": "offline",
			})
		}
	}

	resp := map[string]any{
		"equipmentName": equip.EquipmentName,
		"equipmentPath": equip.EquipmentPath,
		"stationName":   station.Name,
		"location":      equip.Location,
		"points":        points,
		"online":        result.OK,
		"queriedAt":     nowISO(),
	}
	if result.Error != "" {
		resp["error"] = result.Error
	}
	jsonResp(w, 200, resp)
}

func (s *Server) handleGetNotes(w http.ResponseWriter, r *http.Request) {
	notes, err := s.db.GetNotes(r.PathValue("qrId"))
	if err != nil {
		jsonError(w, 500, err.Error())
		return
	}
	if notes == nil {
		notes = []Note{}
	}
	jsonResp(w, 200, notes)
}

func (s *Server) handleAddNote(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Content string `json:"content"`
	}
	if err := readJSON(r, &body); err != nil || strings.TrimSpace(body.Content) == "" {
		jsonError(w, 400, "Note content required")
		return
	}
	id, err := s.db.AddNote(r.PathValue("qrId"), strings.TrimSpace(body.Content))
	if err != nil {
		jsonError(w, 500, err.Error())
		return
	}
	jsonResp(w, 200, map[string]int64{"id": id})
}

// -- Stations --

func (s *Server) handleListStations(w http.ResponseWriter, r *http.Request) {
	stations, err := s.db.ListStations()
	if err != nil {
		jsonError(w, 500, err.Error())
		return
	}
	if stations == nil {
		stations = []Station{}
	}
	jsonResp(w, 200, stations)
}

func (s *Server) handleGetStation(w http.ResponseWriter, r *http.Request) {
	id, _ := strconv.ParseInt(r.PathValue("id"), 10, 64)
	station, err := s.db.GetStation(id)
	if err != nil {
		jsonError(w, 404, "Station not found")
		return
	}
	// Strip credentials for safety in GET
	station.Username = ""
	station.Password = ""
	jsonResp(w, 200, station)
}

func (s *Server) handleCreateStation(w http.ResponseWriter, r *http.Request) {
	var station Station
	if err := readJSON(r, &station); err != nil {
		jsonError(w, 400, "Invalid request body")
		return
	}
	id, err := s.db.CreateStation(station)
	if err != nil {
		jsonError(w, 500, err.Error())
		return
	}
	jsonResp(w, 200, map[string]int64{"id": id})
}

func (s *Server) handleUpdateStation(w http.ResponseWriter, r *http.Request) {
	id, _ := strconv.ParseInt(r.PathValue("id"), 10, 64)
	var station Station
	if err := readJSON(r, &station); err != nil {
		jsonError(w, 400, "Invalid request body")
		return
	}
	if err := s.db.UpdateStation(id, station); err != nil {
		jsonError(w, 500, err.Error())
		return
	}
	jsonResp(w, 200, map[string]bool{"ok": true})
}

func (s *Server) handleDeleteStation(w http.ResponseWriter, r *http.Request) {
	id, _ := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err := s.db.DeleteStation(id); err != nil {
		jsonError(w, 500, err.Error())
		return
	}
	jsonResp(w, 200, map[string]bool{"ok": true})
}

func (s *Server) handleTestStation(w http.ResponseWriter, r *http.Request) {
	id, _ := strconv.ParseInt(r.PathValue("id"), 10, 64)
	station, err := s.db.GetStation(id)
	if err != nil {
		jsonError(w, 404, "Station not found")
		return
	}
	conn := s.connectors.Get(station.ConnectorType)
	if conn == nil {
		jsonError(w, 400, "Unknown connector: "+station.ConnectorType)
		return
	}
	result := conn.TestConnection(station.Host, station.Port, station.Protocol, station.Username, station.Password)
	jsonResp(w, 200, result)
}

func (s *Server) handleStationTree(w http.ResponseWriter, r *http.Request) {
	id, _ := strconv.ParseInt(r.PathValue("id"), 10, 64)
	station, err := s.db.GetStation(id)
	if err != nil {
		jsonError(w, 404, "Station not found")
		return
	}
	conn := s.connectors.Get(station.ConnectorType)
	if conn == nil {
		jsonError(w, 400, "Unknown connector: "+station.ConnectorType)
		return
	}
	result := conn.FetchTree(station.Host, station.Port, station.Protocol, station.Username, station.Password)
	if result.OK {
		jsonResp(w, 200, result.Root)
	} else {
		jsonError(w, 502, result.Error)
	}
}

// -- Equipment (admin) --

func (s *Server) handleListEquipment(w http.ResponseWriter, r *http.Request) {
	equips, err := s.db.ListAllEquipment()
	if err != nil {
		jsonError(w, 500, err.Error())
		return
	}
	if equips == nil {
		equips = []Equipment{}
	}
	jsonResp(w, 200, equips)
}

func (s *Server) handleGetEquipment(w http.ResponseWriter, r *http.Request) {
	equip, err := s.db.GetEquipmentByQRID(r.PathValue("qrId"))
	if err != nil {
		jsonError(w, 404, "Equipment not found")
		return
	}
	jsonResp(w, 200, equip)
}

func (s *Server) handleCreateEquipment(w http.ResponseWriter, r *http.Request) {
	var equip Equipment
	if err := readJSON(r, &equip); err != nil {
		jsonError(w, 400, "Invalid request body")
		return
	}
	qrID, err := s.db.CreateEquipment(equip)
	if err != nil {
		jsonError(w, 500, err.Error())
		return
	}
	jsonResp(w, 200, map[string]string{"qrId": qrID})
}

func (s *Server) handleUpdateEquipment(w http.ResponseWriter, r *http.Request) {
	qrID := r.PathValue("qrId")
	var equip Equipment
	if err := readJSON(r, &equip); err != nil {
		jsonError(w, 400, "Invalid request body")
		return
	}
	if err := s.db.UpdateEquipment(qrID, equip); err != nil {
		jsonError(w, 500, err.Error())
		return
	}
	jsonResp(w, 200, map[string]bool{"ok": true})
}

func (s *Server) handleDeleteEquipment(w http.ResponseWriter, r *http.Request) {
	if err := s.db.DeleteEquipment(r.PathValue("qrId")); err != nil {
		jsonError(w, 500, err.Error())
		return
	}
	jsonResp(w, 200, map[string]bool{"ok": true})
}

func (s *Server) handleQRCode(w http.ResponseWriter, r *http.Request) {
	qrID := r.PathValue("qrId")
	if _, err := s.db.GetEquipmentByQRID(qrID); err != nil {
		http.Error(w, "Equipment not found", 404)
		return
	}

	scheme := "http"
	if r.TLS != nil {
		scheme = "https"
	}
	equipURL := fmt.Sprintf("%s://%s/#/equipment/%s", scheme, r.Host, qrID)

	png, err := generateQRPNG(equipURL, 512)
	if err != nil {
		http.Error(w, "QR generation failed", 500)
		return
	}
	w.Header().Set("Content-Type", "image/png")
	w.Header().Set("Cache-Control", "no-cache")
	w.Write(png)
}

// -- Connectors --

func (s *Server) handleListConnectors(w http.ResponseWriter, r *http.Request) {
	var list []map[string]string
	for _, c := range s.connectors.All() {
		list = append(list, map[string]string{
			"typeId":      c.TypeID(),
			"displayName": c.DisplayName(),
		})
	}
	if list == nil {
		list = []map[string]string{}
	}
	jsonResp(w, 200, list)
}

// -- Utility --

func nowISO() string {
	return strings.Replace(strings.Split(fmt.Sprintf("%v", strings.Replace(fmt.Sprint(
		func() string { t := make([]byte, 0, 30); return string(t) }(),
	), " ", "T", 1)), ".")[0], "", "", 0)
}
```

Wait — that `nowISO` is overly complex. Let me simplify:

```go
func nowISO() string {
	return time.Now().UTC().Format(time.RFC3339)
}
```

(Add `"time"` to imports.)

- [ ] **Step 4: Write handlers_test.go**

```go
package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"
)

func testServer(t *testing.T) *Server {
	t.Helper()
	db := testDB(t)
	reg := NewConnectorRegistry()
	reg.Register(&NiagaraConnector{})
	return NewServer(db, reg)
}

func TestCreateAndListStations(t *testing.T) {
	srv := testServer(t)

	// Create station
	body, _ := json.Marshal(map[string]any{
		"name": "Test JACE", "host": "192.168.1.100", "port": 443,
		"protocol": "https", "connectorType": "niagara",
		"username": "admin", "password": "pass",
	})

	req := httptest.NewRequest("POST", "/api/stations", bytes.NewReader(body))
	w := httptest.NewRecorder()
	srv.ServeHTTP(w, req)

	if w.Code != 200 {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var createResp map[string]any
	json.Unmarshal(w.Body.Bytes(), &createResp)
	if createResp["id"] == nil {
		t.Fatal("expected id in response")
	}

	// List stations (should not include credentials)
	req = httptest.NewRequest("GET", "/api/stations", nil)
	w = httptest.NewRecorder()
	srv.ServeHTTP(w, req)

	if w.Code != 200 {
		t.Fatalf("expected 200, got %d", w.Code)
	}

	var stations []map[string]any
	json.Unmarshal(w.Body.Bytes(), &stations)
	if len(stations) != 1 {
		t.Fatalf("expected 1 station, got %d", len(stations))
	}
	if stations[0]["name"] != "Test JACE" {
		t.Fatalf("expected Test JACE, got %v", stations[0]["name"])
	}
	// Credentials should be stripped
	if stations[0]["username"] != nil && stations[0]["username"] != "" {
		t.Fatal("credentials should not be in list response")
	}
}

func TestLiveDataNotFound(t *testing.T) {
	srv := testServer(t)

	req := httptest.NewRequest("GET", "/api/equipment/nonexistent", nil)
	w := httptest.NewRecorder()
	srv.ServeHTTP(w, req)

	if w.Code != 404 {
		t.Fatalf("expected 404, got %d", w.Code)
	}
}

func TestNotesEndpoint(t *testing.T) {
	srv := testServer(t)

	// Create station + equipment
	stationID, _ := srv.db.CreateStation(Station{
		Name: "S1", Host: "10.0.0.1", Port: 443,
		Protocol: "https", ConnectorType: "niagara",
		Username: "u", Password: "p",
	})
	qrID, _ := srv.db.CreateEquipment(Equipment{
		StationID: stationID, EquipmentName: "AHU-01",
		EquipmentPath: "/Drivers/AHU01", BQLQuery: "bql:...",
		PointPaths: []string{"/points/Temp"},
	})

	// Add note
	body, _ := json.Marshal(map[string]string{"content": "Filter replaced"})
	req := httptest.NewRequest("POST", "/api/equipment/"+qrID+"/notes", bytes.NewReader(body))
	w := httptest.NewRecorder()
	srv.ServeHTTP(w, req)

	if w.Code != 200 {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	// Get notes
	req = httptest.NewRequest("GET", "/api/equipment/"+qrID+"/notes", nil)
	w = httptest.NewRecorder()
	srv.ServeHTTP(w, req)

	var notes []map[string]any
	json.Unmarshal(w.Body.Bytes(), &notes)
	if len(notes) != 1 {
		t.Fatalf("expected 1 note, got %d", len(notes))
	}
	if notes[0]["content"] != "Filter replaced" {
		t.Fatalf("unexpected content: %v", notes[0]["content"])
	}
}
```

- [ ] **Step 5: Run all tests**

Run: `cd server && go test -v`
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add server/handlers.go server/handlers_test.go server/qr.go server/go.mod server/go.sum
git commit -m "feat: add HTTP handlers, QR generation, and API routes"
```

---

## Task 5: PWA Frontend — CSS + App Shell

**Files:**
- Create: `server/web/css/style.css`
- Create: `server/web/index.html`
- Create: `server/web/manifest.json`
- Create: `server/web/sw.js`
- Create: `server/web/js/app.js`

This task creates the app shell with hash-based SPA routing and the dark basidekick theme.

- [ ] **Step 1: Create style.css (dark basidekick theme)**

The CSS should define these variables (dark inversion of basidekick.com):
```
--background: #151c14    (deep forest)
--surface: #1f2920       (basidekick primary)
--surface-hover: #283528
--border: #2d3a2b        (muted green)
--text-primary: #f1efe6  (basidekick background)
--text-secondary: #a8a693
--text-tertiary: #6b7266
--accent: #c08621        (gold)
--error: #8b2914         (rust)
--success: #4a8c3f       (forest green)
```

Fonts: Fraunces (heading), Manrope (body), JetBrains Mono (mono). Load via Google Fonts link in HTML.

Include Niagara status colors:
```
--niagara-alarm: #CF1624
--niagara-fault: #FC7734
--niagara-down: #FAC600
--niagara-stale: #D9C09D
--niagara-overridden: #BFADDD
--niagara-disabled: #D6D6D6
```

Style classes matching basidekick patterns:
- `.mono` — JetBrains Mono, 11px, uppercase, tracking 1.2px
- `.heading` — Fraunces, italic
- `.section-header` — mono styling with accent-colored prefix
- `.card` — surface bg, border, rounded
- `.badge` — inline mono label with border
- `.btn` / `.btn-primary` / `.btn-outline`
- `.point-row`, `.note-card`
- Nav bar (bottom tabs for mobile PWA)
- Print-friendly CSS

- [ ] **Step 2: Create index.html (SPA shell)**

Single HTML file with:
- Google Fonts link (Fraunces, Manrope, JetBrains Mono)
- Bottom nav bar with 3 tabs: Scanner, Equipment, Admin
- `<div id="app">` content area
- Script includes for app.js, scanner.js, equipment.js, admin.js, tree-browser.js
- PWA manifest link
- Viewport meta for mobile

- [ ] **Step 3: Create manifest.json**

```json
{
  "name": "QR Sidekick",
  "short_name": "QR Sidekick",
  "description": "Scan equipment QR codes for live BAS data",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#151c14",
  "theme_color": "#151c14",
  "icons": []
}
```

- [ ] **Step 4: Create sw.js (service worker)**

Basic cache-first service worker for PWA installability. Caches the app shell (HTML, CSS, JS). Network-first for API calls.

- [ ] **Step 5: Create app.js (SPA router + API helpers)**

Hash-based routing (#/scanner, #/equipment/:id, #/admin, etc.). Shared API fetch helper. Tab switching. Page rendering delegation to scanner.js, equipment.js, admin.js.

```javascript
const API = {
  async get(path) {
    const res = await fetch(path);
    if (!res.ok) throw new Error(`${res.status}`);
    return res.json();
  },
  async post(path, body) {
    const res = await fetch(path, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    return res.json();
  },
  // put, del similarly
};
```

- [ ] **Step 6: Commit**

```bash
git add server/web/
git commit -m "feat: add PWA shell with dark basidekick theme and SPA routing"
```

---

## Task 6: PWA Frontend — Scanner + Equipment View

**Files:**
- Create: `server/web/js/scanner.js`
- Create: `server/web/js/equipment.js`

- [ ] **Step 1: Add html5-qrcode library**

Include via CDN in index.html: `https://unpkg.com/html5-qrcode@2.3.8/html5-qrcode.min.js`

- [ ] **Step 2: Create scanner.js**

Camera-based QR scanner:
- Request camera permission
- Use `Html5QrcodeScanner` with rear camera preference
- On scan: validate UUID format, navigate to `#/equipment/<qrId>`
- Torch toggle if supported
- Recent scans list (localStorage)

- [ ] **Step 3: Create equipment.js**

Equipment view (ported from Flutter app's equipment_screen.dart):
- Fetches `/api/equipment/<qrId>` for live data
- Fetches `/api/equipment/<qrId>/notes`
- Header card: equipment name, station, location, path, online/offline badge
- Points list with Niagara status color mapping (alarm/fault/down/stale/overridden/disabled)
- Notes section with add/view
- Refresh button + auto-refresh every 30s
- QR ID footer

- [ ] **Step 4: Commit**

```bash
git add server/web/js/scanner.js server/web/js/equipment.js
git commit -m "feat: add QR scanner and equipment live data view"
```

---

## Task 7: PWA Frontend — Admin Section

**Files:**
- Create: `server/web/js/admin.js`
- Create: `server/web/js/tree-browser.js`

- [ ] **Step 1: Create admin.js**

Admin section with sub-views:
- Station list: cards with name/host/port, add/edit/delete
- Station form: name, host, port, protocol, connector type, username, password, test connection, save
- Equipment list: cards with name/path/station, add/edit/delete, view QR
- Equipment form: station picker, browse tree button, name, path, BQL query, point paths, location, save
- QR view: shows QR image from `/api/admin/equipment/<qrId>/qr.png`, print button

All admin views rendered within the `#/admin` hash route with internal sub-routing.

- [ ] **Step 2: Create tree-browser.js**

Modal tree browser (ported from Flutter's equipment_tree_browser.dart):
- Fetches station tree from `/api/stations/<id>/tree`
- Renders expandable/collapsible tree nodes
- Equipment nodes highlighted with point count
- Click equipment → returns selection (name, path, points)
- Close/cancel

- [ ] **Step 3: Commit**

```bash
git add server/web/js/admin.js server/web/js/tree-browser.js
git commit -m "feat: add admin UI for station and equipment management"
```

---

## Task 8: Wire Up Main + Embed Web Files

**Files:**
- Modify: `server/main.go`

- [ ] **Step 1: Update main.go with go:embed and full server startup**

```go
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

	srv := NewServer(db, connectors)

	// Serve embedded web files for non-API routes
	webFS, _ := fs.Sub(webFiles, "web")
	fileServer := http.FileServer(http.FS(webFS))

	mux := http.NewServeMux()
	mux.Handle("/api/", srv)
	mux.Handle("/", fileServer)

	addr := fmt.Sprintf(":%d", *port)
	localIP := getLocalIP()

	fmt.Println()
	fmt.Println("  QR Sidekick Server")
	fmt.Println("  ──────────────────")
	fmt.Printf("  Local:   http://localhost:%d\n", *port)
	fmt.Printf("  Network: http://%s:%d\n", localIP, *port)
	fmt.Printf("  Data:    %s\n", *dataDir)
	fmt.Println()

	log.Fatal(http.ListenAndServe(addr, mux))
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
```

- [ ] **Step 2: Update handlers.go route registration**

The Server's `mux` handles `/api/` routes. The main mux routes `/api/` to the server and everything else to the file server. Adjust `Server.routes()` paths to not include `/api/` prefix since the main mux strips it — actually, since we use `mux.Handle("/api/", srv)`, the server's internal routes should use the full path. Make sure the routing works.

The simplest approach: have the main mux just use `srv` directly (it handles both API and falls through to static files):

```go
// In Server.routes(), add at the end:
webFS, _ := fs.Sub(webFiles, "web")
s.mux.Handle("/", http.FileServer(http.FS(webFS)))
```

And in main.go, just use `srv` directly:
```go
log.Fatal(http.ListenAndServe(addr, srv))
```

- [ ] **Step 3: Verify build and run**

Run: `cd server && go build -o qr-sidekick-server && ./qr-sidekick-server`
Expected: Server starts, prints local and network URLs. Ctrl+C to stop.

- [ ] **Step 4: Commit**

```bash
git add server/main.go server/handlers.go
git commit -m "feat: embed web files and wire up complete server"
```

---

## Task 9: README

**Files:**
- Create: `server/README.md`

- [ ] **Step 1: Create README**

```markdown
# QR Sidekick Server

Self-hosted companion for QR Sidekick. Runs on your network — technicians scan QR codes on equipment and see live BAS data in their browser. No app store, no cloud, no logins.

## Quick Start

1. Download for your OS from Releases
2. Run: `./qr-sidekick-server`
3. Open `http://localhost:8080`
4. Add a station (enter Niagara host + credentials)
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

## Adding BAS Connectors

Implement the `Connector` interface:

```go
type MyConnector struct{}

func (c *MyConnector) DisplayName() string { return "My BAS" }
func (c *MyConnector) TypeID() string      { return "my-bas" }
func (c *MyConnector) TestConnection(host string, port int, protocol, username, password string) ConnResult { ... }
func (c *MyConnector) FetchTree(host string, port int, protocol, username, password string) TreeResult { ... }
func (c *MyConnector) FetchSnapshot(host string, port int, protocol, username, password, equipmentPath string) SnapResult { ... }
```

Register in main.go:
```go
connectors.Register(&MyConnector{})
```
```

- [ ] **Step 2: Commit**

```bash
git add server/README.md
git commit -m "docs: add server README with build and usage instructions"
```

---

## Summary

| Task | What | Dependencies |
|------|------|-------------|
| 1 | Go project scaffold | None |
| 2 | SQLite database layer | Task 1 |
| 3 | Connector interface + Niagara | Task 1 |
| 4 | HTTP handlers + QR generation | Tasks 2, 3 |
| 5 | PWA shell + CSS theme | Task 1 |
| 6 | Scanner + equipment view | Task 5 |
| 7 | Admin UI | Task 5 |
| 8 | Wire up main + embed | Tasks 4, 5, 6, 7 |
| 9 | README | Task 8 |

Tasks 2+3 can run in parallel. Tasks 5+6+7 can run in parallel with tasks 2+3+4 (frontend doesn't depend on backend until Task 8 wires them together).
