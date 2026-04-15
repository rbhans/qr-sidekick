package main

import (
	"testing"
)

func TestNiagaraConnectorInterface(t *testing.T) {
	var c Connector = &NiagaraConnector{}

	if c.TypeID() != "niagara" {
		t.Errorf("TypeID() = %q, want %q", c.TypeID(), "niagara")
	}
	if c.DisplayName() != "Niagara 4" {
		t.Errorf("DisplayName() = %q, want %q", c.DisplayName(), "Niagara 4")
	}
}

func TestParseCsvLine(t *testing.T) {
	tests := []struct {
		name string
		line string
		want []string
	}{
		{
			name: "basic CSV",
			line: "a,b,c",
			want: []string{"a", "b", "c"},
		},
		{
			name: "quoted commas",
			line: `a,"b,c",d`,
			want: []string{"a", "b,c", "d"},
		},
		{
			name: "escaped quotes",
			line: `a,"b""c",d`,
			want: []string{"a", `b"c`, "d"},
		},
		{
			name: "single value",
			line: "hello",
			want: []string{"hello"},
		},
		{
			name: "empty fields",
			line: "a,,c",
			want: []string{"a", "", "c"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := parseCsvLine(tt.line)
			if len(got) != len(tt.want) {
				t.Fatalf("parseCsvLine(%q) returned %d fields, want %d: %v", tt.line, len(got), len(tt.want), got)
			}
			for i := range got {
				if got[i] != tt.want[i] {
					t.Errorf("parseCsvLine(%q)[%d] = %q, want %q", tt.line, i, got[i], tt.want[i])
				}
			}
		})
	}
}

func TestParseHTMLTableToCSV(t *testing.T) {
	html := `<html><body>
<table>
  <tr><th>Name</th><th>Value</th></tr>
  <tr><td>Temp</td><td>72.5</td></tr>
  <tr><td>Fan</td><td>On</td></tr>
</table>
</body></html>`

	csv := parseHTMLTableToCSV(html)
	if csv == "" {
		t.Fatal("parseHTMLTableToCSV returned empty string")
	}

	lines := splitNonEmpty(csv, "\n")
	if len(lines) != 3 {
		t.Fatalf("expected 3 lines, got %d: %v", len(lines), lines)
	}

	// Header
	if lines[0] != "Name,Value" {
		t.Errorf("header = %q, want %q", lines[0], "Name,Value")
	}
	if lines[1] != "Temp,72.5" {
		t.Errorf("row 1 = %q, want %q", lines[1], "Temp,72.5")
	}
	if lines[2] != "Fan,On" {
		t.Errorf("row 2 = %q, want %q", lines[2], "Fan,On")
	}
}

func TestParseStationTree(t *testing.T) {
	csv := `Slot Path,Point Type,Facets
slot:/Drivers/NiagaraNetwork/Jace01/points/ZoneTemp,control:NumericPoint,units=fahrenheit
slot:/Drivers/NiagaraNetwork/Jace01/points/FanCmd,control:BooleanPoint,
slot:/Drivers/NiagaraNetwork/Jace02/points/DamperPos,control:NumericPoint,units=percent`

	equipment := parseStationTree(csv)
	if len(equipment) != 2 {
		t.Fatalf("expected 2 equipment, got %d", len(equipment))
	}

	// First equipment
	if equipment[0].Name != "Jace01" {
		t.Errorf("equipment[0].Name = %q, want %q", equipment[0].Name, "Jace01")
	}
	if len(equipment[0].Points) != 2 {
		t.Errorf("equipment[0] has %d points, want 2", len(equipment[0].Points))
	}

	// Second equipment
	if equipment[1].Name != "Jace02" {
		t.Errorf("equipment[1].Name = %q, want %q", equipment[1].Name, "Jace02")
	}
	if len(equipment[1].Points) != 1 {
		t.Errorf("equipment[1] has %d points, want 1", len(equipment[1].Points))
	}

	// Build tree and verify it is non-empty
	root := buildTree(equipment)
	if root == nil {
		t.Fatal("buildTree returned nil")
	}
	if len(root.Children) == 0 {
		t.Fatal("tree root has no children")
	}
	if root.Name != "Station" {
		t.Errorf("root.Name = %q, want %q", root.Name, "Station")
	}
}

func TestParseSnapshot(t *testing.T) {
	csv := `Slot Path,Value,Status
slot:/Drivers/NiagaraNetwork/Jace01/points/ZoneTemp,72.5,ok
slot:/Drivers/NiagaraNetwork/Jace01/points/FanCmd,true,alarm`

	points := parseSnapshot(csv)
	if len(points) != 2 {
		t.Fatalf("expected 2 points, got %d", len(points))
	}

	if points[0].Name != "ZoneTemp" {
		t.Errorf("points[0].Name = %q, want %q", points[0].Name, "ZoneTemp")
	}
	if points[0].Value != "72.5" {
		t.Errorf("points[0].Value = %q, want %q", points[0].Value, "72.5")
	}
	if points[0].Status != "ok" {
		t.Errorf("points[0].Status = %q, want %q", points[0].Status, "ok")
	}

	if points[1].Name != "FanCmd" {
		t.Errorf("points[1].Name = %q, want %q", points[1].Name, "FanCmd")
	}
	if points[1].Value != "true" {
		t.Errorf("points[1].Value = %q, want %q", points[1].Value, "true")
	}
	if points[1].Status != "alarm" {
		t.Errorf("points[1].Status = %q, want %q", points[1].Status, "alarm")
	}
}

func TestConnectorRegistry(t *testing.T) {
	reg := NewConnectorRegistry()

	// Get missing returns nil
	if got := reg.Get("niagara"); got != nil {
		t.Errorf("Get before Register returned non-nil: %v", got)
	}

	// Register
	c := &NiagaraConnector{}
	reg.Register(c)

	// Get existing
	got := reg.Get("niagara")
	if got == nil {
		t.Fatal("Get after Register returned nil")
	}
	if got.TypeID() != "niagara" {
		t.Errorf("Get returned connector with TypeID %q, want %q", got.TypeID(), "niagara")
	}

	// Get missing still nil
	if got := reg.Get("bacnet"); got != nil {
		t.Errorf("Get('bacnet') returned non-nil: %v", got)
	}

	// All
	all := reg.All()
	if len(all) != 1 {
		t.Fatalf("All() returned %d connectors, want 1", len(all))
	}
	if all[0].TypeID() != "niagara" {
		t.Errorf("All()[0].TypeID() = %q, want %q", all[0].TypeID(), "niagara")
	}
}
