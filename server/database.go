package main

import (
	"database/sql"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	_ "modernc.org/sqlite"
)

// Database wraps a sql.DB connection to SQLite.
type Database struct {
	db *sql.DB
}

// Station represents a Niagara station connection.
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

// Equipment represents a piece of equipment linked to a station.
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

// Note represents a note attached to a piece of equipment.
type Note struct {
	ID        int64  `json:"id"`
	QRID      string `json:"qrId"`
	Content   string `json:"content"`
	CreatedAt string `json:"createdAt"`
}

// NewDatabase opens a SQLite database at the given path, enables foreign keys
// and WAL mode, and runs migrations.
func NewDatabase(path string) (*Database, error) {
	dsn := path + "?_pragma=foreign_keys(1)&_pragma=journal_mode(wal)"
	sqlDB, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, fmt.Errorf("open database: %w", err)
	}
	d := &Database{db: sqlDB}
	if err := d.migrate(); err != nil {
		sqlDB.Close()
		return nil, fmt.Errorf("migrate: %w", err)
	}
	return d, nil
}

// Close closes the underlying database connection.
func (d *Database) Close() error {
	return d.db.Close()
}

func (d *Database) migrate() error {
	const ddl = `
	CREATE TABLE IF NOT EXISTS settings (
		key   TEXT PRIMARY KEY,
		value TEXT NOT NULL
	);

	CREATE TABLE IF NOT EXISTS stations (
		id             INTEGER PRIMARY KEY AUTOINCREMENT,
		name           TEXT NOT NULL,
		host           TEXT NOT NULL,
		port           INTEGER NOT NULL,
		protocol       TEXT NOT NULL DEFAULT 'https',
		connector_type TEXT NOT NULL DEFAULT 'niagara',
		username       TEXT NOT NULL DEFAULT '',
		password       TEXT NOT NULL DEFAULT '',
		created_at     TEXT NOT NULL DEFAULT (datetime('now'))
	);

	CREATE TABLE IF NOT EXISTS equipment (
		qr_id          TEXT PRIMARY KEY,
		station_id     INTEGER NOT NULL REFERENCES stations(id) ON DELETE CASCADE,
		equipment_name TEXT NOT NULL,
		equipment_path TEXT NOT NULL,
		bql_query      TEXT NOT NULL DEFAULT '',
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
	`
	_, err := d.db.Exec(ddl)
	return err
}

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

// GetSetting returns the value for a setting key, or empty string if not found.
func (d *Database) GetSetting(key string) (string, error) {
	var value string
	err := d.db.QueryRow("SELECT value FROM settings WHERE key = ?", key).Scan(&value)
	if err == sql.ErrNoRows {
		return "", nil
	}
	return value, err
}

// SetSetting upserts a setting key/value pair.
func (d *Database) SetSetting(key, value string) error {
	_, err := d.db.Exec(
		"INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
		key, value,
	)
	return err
}

// ---------------------------------------------------------------------------
// Stations
// ---------------------------------------------------------------------------

