package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"testing/fstest"
)

func testServer(t *testing.T) *Server {
	t.Helper()
	db := testDB(t)
	reg := NewConnectorRegistry()
	reg.Register(&NiagaraConnector{})
	return NewServer(db, reg, fstest.MapFS{})
}

func TestCreateAndListStations(t *testing.T) {
	srv := testServer(t)

	// POST create a station.
	body, _ := json.Marshal(Station{
		Name:          "My Station",
		Host:          "10.0.0.1",
		Port:          443,
		Protocol:      "https",
		ConnectorType: "niagara",
		Username:      "admin",
		Password:      "secret",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/stations", bytes.NewReader(body))
	w := httptest.NewRecorder()
	srv.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d: %s", w.Code, w.Body.String())
	}

	// Verify create response has no credentials.
	var created map[string]any
	json.Unmarshal(w.Body.Bytes(), &created)
	if created["username"] != "" && created["username"] != nil {
		t.Fatalf("create response should not include username, got %v", created["username"])
	}
	if created["password"] != "" && created["password"] != nil {
		t.Fatalf("create response should not include password, got %v", created["password"])
	}

	// GET list stations.
	req = httptest.NewRequest(http.MethodGet, "/api/stations", nil)
	w = httptest.NewRecorder()
	srv.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var stations []map[string]any
	json.Unmarshal(w.Body.Bytes(), &stations)
	if len(stations) != 1 {
		t.Fatalf("expected 1 station, got %d", len(stations))
	}
	if stations[0]["name"] != "My Station" {
		t.Fatalf("expected name %q, got %v", "My Station", stations[0]["name"])
	}
	// ListStations from DB already excludes credentials; verify.
	if stations[0]["username"] != "" && stations[0]["username"] != nil {
		t.Fatalf("list should not include username, got %v", stations[0]["username"])
	}
	if stations[0]["password"] != "" && stations[0]["password"] != nil {
		t.Fatalf("list should not include password, got %v", stations[0]["password"])
	}
}

func TestLiveDataNotFound(t *testing.T) {
	srv := testServer(t)

	req := httptest.NewRequest(http.MethodGet, "/api/equipment/nonexistent", nil)
	w := httptest.NewRecorder()
	srv.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d: %s", w.Code, w.Body.String())
	}

	var resp map[string]string
	json.Unmarshal(w.Body.Bytes(), &resp)
	if resp["error"] != "equipment not found" {
		t.Fatalf("expected 'equipment not found', got %q", resp["error"])
	}
}

func TestNotesEndpoint(t *testing.T) {
	srv := testServer(t)

	// Create station + equipment in DB.
	stationID, err := srv.db.CreateStation(Station{
		Name:          "S1",
		Host:          "localhost",
		Port:          443,
		Protocol:      "https",
		ConnectorType: "niagara",
	})
	if err != nil {
		t.Fatal(err)
	}

	qrID, err := srv.db.CreateEquipment(Equipment{
		StationID:     stationID,
		EquipmentName: "AHU-1",
		EquipmentPath: "/ahu1",
		PointPaths:    []string{},
	})
	if err != nil {
		t.Fatal(err)
	}

	// POST a note.
	noteBody, _ := json.Marshal(map[string]string{"content": "Filter changed"})
	req := httptest.NewRequest(http.MethodPost, "/api/equipment/"+qrID+"/notes", bytes.NewReader(noteBody))
	w := httptest.NewRecorder()
	srv.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d: %s", w.Code, w.Body.String())
	}

	var noteResp map[string]any
	json.Unmarshal(w.Body.Bytes(), &noteResp)
	if noteResp["content"] != "Filter changed" {
		t.Fatalf("expected content %q, got %v", "Filter changed", noteResp["content"])
	}

	// GET notes.
	req = httptest.NewRequest(http.MethodGet, "/api/equipment/"+qrID+"/notes", nil)
	w = httptest.NewRecorder()
	srv.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var notes []map[string]any
	json.Unmarshal(w.Body.Bytes(), &notes)
	if len(notes) != 1 {
		t.Fatalf("expected 1 note, got %d", len(notes))
	}
	if notes[0]["content"] != "Filter changed" {
		t.Fatalf("expected content %q, got %v", "Filter changed", notes[0]["content"])
	}
}

