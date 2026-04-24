package main

import (
	"crypto/tls"
	"fmt"
	"io"
	"log"
	"net/http"
	"regexp"
	"sort"
	"strings"
	"time"
)

// NiagaraConnector implements Connector for Niagara 4 stations.
type NiagaraConnector struct{}

func (n *NiagaraConnector) DisplayName() string { return "Niagara 4" }
func (n *NiagaraConnector) TypeID() string      { return "niagara" }

func (n *NiagaraConnector) newClient(timeout time.Duration) *http.Client {
	return &http.Client{
		Timeout: timeout,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
		},
	}
}

func (n *NiagaraConnector) basicAuth(username, password string) string {
	// Manual base64 to avoid import; use net/http SetBasicAuth instead.
	// Actually, we set the header via request.SetBasicAuth.
	return "" // unused, we use req.SetBasicAuth
}

func (n *NiagaraConnector) TestConnection(host string, port int, protocol, username, password string) ConnResult {
	client := n.newClient(10 * time.Second)
	// Hit the base ORD endpoint. Niagara returns 302 → station:|slot:/ on
	// successful auth. We disable redirects so we can inspect the status code
	// directly: 302 = auth OK, 401/403 = bad creds.
	client.CheckRedirect = func(req *http.Request, via []*http.Request) error {
		return http.ErrUseLastResponse
	}

	url := fmt.Sprintf("%s://%s:%d/ord", protocol, host, port)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return ConnResult{OK: false, Error: fmt.Sprintf("invalid request: %v", err)}
	}
	req.SetBasicAuth(username, password)

	resp, err := client.Do(req)
	if err != nil {
		return ConnResult{OK: false, Error: fmt.Sprintf("connection failed: %v", err)}
	}
	defer resp.Body.Close()
	io.Copy(io.Discard, resp.Body)

	switch resp.StatusCode {
	case 200, 302:
		return ConnResult{OK: true}
	case 401:
		return ConnResult{OK: false, Error: "invalid username or password"}
	case 403:
		return ConnResult{OK: false, Error: "access forbidden - check user permissions"}
	default:
		return ConnResult{OK: false, Error: fmt.Sprintf("unexpected response: %d", resp.StatusCode)}
	}
}

func (n *NiagaraConnector) FetchTree(host string, port int, protocol, username, password string) TreeResult {
	client := n.newClient(30 * time.Second)
	baseURL := fmt.Sprintf("%s://%s:%d", protocol, host, port)

	// Path-based ORD with fullScreen view returns an HTML table we can parse.
	bqlQuery := "station:%7Cslot:/Drivers%7Cbql:select%20slotPath,%20type%20as%20'Point%20Type',%20facets%20from%20control:ControlPoint%7Cview:?fullScreen=true"
	ordURL := fmt.Sprintf("%s/ord/%s", baseURL, bqlQuery)

	log.Printf("FetchTree: %s", ordURL)

	req, err := http.NewRequest("GET", ordURL, nil)
	if err != nil {
		return TreeResult{OK: false, Error: fmt.Sprintf("invalid request: %v", err)}
	}
	req.SetBasicAuth(username, password)
	req.Header.Set("Accept", "text/html, */*")

	start := time.Now()
	resp, err := client.Do(req)
	elapsed := time.Since(start)
	if err != nil {
		return TreeResult{OK: false, Error: fmt.Sprintf("cannot reach station: %v", err)}
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return TreeResult{OK: false, Error: fmt.Sprintf("read error: %v", err)}
	}

	log.Printf("FetchTree: HTTP %d in %s (%d bytes)", resp.StatusCode, elapsed, len(body))

	switch resp.StatusCode {
	case 401, 403:
		return TreeResult{OK: false, Error: "authentication failed"}
	case 404:
		return TreeResult{OK: false, Error: "ORD servlet returned 404 - check that /Drivers exists and the web service is enabled"}
	}
	if resp.StatusCode != 200 {
		return TreeResult{OK: false, Error: fmt.Sprintf("station returned HTTP %d", resp.StatusCode)}
	}

	csvContent := parseHTMLTableToCSV(string(body))
	if csvContent == "" {
		return TreeResult{OK: false, Error: "could not parse BQL response - no table found in response"}
	}

	equipment := parseStationTree(csvContent)
	root := buildTree(equipment)
	return TreeResult{OK: true, Root: root}
}

