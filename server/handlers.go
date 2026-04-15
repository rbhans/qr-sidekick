package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"net/http"
	"strconv"
	"time"
)

// Server is the HTTP server for QR Sidekick.
type Server struct {
	db         *Database
	connectors *ConnectorRegistry
	mux        *http.ServeMux
}

// NewServer creates a new Server and registers all routes.
// webFS is served as a fallback for non-API routes (static files).
func NewServer(db *Database, connectors *ConnectorRegistry, webFS fs.FS) *Server {
	s := &Server{
		db:         db,
		connectors: connectors,
		mux:        http.NewServeMux(),
	}
	s.routes(webFS)
	return s
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// CORS headers on all responses.
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return
	}

	s.mux.ServeHTTP(w, r)
}

func (s *Server) routes(webFS fs.FS) {
	// Public (tech-facing)
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

	// Misc
	s.mux.HandleFunc("GET /api/connectors", s.handleListConnectors)

	// Static files (fallback for non-API routes)
	s.mux.Handle("/", http.FileServer(http.FS(webFS)))
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

func jsonResp(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func jsonError(w http.ResponseWriter, status int, msg string) {
	jsonResp(w, status, map[string]string{"error": msg})
}

func readJSON(r *http.Request, v any) error {
	defer r.Body.Close()
	body, err := io.ReadAll(r.Body)
	if err != nil {
		return err
	}
	return json.Unmarshal(body, v)
}

func nowISO() string {
	return time.Now().UTC().Format(time.RFC3339)
}

func parseIDParam(r *http.Request) (int64, error) {
	return strconv.ParseInt(r.PathValue("id"), 10, 64)
}

// stripCredentials returns a copy of the station with credentials removed.
func stripCredentials(s Station) Station {
	s.Username = ""
	s.Password = ""
	return s
}

// ---------------------------------------------------------------------------
// Public handlers
// ---------------------------------------------------------------------------

func (s *Server) handleGetLiveData(w http.ResponseWriter, r *http.Request) {
	qrID := r.PathValue("qrId")

	equip, err := s.db.GetEquipmentByQRID(qrID)
	if err == sql.ErrNoRows {
		jsonError(w, http.StatusNotFound, "equipment not found")
		return
	}
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	station, err := s.db.GetStation(equip.StationID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "station not found")
		return
	}

	connector := s.connectors.Get(station.ConnectorType)
	if connector == nil {
		jsonError(w, http.StatusInternalServerError, fmt.Sprintf("unsupported connector type: %s", station.ConnectorType))
		return
	}

	snap := connector.FetchSnapshot(
		station.Host, station.Port, station.Protocol,
		station.Username, station.Password,
		equip.EquipmentPath,
	)

	// Match results against configured pointPaths (in order).
	var points []PointValue
	if snap.OK && len(equip.PointPaths) > 0 {
		pointMap := make(map[string]PointValue)
		for _, pv := range snap.Points {
			pointMap[pv.Path] = pv
		}
		for _, pp := range equip.PointPaths {
			if pv, ok := pointMap[pp]; ok {
				points = append(points, pv)
			}
		}
	} else if snap.OK {
		points = snap.Points
	}

	if points == nil {
		points = []PointValue{}
	}

	jsonResp(w, http.StatusOK, map[string]any{
		"equipmentName": equip.EquipmentName,
		"stationName":   station.Name,
		"location":      equip.Location,
		"points":        points,
		"online":        snap.OK,
		"queriedAt":     nowISO(),
	})
}

func (s *Server) handleGetNotes(w http.ResponseWriter, r *http.Request) {
	qrID := r.PathValue("qrId")

	notes, err := s.db.GetNotes(qrID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if notes == nil {
		notes = []Note{}
	}
	jsonResp(w, http.StatusOK, notes)
}

func (s *Server) handleAddNote(w http.ResponseWriter, r *http.Request) {
	qrID := r.PathValue("qrId")

	var body struct {
		Content string `json:"content"`
	}
	if err := readJSON(r, &body); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if body.Content == "" {
		jsonError(w, http.StatusBadRequest, "content is required")
		return
	}

	id, err := s.db.AddNote(qrID, body.Content)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	jsonResp(w, http.StatusCreated, map[string]any{
		"id":        id,
		"qrId":      qrID,
		"content":   body.Content,
		"createdAt": nowISO(),
	})
}

// ---------------------------------------------------------------------------
// Station handlers
// ---------------------------------------------------------------------------

func (s *Server) handleListStations(w http.ResponseWriter, r *http.Request) {
	stations, err := s.db.ListStations()
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if stations == nil {
		stations = []Station{}
	}
	jsonResp(w, http.StatusOK, stations)
}

func (s *Server) handleGetStation(w http.ResponseWriter, r *http.Request) {
	id, err := parseIDParam(r)
	if err != nil {
		jsonError(w, http.StatusBadRequest, "invalid station id")
		return
	}

	station, err := s.db.GetStation(id)
	if err == sql.ErrNoRows {
		jsonError(w, http.StatusNotFound, "station not found")
		return
	}
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	jsonResp(w, http.StatusOK, stripCredentials(station))
}

func (s *Server) handleCreateStation(w http.ResponseWriter, r *http.Request) {
	var station Station
	if err := readJSON(r, &station); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid JSON")
		return
	}

	id, err := s.db.CreateStation(station)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	station.ID = id
	jsonResp(w, http.StatusCreated, stripCredentials(station))
}

func (s *Server) handleUpdateStation(w http.ResponseWriter, r *http.Request) {
	id, err := parseIDParam(r)
	if err != nil {
		jsonError(w, http.StatusBadRequest, "invalid station id")
		return
	}

	var station Station
	if err := readJSON(r, &station); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid JSON")
		return
	}

	if err := s.db.UpdateStation(id, station); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	jsonResp(w, http.StatusOK, map[string]string{"status": "updated"})
}

