package main

import (
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

	// Get missing key returns empty string.
	val, err := db.GetSetting("missing")
	if err != nil {
		t.Fatal(err)
	}
	if val != "" {
		t.Fatalf("expected empty string, got %q", val)
	}

	// Set and get.
	if err := db.SetSetting("theme", "dark"); err != nil {
		t.Fatal(err)
	}
	val, err = db.GetSetting("theme")
	if err != nil {
		t.Fatal(err)
	}
	if val != "dark" {
		t.Fatalf("expected %q, got %q", "dark", val)
	}

	// Overwrite.
	if err := db.SetSetting("theme", "light"); err != nil {
		t.Fatal(err)
	}
	val, err = db.GetSetting("theme")
	if err != nil {
		t.Fatal(err)
	}
	if val != "light" {
		t.Fatalf("expected %q, got %q", "light", val)
	}
}

func TestStationsCRUD(t *testing.T) {
	db := testDB(t)

	// Create.
	id, err := db.CreateStation(Station{
		Name:          "Test Station",
		Host:          "192.168.1.100",
		Port:          443,
		Protocol:      "https",
		ConnectorType: "niagara",
		Username:      "admin",
		Password:      "secret",
	})
	if err != nil {
		t.Fatal(err)
	}
	if id == 0 {
		t.Fatal("expected non-zero id")
	}

	// Get (includes credentials).
	s, err := db.GetStation(id)
	if err != nil {
		t.Fatal(err)
	}
	if s.Name != "Test Station" {
		t.Fatalf("expected %q, got %q", "Test Station", s.Name)
	}
	if s.Username != "admin" || s.Password != "secret" {
		t.Fatalf("expected credentials, got user=%q pass=%q", s.Username, s.Password)
	}

	// List (no credentials).
	stations, err := db.ListStations()
	if err != nil {
		t.Fatal(err)
	}
	if len(stations) != 1 {
		t.Fatalf("expected 1 station, got %d", len(stations))
	}
	if stations[0].Username != "" || stations[0].Password != "" {
		t.Fatalf("list should not include credentials, got user=%q pass=%q", stations[0].Username, stations[0].Password)
	}

	// Create equipment linked to station.
	qrID, err := db.CreateEquipment(Equipment{
		StationID:     id,
		EquipmentName: "AHU-1",
		EquipmentPath: "/slot/AHU1",
		PointPaths:    []string{"/point1"},
	})
	if err != nil {
		t.Fatal(err)
	}

	// Delete station cascades to equipment.
	if err := db.DeleteStation(id); err != nil {
		t.Fatal(err)
	}
	_, err = db.GetEquipmentByQRID(qrID)
	if err == nil {
		t.Fatal("expected equipment to be deleted after station cascade")
	}
}

func TestEquipmentCRUD(t *testing.T) {
	db := testDB(t)

	// Create station first.
	stationID, err := db.CreateStation(Station{
		Name:          "S1",
		Host:          "localhost",
		Port:          443,
		Protocol:      "https",
		ConnectorType: "niagara",
	})
	if err != nil {
		t.Fatal(err)
	}

	// Create equipment generates qrId.
	paths := []string{"/a/b/c", "/d/e/f"}
	qrID, err := db.CreateEquipment(Equipment{
		StationID:     stationID,
		EquipmentName: "VAV-101",
		EquipmentPath: "/slot/VAV101",
		BQLQuery:      "bql:select *",
		PointPaths:    paths,
		Location:      "Floor 2",
	})
	if err != nil {
		t.Fatal(err)
	}
	if qrID == "" {
		t.Fatal("expected non-empty qrId")
	}

	// Get by qrId.
	e, err := db.GetEquipmentByQRID(qrID)
	if err != nil {
		t.Fatal(err)
	}
	if e.EquipmentName != "VAV-101" {
		t.Fatalf("expected %q, got %q", "VAV-101", e.EquipmentName)
	}
	if e.Location != "Floor 2" {
		t.Fatalf("expected %q, got %q", "Floor 2", e.Location)
	}

	// PointPaths round-trip.
	if len(e.PointPaths) != 2 || e.PointPaths[0] != "/a/b/c" || e.PointPaths[1] != "/d/e/f" {
		t.Fatalf("point paths round-trip failed: got %v", e.PointPaths)
	}

	// List by station.
	list, err := db.ListEquipmentByStation(stationID)
	if err != nil {
		t.Fatal(err)
	}
	if len(list) != 1 {
		t.Fatalf("expected 1, got %d", len(list))
	}

	// List all.
	all, err := db.ListAllEquipment()
	if err != nil {
		t.Fatal(err)
	}
	if len(all) != 1 {
		t.Fatalf("expected 1, got %d", len(all))
	}
}

