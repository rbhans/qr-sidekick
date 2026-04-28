package main

// Connector abstracts communication with a BAS station.
type Connector interface {
	DisplayName() string
	TypeID() string
	TestConnection(host string, port int, protocol, username, password string) ConnResult
	FetchTree(host string, port int, protocol, username, password string) TreeResult
	FetchSnapshot(host string, port int, protocol, username, password, equipmentPath string) SnapResult
}

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

type ConnectorRegistry struct {
	connectors map[string]Connector
}

func NewConnectorRegistry() *ConnectorRegistry {
	return &ConnectorRegistry{connectors: make(map[string]Connector)}
}

func (r *ConnectorRegistry) Register(c Connector)        { r.connectors[c.TypeID()] = c }
func (r *ConnectorRegistry) Get(typeID string) Connector { return r.connectors[typeID] }
func (r *ConnectorRegistry) All() []Connector {
	out := make([]Connector, 0, len(r.connectors))
	for _, c := range r.connectors {
		out = append(out, c)
	}
	return out
}