func (n *NiagaraConnector) FetchSnapshot(host string, port int, protocol, username, password, equipmentPath string) SnapResult {
	client := n.newClient(30 * time.Second)
	baseURL := fmt.Sprintf("%s://%s:%d", protocol, host, port)

	// URL-encode the equipment path for the ORD path segment.
	encodedPath := strings.ReplaceAll(equipmentPath, " ", "%20")
	bqlQuery := fmt.Sprintf("station:%%7Cslot:%s%%7Cbql:select%%20slotPath,%%20out.value%%20as%%20'Value',%%20status%%20as%%20'Status'%%20from%%20control:ControlPoint%%7Cview:?fullScreen=true", encodedPath)

	ordURL := fmt.Sprintf("%s/ord/%s", baseURL, bqlQuery)

	req, err := http.NewRequest("GET", ordURL, nil)
	if err != nil {
		return SnapResult{OK: false, Error: fmt.Sprintf("invalid request: %v", err)}
	}
	req.SetBasicAuth(username, password)
	req.Header.Set("Accept", "text/html, */*")

	resp, err := client.Do(req)
	if err != nil {
		return SnapResult{OK: false, Error: fmt.Sprintf("connection failed: %v", err)}
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return SnapResult{OK: false, Error: fmt.Sprintf("read error: %v", err)}
	}

	if resp.StatusCode == 401 || resp.StatusCode == 403 {
		return SnapResult{OK: false, Error: "authentication failed"}
	}
	if resp.StatusCode != 200 {
		return SnapResult{OK: false, Error: fmt.Sprintf("failed to fetch snapshot: %d", resp.StatusCode)}
	}

	csvContent := parseHTMLTableToCSV(string(body))
	if csvContent == "" {
		return SnapResult{OK: false, Error: "could not parse snapshot response"}
	}

	points := parseSnapshot(csvContent)
	return SnapResult{OK: true, Points: points}
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

// parseHTMLTableToCSV extracts the first HTML table into CSV lines.
func parseHTMLTableToCSV(html string) string {
	tableRe := regexp.MustCompile(`(?is)<table[^>]*>(.*?)</table>`)
	tableMatch := tableRe.FindStringSubmatch(html)
	if tableMatch == nil {
		// Try <pre> tags
		preRe := regexp.MustCompile(`(?is)<pre[^>]*>(.*?)</pre>`)
		preMatch := preRe.FindStringSubmatch(html)
		if preMatch != nil {
			return strings.TrimSpace(preMatch[1])
		}
		return ""
	}

	tableContent := tableMatch[1]
	rowRe := regexp.MustCompile(`(?is)<tr[^>]*>(.*?)</tr>`)
	rows := rowRe.FindAllStringSubmatch(tableContent, -1)

	cellRe := regexp.MustCompile(`(?is)<t[hd][^>]*>(.*?)</t[hd]>`)
	tagRe := regexp.MustCompile(`<[^>]+>`)

	var csvLines []string
	for _, row := range rows {
		cells := cellRe.FindAllStringSubmatch(row[1], -1)
		var values []string
		for _, cell := range cells {
			text := tagRe.ReplaceAllString(cell[1], "")
			text = strings.ReplaceAll(text, "&nbsp;", " ")
			text = strings.ReplaceAll(text, "&amp;", "&")
			text = strings.ReplaceAll(text, "&lt;", "<")
			text = strings.ReplaceAll(text, "&gt;", ">")
			text = strings.ReplaceAll(text, "&#39;", "'")
			text = strings.ReplaceAll(text, "&quot;", `"`)
			text = strings.TrimSpace(text)

			// Escape CSV values
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

// parseCsvLine parses a single CSV line, handling quoted values.
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

// findColumnIndex returns the index of the first column whose lowercased name
// contains any of the given substrings.
func findColumnIndex(header []string, subs ...string) int {
	for i, col := range header {
		low := strings.ToLower(strings.TrimSpace(col))
		for _, s := range subs {
			if strings.Contains(low, s) {
				return i
			}
		}
	}
	return -1
}

// splitNonEmpty splits s by sep and returns non-empty parts.
func splitNonEmpty(s, sep string) []string {
	parts := strings.Split(s, sep)
	var out []string
	for _, p := range parts {
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}

// splitPath splits a slash-separated path into non-empty segments.
func splitPath(path string) []string {
	return splitNonEmpty(path, "/")
}

// extractSimpleType extracts Boolean/Numeric/Enum/String from a Niagara type.
func extractSimpleType(fullType string) string {
	re := regexp.MustCompile(`:(\w+)`)
	m := re.FindStringSubmatch(fullType)
	if m == nil {
		return "Unknown"
	}
	pt := m[1]
	switch {
	case strings.Contains(pt, "Boolean"):
		return "Boolean"
	case strings.Contains(pt, "Numeric"):
		return "Numeric"
	case strings.Contains(pt, "Enum"):
		return "Enum"
	case strings.Contains(pt, "String"):
		return "String"
	default:
		return "Unknown"
	}
}

// parseStationTree parses CSV into a list of DiscoveredEquipment.
func parseStationTree(csvContent string) []DiscoveredEquipment {
	lines := splitNonEmpty(csvContent, "\n")
	if len(lines) == 0 {
		return nil
	}

	header := parseCsvLine(lines[0])
	slotPathIdx := findColumnIndex(header, "object", "slot path", "slotpath")
	// Fallback: first column containing "slot" and "path"
	if slotPathIdx == -1 {
		for i, col := range header {
			low := strings.ToLower(strings.TrimSpace(col))
			if strings.Contains(low, "slot") && strings.Contains(low, "path") {
				slotPathIdx = i
				break
			}
			// Also accept the first column if it looks like a path
			if i == 0 && strings.Contains(low, "slot") {
				slotPathIdx = i
				break
			}
		}
	}
	if slotPathIdx == -1 {
		return nil
	}

	pointTypeIdx := findColumnIndex(header, "point type", "type")

	type pointInfo struct {
		path     string
		fullType string
	}

	var points []pointInfo

	for i := 1; i < len(lines); i++ {
		line := strings.TrimSpace(lines[i])
		if line == "" {
			continue
		}
		cols := parseCsvLine(line)
		if len(cols) <= slotPathIdx {
			continue
		}

		pointPath := strings.TrimSpace(cols[slotPathIdx])
		if !strings.HasPrefix(pointPath, "slot:/Drivers/") {
			continue
		}

		// Remove "slot:" prefix
		pointPath = strings.TrimPrefix(pointPath, "slot:")

		var ft string
		if pointTypeIdx >= 0 && len(cols) > pointTypeIdx {
			ft = strings.TrimSpace(cols[pointTypeIdx])
		}

		points = append(points, pointInfo{path: pointPath, fullType: ft})
	}

	// Group points by equipment
	equipMap := make(map[string]*DiscoveredEquipment)
	var equipOrder []string

	for _, pt := range points {
		segments := splitPath(pt.path)
		if len(segments) == 0 {
			continue
		}

		pointName := segments[len(segments)-1]
		segments = segments[:len(segments)-1]

		// Remove trailing "points" folder
		if len(segments) > 0 && segments[len(segments)-1] == "points" {
			segments = segments[:len(segments)-1]
		}
		if len(segments) == 0 {
			continue
		}

		equipName := segments[len(segments)-1]
		equipPath := "/" + strings.Join(segments, "/")

		if _, ok := equipMap[equipPath]; !ok {
			equipMap[equipPath] = &DiscoveredEquipment{
				Name: equipName,
				Path: equipPath,
			}
			equipOrder = append(equipOrder, equipPath)
		}

		simpleType := "Unknown"
		if pt.fullType != "" {
			simpleType = extractSimpleType(pt.fullType)
		}

		equipMap[equipPath].Points = append(equipMap[equipPath].Points, DiscoveredPoint{
			Name: pointName,
			Path: pt.path,
			Type: simpleType,
		})
	}

	result := make([]DiscoveredEquipment, 0, len(equipOrder))
	for _, ep := range equipOrder {
		result = append(result, *equipMap[ep])
	}
	return result
}

// parseSnapshot parses CSV into a list of PointValue.
func parseSnapshot(csvContent string) []PointValue {
	lines := splitNonEmpty(csvContent, "\n")
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
	for i := 1; i < len(lines); i++ {
		line := strings.TrimSpace(lines[i])
		if line == "" {
			continue
		}
		cols := parseCsvLine(line)
		if len(cols) <= pathIdx {
			continue
		}

		path := strings.TrimSpace(cols[pathIdx])
		path = strings.TrimPrefix(path, "slot:")

		parts := splitPath(path)
		name := path
		if len(parts) > 0 {
			name = parts[len(parts)-1]
		}

		value := "--"
		if valueIdx >= 0 && len(cols) > valueIdx {
			value = strings.TrimSpace(cols[valueIdx])
		}

		var status string
		if statusIdx >= 0 && len(cols) > statusIdx {
			status = strings.TrimSpace(cols[statusIdx])
		}

		points = append(points, PointValue{
			Path:   path,
			Name:   name,
			Value:  value,
			Status: status,
		})
	}
	return points
}

// buildTree builds a TreeNode hierarchy from discovered equipment.
func buildTree(equipment []DiscoveredEquipment) *TreeNode {
	root := &TreeNode{
		Name:     "Station",
		Path:     "/",
		Children: []*TreeNode{},
	}

	if len(equipment) == 0 {
		return root
	}

	// Collect all paths (equipment + parents)
	allPaths := make(map[string]bool)
	for _, equip := range equipment {
		allPaths[equip.Path] = true
		segments := splitPath(equip.Path)
		var buildPath string
		for _, seg := range segments {
			buildPath += "/" + seg
			allPaths[buildPath] = true
		}
	}

	// Sort paths for deterministic tree order
	sortedPaths := make([]string, 0, len(allPaths))
	for p := range allPaths {
		sortedPaths = append(sortedPaths, p)
	}
	sort.Strings(sortedPaths)

	// Build tree from paths
	for _, p := range sortedPaths {
		parts := splitPath(p)
		// Filter out "points"
		var filtered []string
		for _, pt := range parts {
			if pt != "points" {
				filtered = append(filtered, pt)
			}
		}

		current := root
		for _, part := range filtered {
			var child *TreeNode
			for _, c := range current.Children {
				if c.Name == part {
					child = c
					break
				}
			}
			if child == nil {
				child = &TreeNode{
					Name:     part,
					Path:     "",
					Children: []*TreeNode{},
				}
				current.Children = append(current.Children, child)
			}
			current = child
		}
	}

	// Mark equipment nodes and set paths
	markEquipmentNodes(root, "", equipment)

	// Sort all children alphabetically
	sortTreeChildren(root)

	return root
}

// sortTreeChildren recursively sorts children alphabetically with folders first.
func sortTreeChildren(node *TreeNode) {
	if len(node.Children) == 0 {
		return
	}
	sort.Slice(node.Children, func(i, j int) bool {
		// Folders (non-equipment) before equipment
		if node.Children[i].IsEquipment != node.Children[j].IsEquipment {
			return !node.Children[i].IsEquipment
		}
		return strings.ToLower(node.Children[i].Name) < strings.ToLower(node.Children[j].Name)
	})
	for _, child := range node.Children {
		sortTreeChildren(child)
	}
}

// markEquipmentNodes sets isEquipment, hasEquipment, pointCount, and path on
// each node in the tree.
func markEquipmentNodes(node *TreeNode, parentPath string, equipment []DiscoveredEquipment) {
	if node.Name == "Station" {
		node.Path = "/"
		for _, child := range node.Children {
			markEquipmentNodes(child, "", equipment)
		}
		// Check if any child has equipment
		for _, child := range node.Children {
			if child.HasEquipment {
				node.HasEquipment = true
				break
			}
		}
		return
	}

	var currentPath string
	if parentPath == "" {
		currentPath = "/" + node.Name
	} else {
		currentPath = parentPath + "/" + node.Name
	}
	node.Path = currentPath

	// Check if this node is equipment
	for _, equip := range equipment {
		if equip.Path == currentPath || strings.TrimSuffix(equip.Path, "/points") == currentPath {
			node.IsEquipment = true
			node.PointCount = len(equip.Points)
			break
		}
	}

	// Recurse
	for _, child := range node.Children {
		markEquipmentNodes(child, currentPath, equipment)
	}

	// Mark hasEquipment
	if node.IsEquipment {
		node.HasEquipment = true
	} else {
		for _, child := range node.Children {
			if child.HasEquipment {
				node.HasEquipment = true
				break
			}
		}
	}
}