func (s *Server) handleDeleteStation(w http.ResponseWriter, r *http.Request) {
	id, err := parseIDParam(r)
	if err != nil {
		jsonError(w, http.StatusBadRequest, "invalid station id")
		return
	}

	if err := s.db.DeleteStation(id); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	jsonResp(w, http.StatusOK, map[string]string{"status": "deleted"})
}

func (s *Server) handleTestStation(w http.ResponseWriter, r *http.Request) {
	id, err := parseIDParam(r)
	if err != nil {
		jsonError(w, http.StatusBadRequest, "invalid station id")
		return
	}

	station, err := s.db.GetStation(id)
	if err == sql.ErrNoRows {
		jsonError(w, http.StatusNotFound, "station not found")
		return
	}
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	connector := s.connectors.Get(station.ConnectorType)
	if connector == nil {
		jsonError(w, http.StatusInternalServerError, fmt.Sprintf("unsupported connector type: %s", station.ConnectorType))
		return
	}

	result := connector.TestConnection(station.Host, station.Port, station.Protocol, station.Username, station.Password)
	jsonResp(w, http.StatusOK, result)
}

func (s *Server) handleStationTree(w http.ResponseWriter, r *http.Request) {
	id, err := parseIDParam(r)
	if err != nil {
		jsonError(w, http.StatusBadRequest, "invalid station id")
		return
	}

	station, err := s.db.GetStation(id)
	if err == sql.ErrNoRows {
		jsonError(w, http.StatusNotFound, "station not found")
		return
	}
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	connector := s.connectors.Get(station.ConnectorType)
	if connector == nil {
		jsonError(w, http.StatusInternalServerError, fmt.Sprintf("unsupported connector type: %s", station.ConnectorType))
		return
	}

	result := connector.FetchTree(station.Host, station.Port, station.Protocol, station.Username, station.Password)
	if !result.OK {
		jsonError(w, http.StatusBadGateway, result.Error)
		return
	}
	// Return the root node directly — frontend iterates its children.
	jsonResp(w, http.StatusOK, result.Root)
}

// ---------------------------------------------------------------------------
// Equipment handlers
// ---------------------------------------------------------------------------

func (s *Server) handleListEquipment(w http.ResponseWriter, r *http.Request) {
	equipment, err := s.db.ListAllEquipment()
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if equipment == nil {
		equipment = []Equipment{}
	}
	jsonResp(w, http.StatusOK, equipment)
}

func (s *Server) handleGetEquipment(w http.ResponseWriter, r *http.Request) {
	qrID := r.PathValue("qrId")

	equip, err := s.db.GetEquipmentByQRID(qrID)
	if err == sql.ErrNoRows {
		jsonError(w, http.StatusNotFound, "equipment not found")
		return
	}
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	jsonResp(w, http.StatusOK, equip)
}

func (s *Server) handleCreateEquipment(w http.ResponseWriter, r *http.Request) {
	var equip Equipment
	if err := readJSON(r, &equip); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if equip.PointPaths == nil {
		equip.PointPaths = []string{}
	}

	qrID, err := s.db.CreateEquipment(equip)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	equip.QRID = qrID
	jsonResp(w, http.StatusCreated, equip)
}

func (s *Server) handleUpdateEquipment(w http.ResponseWriter, r *http.Request) {
	qrID := r.PathValue("qrId")

	var equip Equipment
	if err := readJSON(r, &equip); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	if equip.PointPaths == nil {
		equip.PointPaths = []string{}
	}

	if err := s.db.UpdateEquipment(qrID, equip); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	jsonResp(w, http.StatusOK, map[string]string{"status": "updated"})
}

func (s *Server) handleDeleteEquipment(w http.ResponseWriter, r *http.Request) {
	qrID := r.PathValue("qrId")

	if err := s.db.DeleteEquipment(qrID); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	jsonResp(w, http.StatusOK, map[string]string{"status": "deleted"})
}

func (s *Server) handleQRCode(w http.ResponseWriter, r *http.Request) {
	qrID := r.PathValue("qrId")

	scheme := "https"
	if r.TLS == nil {
		scheme = "http"
	}
	host := r.Host

	url := fmt.Sprintf("%s://%s:#/equipment/%s", scheme, host, qrID)

	png, err := generateQRPNG(url, 512)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to generate QR code")
		return
	}

	w.Header().Set("Content-Type", "image/png")
	w.Header().Set("Content-Length", strconv.Itoa(len(png)))
	w.WriteHeader(http.StatusOK)
	w.Write(png)
}

// ---------------------------------------------------------------------------
// Connectors handler
// ---------------------------------------------------------------------------

func (s *Server) handleListConnectors(w http.ResponseWriter, r *http.Request) {
	type connectorInfo struct {
		TypeID      string `json:"typeId"`
		DisplayName string `json:"displayName"`
	}

	all := s.connectors.All()
	result := make([]connectorInfo, len(all))
	for i, c := range all {
		result[i] = connectorInfo{
			TypeID:      c.TypeID(),
			DisplayName: c.DisplayName(),
		}
	}

	jsonResp(w, http.StatusOK, result)
}