// CreateStation inserts a new station and returns its ID.
func (d *Database) CreateStation(s Station) (int64, error) {
	res, err := d.db.Exec(
		`INSERT INTO stations (name, host, port, protocol, connector_type, username, password)
		 VALUES (?, ?, ?, ?, ?, ?, ?)`,
		s.Name, s.Host, s.Port, s.Protocol, s.ConnectorType, s.Username, s.Password,
	)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

// GetStation returns a station by ID, including credentials.
func (d *Database) GetStation(id int64) (Station, error) {
	var s Station
	err := d.db.QueryRow(
		`SELECT id, name, host, port, protocol, connector_type, username, password, created_at
		 FROM stations WHERE id = ?`, id,
	).Scan(&s.ID, &s.Name, &s.Host, &s.Port, &s.Protocol, &s.ConnectorType, &s.Username, &s.Password, &s.CreatedAt)
	return s, err
}

// ListStations returns all stations without credentials.
func (d *Database) ListStations() ([]Station, error) {
	rows, err := d.db.Query(
		`SELECT id, name, host, port, protocol, connector_type, created_at FROM stations`,
	)
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
	return stations, rows.Err()
}

// UpdateStation updates a station by ID.
func (d *Database) UpdateStation(id int64, s Station) error {
	// Update core fields always.
	_, err := d.db.Exec(
		`UPDATE stations SET name=?, host=?, port=?, protocol=?, connector_type=? WHERE id=?`,
		s.Name, s.Host, s.Port, s.Protocol, s.ConnectorType, id,
	)
	if err != nil {
		return err
	}
	// Only overwrite credentials when the client explicitly sent them.
	// Empty strings mean "leave existing credentials alone" (admin form sends
	// blank fields when the operator is not changing the password).
	if s.Username != "" {
		if _, err := d.db.Exec("UPDATE stations SET username=? WHERE id=?", s.Username, id); err != nil {
			return err
		}
	}
	if s.Password != "" {
		if _, err := d.db.Exec("UPDATE stations SET password=? WHERE id=?", s.Password, id); err != nil {
			return err
		}
	}
	return nil
}

// DeleteStation deletes a station by ID (cascades to equipment and notes).
func (d *Database) DeleteStation(id int64) error {
	_, err := d.db.Exec("DELETE FROM stations WHERE id = ?", id)
	return err
}

// ---------------------------------------------------------------------------
// Equipment
// ---------------------------------------------------------------------------

// CreateEquipment inserts a new equipment record with a generated UUID qrId.
func (d *Database) CreateEquipment(e Equipment) (string, error) {
	qrID := uuid.New().String()
	pointPaths, err := json.Marshal(e.PointPaths)
	if err != nil {
		return "", err
	}
	_, err = d.db.Exec(
		`INSERT INTO equipment (qr_id, station_id, equipment_name, equipment_path, bql_query, point_paths, location)
		 VALUES (?, ?, ?, ?, ?, ?, ?)`,
		qrID, e.StationID, e.EquipmentName, e.EquipmentPath, e.BQLQuery, string(pointPaths), e.Location,
	)
	if err != nil {
		return "", err
	}
	return qrID, nil
}

// GetEquipmentByQRID returns equipment by its QR ID.
func (d *Database) GetEquipmentByQRID(qrID string) (Equipment, error) {
	var e Equipment
	var pointPathsJSON string
	err := d.db.QueryRow(
		`SELECT qr_id, station_id, equipment_name, equipment_path, bql_query, point_paths, location, created_at
		 FROM equipment WHERE qr_id = ?`, qrID,
	).Scan(&e.QRID, &e.StationID, &e.EquipmentName, &e.EquipmentPath, &e.BQLQuery, &pointPathsJSON, &e.Location, &e.CreatedAt)
	if err != nil {
		return e, err
	}
	if err := json.Unmarshal([]byte(pointPathsJSON), &e.PointPaths); err != nil {
		return e, fmt.Errorf("unmarshal point_paths: %w", err)
	}
	return e, nil
}

// ListEquipmentByStation returns all equipment for a given station.
func (d *Database) ListEquipmentByStation(stationID int64) ([]Equipment, error) {
	return d.queryEquipment("SELECT qr_id, station_id, equipment_name, equipment_path, bql_query, point_paths, location, created_at FROM equipment WHERE station_id = ?", stationID)
}

// ListAllEquipment returns all equipment.
func (d *Database) ListAllEquipment() ([]Equipment, error) {
	return d.queryEquipment("SELECT qr_id, station_id, equipment_name, equipment_path, bql_query, point_paths, location, created_at FROM equipment")
}

func (d *Database) queryEquipment(query string, args ...any) ([]Equipment, error) {
	rows, err := d.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var equipment []Equipment
	for rows.Next() {
		var e Equipment
		var pointPathsJSON string
		if err := rows.Scan(&e.QRID, &e.StationID, &e.EquipmentName, &e.EquipmentPath, &e.BQLQuery, &pointPathsJSON, &e.Location, &e.CreatedAt); err != nil {
			return nil, err
		}
		if err := json.Unmarshal([]byte(pointPathsJSON), &e.PointPaths); err != nil {
			return nil, fmt.Errorf("unmarshal point_paths: %w", err)
		}
		equipment = append(equipment, e)
	}
	return equipment, rows.Err()
}

// UpdateEquipment updates equipment by QR ID.
func (d *Database) UpdateEquipment(qrID string, e Equipment) error {
	pointPaths, err := json.Marshal(e.PointPaths)
	if err != nil {
		return err
	}
	_, err = d.db.Exec(
		`UPDATE equipment SET station_id=?, equipment_name=?, equipment_path=?, bql_query=?, point_paths=?, location=?
		 WHERE qr_id=?`,
		e.StationID, e.EquipmentName, e.EquipmentPath, e.BQLQuery, string(pointPaths), e.Location, qrID,
	)
	return err
}

// DeleteEquipment deletes equipment by QR ID (cascades to notes).
func (d *Database) DeleteEquipment(qrID string) error {
	_, err := d.db.Exec("DELETE FROM equipment WHERE qr_id = ?", qrID)
	return err
}

// ---------------------------------------------------------------------------
// Notes
// ---------------------------------------------------------------------------

// AddNote adds a note to equipment and returns the note ID.
func (d *Database) AddNote(qrID, content string) (int64, error) {
	res, err := d.db.Exec(
		"INSERT INTO notes (qr_id, content) VALUES (?, ?)",
		qrID, content,
	)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

// GetNotes returns all notes for an equipment QR ID, newest first.
func (d *Database) GetNotes(qrID string) ([]Note, error) {
	rows, err := d.db.Query(
		"SELECT id, qr_id, content, created_at FROM notes WHERE qr_id = ? ORDER BY id DESC",
		qrID,
	)
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
	return notes, rows.Err()
}

// DeleteNote deletes a note by ID.
func (d *Database) DeleteNote(id int64) error {
	_, err := d.db.Exec("DELETE FROM notes WHERE id = ?", id)
	return err
}