func TestCORSHeaders(t *testing.T) {
	srv := testServer(t)

	req := httptest.NewRequest(http.MethodOptions, "/api/stations", nil)
	w := httptest.NewRecorder()
	srv.ServeHTTP(w, req)

	if w.Code != http.StatusNoContent {
		t.Fatalf("expected 204, got %d", w.Code)
	}
	if got := w.Header().Get("Access-Control-Allow-Origin"); got != "*" {
		t.Fatalf("expected CORS origin *, got %q", got)
	}
}

func TestQRCodeEndpoint(t *testing.T) {
	srv := testServer(t)

	// Create station + equipment.
	stationID, err := srv.db.CreateStation(Station{
		Name: "S1", Host: "localhost", Port: 443, Protocol: "https", ConnectorType: "niagara",
	})
	if err != nil {
		t.Fatal(err)
	}
	qrID, err := srv.db.CreateEquipment(Equipment{
		StationID: stationID, EquipmentName: "AHU-1", EquipmentPath: "/ahu1", PointPaths: []string{},
	})
	if err != nil {
		t.Fatal(err)
	}

	req := httptest.NewRequest(http.MethodGet, "/api/admin/equipment/"+qrID+"/qr.png", nil)
	w := httptest.NewRecorder()
	srv.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}
	if ct := w.Header().Get("Content-Type"); ct != "image/png" {
		t.Fatalf("expected image/png, got %q", ct)
	}
	// PNG magic bytes.
	png := w.Body.Bytes()
	if len(png) < 8 || string(png[1:4]) != "PNG" {
		t.Fatal("response is not a valid PNG")
	}
}

func TestBuildEquipmentURL(t *testing.T) {
	cases := []struct {
		scheme, host, qrID, want string
	}{
		{"http", "192.168.1.50:8080", "abc", "http://192.168.1.50:8080/#/equipment/abc"},
		{"https", "qrbas.local:8443", "xyz", "https://qrbas.local:8443/#/equipment/xyz"},
		{"http", "localhost:8080", "id1", "http://localhost:8080/#/equipment/id1"},
	}
	for _, c := range cases {
		got := buildEquipmentURL(c.scheme, c.host, c.qrID)
		if got != c.want {
			t.Errorf("buildEquipmentURL(%q,%q,%q) = %q, want %q", c.scheme, c.host, c.qrID, got, c.want)
		}
	}
}

func TestNetworkInfoEndpoint(t *testing.T) {
	srv := testServer(t)
	srv.HTTPPort = 8080
	srv.HTTPSPort = 8443
	srv.MDNSHost = "qrbas.local"
	srv.CertPath = "/tmp/cert.pem"

	req := httptest.NewRequest(http.MethodGet, "/api/network", nil)
	w := httptest.NewRecorder()
	srv.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", w.Code)
	}
	var got map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &got); err != nil {
		t.Fatal(err)
	}
	if got["mdnsHost"] != "qrbas.local" {
		t.Errorf("mdnsHost = %v", got["mdnsHost"])
	}
	if got["certAvailable"] != true {
		t.Errorf("certAvailable = %v", got["certAvailable"])
	}
}

func TestListConnectors(t *testing.T) {
	srv := testServer(t)

	req := httptest.NewRequest(http.MethodGet, "/api/connectors", nil)
	w := httptest.NewRecorder()
	srv.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", w.Code)
	}

	var connectors []map[string]string
	json.Unmarshal(w.Body.Bytes(), &connectors)
	if len(connectors) != 1 {
		t.Fatalf("expected 1 connector, got %d", len(connectors))
	}
	if connectors[0]["typeId"] != "niagara" {
		t.Fatalf("expected typeId 'niagara', got %q", connectors[0]["typeId"])
	}
}