func TestNotesCRUD(t *testing.T) {
	db := testDB(t)

	// Setup: station + equipment.
	stationID, err := db.CreateStation(Station{
		Name: "S1", Host: "localhost", Port: 443, Protocol: "https", ConnectorType: "niagara",
	})
	if err != nil {
		t.Fatal(err)
	}
	qrID, err := db.CreateEquipment(Equipment{
		StationID: stationID, EquipmentName: "AHU-1", EquipmentPath: "/ahu1", PointPaths: []string{},
	})
	if err != nil {
		t.Fatal(err)
	}

	// Add 2 notes.
	id1, err := db.AddNote(qrID, "First note")
	if err != nil {
		t.Fatal(err)
	}
	id2, err := db.AddNote(qrID, "Second note")
	if err != nil {
		t.Fatal(err)
	}
	if id1 == 0 || id2 == 0 {
		t.Fatal("expected non-zero note ids")
	}

	// Get newest first.
	notes, err := db.GetNotes(qrID)
	if err != nil {
		t.Fatal(err)
	}
	if len(notes) != 2 {
		t.Fatalf("expected 2 notes, got %d", len(notes))
	}
	if notes[0].Content != "Second note" {
		t.Fatalf("expected newest first, got %q", notes[0].Content)
	}
	if notes[1].Content != "First note" {
		t.Fatalf("expected oldest second, got %q", notes[1].Content)
	}

	// Delete one.
	if err := db.DeleteNote(id1); err != nil {
		t.Fatal(err)
	}
	notes, err = db.GetNotes(qrID)
	if err != nil {
		t.Fatal(err)
	}
	if len(notes) != 1 {
		t.Fatalf("expected 1 note after delete, got %d", len(notes))
	}
	if notes[0].Content != "Second note" {
		t.Fatalf("expected %q, got %q", "Second note", notes[0].Content)
	}
}

func TestUpdateStationPreservesCredentialsWhenBlank(t *testing.T) {
	db := testDB(t)
	id, err := db.CreateStation(Station{
		Name: "S1", Host: "10.0.0.1", Port: 443,
		Protocol: "https", ConnectorType: "niagara",
		Username: "admin", Password: "secret",
	})
	if err != nil {
		t.Fatal(err)
	}

	// Update without credentials (simulates admin form save with blank fields).
	err = db.UpdateStation(id, Station{
		Name: "S1-renamed", Host: "10.0.0.2", Port: 8443,
		Protocol: "http", ConnectorType: "niagara",
		// Username and Password intentionally blank
	})
	if err != nil {
		t.Fatal(err)
	}

	got, err := db.GetStation(id)
	if err != nil {
		t.Fatal(err)
	}
	if got.Name != "S1-renamed" || got.Host != "10.0.0.2" || got.Port != 8443 || got.Protocol != "http" {
		t.Fatalf("core fields not updated: %+v", got)
	}
	if got.Username != "admin" || got.Password != "secret" {
		t.Fatalf("credentials were overwritten: %+v", got)
	}

	// Explicit credential change should work.
	err = db.UpdateStation(id, Station{
		Name: "S1-renamed", Host: "10.0.0.2", Port: 8443,
		Protocol: "http", ConnectorType: "niagara",
		Username: "newuser", Password: "newpass",
	})
	if err != nil {
		t.Fatal(err)
	}
	got, _ = db.GetStation(id)
	if got.Username != "newuser" || got.Password != "newpass" {
		t.Fatalf("credentials did not update when explicit: %+v", got)
	}
}
