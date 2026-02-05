import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/station.dart';
import '../models/equipment_config.dart';

/// Client for communicating with Niagara 4 stations
/// Based on proven patterns from niagara-sidekick
class NiagaraClient {
  final FlutterSecureStorage _secureStorage;

  NiagaraClient({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Storage keys for credentials
  static String _usernameKey(String stationId) => 'niagara_${stationId}_username';
  static String _passwordKey(String stationId) => 'niagara_${stationId}_password';

  /// Store credentials securely for a station
  Future<void> storeCredentials({
    required String stationId,
    required String username,
    required String password,
  }) async {
    await _secureStorage.write(key: _usernameKey(stationId), value: username);
    await _secureStorage.write(key: _passwordKey(stationId), value: password);
  }

  /// Retrieve stored credentials for a station
  Future<({String? username, String? password})> getCredentials(String stationId) async {
    final username = await _secureStorage.read(key: _usernameKey(stationId));
    final password = await _secureStorage.read(key: _passwordKey(stationId));
    return (username: username, password: password);
  }

  /// Check if credentials exist for a station
  Future<bool> hasCredentials(String stationId) async {
    final creds = await getCredentials(stationId);
    return creds.username != null && creds.password != null;
  }

  /// Delete stored credentials for a station
  Future<void> deleteCredentials(String stationId) async {
    await _secureStorage.delete(key: _usernameKey(stationId));
    await _secureStorage.delete(key: _passwordKey(stationId));
  }

  /// Create an HTTP client that allows self-signed certificates
  http.Client _createClient({bool allowSelfSigned = true}) {
    if (allowSelfSigned) {
      final httpClient = HttpClient()
        ..badCertificateCallback = (cert, host, port) => true;
      return IOClient(httpClient);
    }
    return http.Client();
  }

  /// Test connection to a station
  Future<NiagaraConnectionResult> testConnection({
    required Station station,
    required String username,
    required String password,
  }) async {
    final client = _createClient();
    try {
      final uri = Uri.parse('${station.baseUrl}/ord');
      final basicAuth = base64Encode(utf8.encode('$username:$password'));

      final response = await client.get(
        uri,
        headers: {
          'Authorization': 'Basic $basicAuth',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 404) {
        // 200 = success, 404 = authenticated but no default ord (still valid)
        return NiagaraConnectionResult.success();
      } else if (response.statusCode == 401) {
        return NiagaraConnectionResult.authFailed('Invalid username or password');
      } else if (response.statusCode == 403) {
        return NiagaraConnectionResult.authFailed('Access forbidden - check user permissions');
      } else {
        return NiagaraConnectionResult.error('Unexpected response: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      return NiagaraConnectionResult.connectionFailed('Cannot connect to ${station.host}: ${e.message}');
    } on TimeoutException {
      return NiagaraConnectionResult.connectionFailed('Connection timed out');
    } on HandshakeException catch (e) {
      return NiagaraConnectionResult.connectionFailed('SSL/TLS error: ${e.message}');
    } catch (e) {
      return NiagaraConnectionResult.error('Connection error: $e');
    } finally {
      client.close();
    }
  }

  /// Fetch the station tree structure (all equipment and points)
  /// Uses BQL: select slotPath, type as 'Point Type', facets from control:ControlPoint
  Future<NiagaraTreeResult> fetchStationTree({
    required Station station,
    required String username,
    required String password,
  }) async {
    final client = _createClient();
    try {
      final basicAuth = base64Encode(utf8.encode('$username:$password'));

      // BQL query from niagara-sidekick
      const bqlQuery = "station:|slot:/Drivers|bql:select%20slotPath,%20type%20as%20'Point%20Type',%20facets%20from%20control:ControlPoint";

      // Format options to try (from niagara-sidekick)
      final formatOptions = [
        '&format=csv',
        '&export=csv',
        '&view=csv',
        '|view:web:CsvView',
        '|view:web:TextView',
        '', // Fallback: parse HTML
      ];

      String? csvContent;
      http.Response? lastResponse;

      for (final formatParam in formatOptions) {
        final testUrl = '${station.baseUrl}/ord?$bqlQuery$formatParam';
        print('NiagaraClient: Trying URL: $testUrl');

        try {
          final response = await client.get(
            Uri.parse(testUrl),
            headers: {
              'Authorization': 'Basic $basicAuth',
              'Accept': 'text/csv, text/plain, application/xml, */*',
            },
          ).timeout(const Duration(seconds: 30));

          lastResponse = response;

          if (response.statusCode != 200) {
            print('NiagaraClient: Status ${response.statusCode}');
            continue;
          }

          final data = response.body;

          // Check if we got CSV (not HTML)
          if (!data.contains('<!DOCTYPE') && !data.contains('<html')) {
            print('NiagaraClient: Got direct CSV with format: $formatParam');
            csvContent = data;
            break;
          }

          // If this is the fallback (empty string), try parsing HTML
          if (formatParam == '') {
            print('NiagaraClient: Got HTML, trying to extract data from iframe...');
            csvContent = await _fetchIframeContent(data, station.baseUrl, basicAuth, client);
            if (csvContent != null) {
              print('NiagaraClient: Extracted CSV from iframe');
              break;
            }
          }
        } catch (e) {
          print('NiagaraClient: Format $formatParam failed: $e');
        }
      }

      if (csvContent != null) {
        print('NiagaraClient: CSV lines: ${csvContent.split('\n').length}');
        final tree = _parseStationTree(csvContent);
        print('NiagaraClient: Parsed ${tree.equipment.length} equipment');
        return NiagaraTreeResult.success(tree);
      }

      if (lastResponse == null) {
        return NiagaraTreeResult.error('No response from station');
      }

      final response = lastResponse;

      if (response.statusCode == 200) {
        // Debug: log response format
        final body = response.body;
        print('NiagaraClient: Response length=${body.length}');
        // Print more of the body to understand structure
        if (body.length > 500) {
          print('NiagaraClient: Body start: ${body.substring(0, 500)}');
          print('NiagaraClient: Body middle: ${body.substring(body.length ~/ 2, (body.length ~/ 2) + 500 > body.length ? body.length : (body.length ~/ 2) + 500)}');
        } else {
          print('NiagaraClient: Full body: $body');
        }

        final csvContent = _extractCsvContent(body, station.baseUrl, basicAuth, client);
        if (csvContent != null) {
          print('NiagaraClient: CSV parsed, lines=${csvContent.split('\n').length}');
          final tree = _parseStationTree(csvContent);
          print('NiagaraClient: Tree parsed, equipment count=${tree.equipment.length}');
          return NiagaraTreeResult.success(tree);
        }
        // Provide more info about what we received
        final format = body.contains('<!DOCTYPE') ? 'HTML' : (body.contains('<?xml') ? 'XML' : 'Unknown');
        return NiagaraTreeResult.error('Could not parse station response (format: $format, len: ${body.length})');
      } else if (response.statusCode == 401) {
        return NiagaraTreeResult.authFailed('Authentication failed');
      } else {
        return NiagaraTreeResult.error('Failed to fetch tree: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      return NiagaraTreeResult.connectionFailed('Cannot connect: ${e.message}');
    } on TimeoutException {
      return NiagaraTreeResult.connectionFailed('Request timed out');
    } catch (e) {
      return NiagaraTreeResult.error('Error fetching tree: $e');
    } finally {
      client.close();
    }
  }

  /// Fetch CSV content from iframe in HTML response (niagara-sidekick approach)
  Future<String?> _fetchIframeContent(String html, String baseUrl, String basicAuth, http.Client client) async {
    try {
      // Look for iframe with id='servletViewWidget' (from niagara-sidekick)
      final iframeMatch = RegExp(
        r'''<iframe[^>]+id=['"]servletViewWidget['"][^>]+src=['"]([^'"]+)['"]''',
        caseSensitive: false,
      ).firstMatch(html);

      if (iframeMatch != null) {
        var iframeUrl = iframeMatch.group(1)!;
        print('NiagaraClient: Found iframe src: $iframeUrl');

        // Decode HTML entities first
        iframeUrl = iframeUrl
            .replaceAll('&#x27;', "'")
            .replaceAll('&#39;', "'")
            .replaceAll('&quot;', '"')
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>');

        // Make relative URL absolute
        if (iframeUrl.startsWith('/')) {
          iframeUrl = baseUrl + iframeUrl;
        }

        // URL decode
        iframeUrl = Uri.decodeFull(iframeUrl);
        print('NiagaraClient: Fetching iframe: $iframeUrl');

        final iframeResponse = await client.get(
          Uri.parse(iframeUrl),
          headers: {
            'Authorization': 'Basic $basicAuth',
            'Accept': 'text/html, */*',
          },
        ).timeout(const Duration(seconds: 30));

        if (iframeResponse.statusCode == 200) {
          final iframeHtml = iframeResponse.body;
          print('NiagaraClient: Iframe response length: ${iframeHtml.length}');

          // Parse table from iframe content
          final csv = _parseHtmlTableToCsv(iframeHtml);
          if (csv != null && csv.isNotEmpty) {
            return csv;
          }
        }
      } else {
        print('NiagaraClient: No servletViewWidget iframe found');
      }

      // Fallback: try to find any table in the main HTML
      final csv = _parseHtmlTableToCsv(html);
      return csv;
    } catch (e) {
      print('NiagaraClient: Error fetching iframe: $e');
      return null;
    }
  }

  /// Parse oBIX XML response to build station tree
  StationTree? _parseObixResponse(String body) {
    try {
      // oBIX returns XML with obj elements
      // Look for ref elements that represent points
      final equipment = <NiagaraEquipment>[];
      final pointPaths = <String>[];

      // Simple XML parsing - look for href attributes
      final hrefPattern = RegExp(r'href="([^"]+)"');
      final hrefMatches = hrefPattern.allMatches(body);
      for (final match in hrefMatches) {
        final href = match.group(1)!;
        if (href.contains('/points/') || href.endsWith('Point')) {
          pointPaths.add(href);
        }
      }

      // Also look for slot paths in the response
      final slotPattern = RegExp(r'slot:/[^\s<>"]+');
      final slotMatches = slotPattern.allMatches(body);
      for (final match in slotMatches) {
        pointPaths.add(match.group(0)!);
      }

      if (pointPaths.isEmpty) {
        print('NiagaraClient: No points found in oBIX response');
        return null;
      }

      print('NiagaraClient: Found ${pointPaths.length} paths in oBIX');

      // Group points by parent equipment
      final equipmentMap = <String, NiagaraEquipment>{};
      for (final path in pointPaths) {
        final segments = path.replaceFirst('slot:', '').split('/').where((s) => s.isNotEmpty).toList();
        if (segments.isEmpty) continue;

        final pointName = segments.removeLast();
        if (segments.isNotEmpty && segments.last == 'points') {
          segments.removeLast();
        }
        if (segments.isEmpty) continue;

        final equipName = segments.last;
        final equipPath = '/${segments.join('/')}';

        if (!equipmentMap.containsKey(equipPath)) {
          equipmentMap[equipPath] = NiagaraEquipment(
            name: equipName,
            path: equipPath,
            points: [],
          );
        }
        equipmentMap[equipPath]!.points.add(NiagaraPoint(
          name: pointName,
          path: path,
          type: 'Unknown',
        ));
      }

      final equipmentList = equipmentMap.values.toList();
      final root = _buildTree(equipmentList);

      return StationTree(equipment: equipmentList, root: root);
    } catch (e) {
      print('NiagaraClient: Error parsing oBIX: $e');
      return null;
    }
  }

  /// Extract CSV content from response (handles HTML table parsing if needed)
  String? _extractCsvContent(String body, String baseUrl, String authHeader, http.Client client) {
    // Check if response is already CSV (not HTML)
    if (!body.contains('<!DOCTYPE') && !body.contains('<html')) {
      return body;
    }

    // Parse HTML table to CSV (simplified version)
    return _parseHtmlTableToCsv(body);
  }

  /// Parse HTML table to CSV format
  String? _parseHtmlTableToCsv(String html) {
    try {
      print('NiagaraClient: Parsing HTML table...');

      // Simple regex-based table extraction
      final tableMatch = RegExp(r'<table[^>]*>(.*?)</table>', dotAll: true, caseSensitive: false).firstMatch(html);
      if (tableMatch == null) {
        print('NiagaraClient: No table found in HTML');
        // Try to find if there's a different structure
        if (html.contains('<pre>')) {
          // Some Niagara versions return CSV in <pre> tags
          final preMatch = RegExp(r'<pre[^>]*>(.*?)</pre>', dotAll: true).firstMatch(html);
          if (preMatch != null) {
            print('NiagaraClient: Found content in <pre> tags');
            return preMatch.group(1)?.trim();
          }
        }
        return null;
      }

      final tableContent = tableMatch.group(1)!;
      final rows = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true, caseSensitive: false).allMatches(tableContent);

      final csvLines = <String>[];
      for (final row in rows) {
        final rowContent = row.group(1)!;
        final cells = RegExp(r'<t[hd][^>]*>(.*?)</t[hd]>', dotAll: true, caseSensitive: false).allMatches(rowContent);
        final values = cells.map((c) {
          var text = c.group(1)!
              .replaceAll(RegExp(r'<[^>]+>'), '') // Remove HTML tags
              .replaceAll('&nbsp;', ' ')
              .replaceAll('&amp;', '&')
              .replaceAll('&lt;', '<')
              .replaceAll('&gt;', '>')
              .replaceAll('&#39;', "'")
              .replaceAll('&quot;', '"')
              .trim();
          // Escape CSV values
          if (text.contains(',') || text.contains('"') || text.contains('\n')) {
            text = '"${text.replaceAll('"', '""')}"';
          }
          return text;
        }).toList();
        if (values.isNotEmpty) {
          csvLines.add(values.join(','));
        }
      }

      print('NiagaraClient: Extracted ${csvLines.length} rows from HTML table');
      return csvLines.isNotEmpty ? csvLines.join('\n') : null;
    } catch (e) {
      print('NiagaraClient: Error parsing HTML table: $e');
      return null;
    }
  }

  /// Parse CSV content into station tree structure
  StationTree _parseStationTree(String csvContent) {
    final lines = csvContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) {
      return StationTree(equipment: [], root: TreeNode(name: 'Station', path: '/', children: []));
    }

    // Parse header
    final header = _parseCsvLine(lines[0]);
    final slotPathIndex = header.indexWhere((col) =>
        col.toLowerCase().contains('object') ||
        col.toLowerCase().contains('slot path') ||
        (col.toLowerCase().contains('slot') && col.toLowerCase().contains('path')));

    if (slotPathIndex == -1) {
      return StationTree(equipment: [], root: TreeNode(name: 'Station', path: '/', children: []));
    }

    final pointTypeIndex = header.indexWhere((col) =>
        col.toLowerCase().contains('point type') || col.toLowerCase().contains('type'));

    // Collect all point paths
    final pointPaths = <String>[];
    final pointTypes = <String, String>{};

    for (int i = 1; i < lines.length; i++) {
      final cols = _parseCsvLine(lines[i]);
      if (cols.length <= slotPathIndex) continue;

      var pointPath = cols[slotPathIndex].trim();
      if (!pointPath.startsWith('slot:/Drivers/')) continue;

      // Remove slot: prefix
      pointPath = pointPath.replaceFirst('slot:', '');
      pointPaths.add(pointPath);

      if (pointTypeIndex != -1 && cols.length > pointTypeIndex) {
        pointTypes[pointPath] = cols[pointTypeIndex].trim();
      }
    }

    // Build equipment list by grouping points
    final equipmentMap = <String, NiagaraEquipment>{};

    for (final pointPath in pointPaths) {
      final segments = pointPath.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) continue;

      final pointName = segments.removeLast();

      // Determine equipment path
      String equipmentPath;
      String equipmentName;

      if (segments.isNotEmpty && segments.last == 'points') {
        segments.removeLast(); // Remove 'points'
        if (segments.isEmpty) continue;
      }

      if (segments.isEmpty) continue;

      equipmentName = segments.last;
      equipmentPath = '/${segments.join('/')}';

      // Create equipment if it doesn't exist
      if (!equipmentMap.containsKey(equipmentPath)) {
        equipmentMap[equipmentPath] = NiagaraEquipment(
          name: equipmentName,
          path: equipmentPath,
          points: [],
        );
      }

      // Add point to equipment
      final pointType = pointTypes[pointPath];
      equipmentMap[equipmentPath]!.points.add(NiagaraPoint(
        name: pointName,
        path: pointPath,
        type: _extractSimpleType(pointType),
      ));
    }

    // Build tree structure
    final equipment = equipmentMap.values.toList();
    final root = _buildTree(equipment);

    return StationTree(equipment: equipment, root: root);
  }

  /// Parse a CSV line handling quoted values
  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    var current = '';
    var inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current += '"';
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(current);
        current = '';
      } else {
        current += char;
      }
    }
    result.add(current);
    return result;
  }

  /// Extract simple point type from full type string
  String _extractSimpleType(String? fullType) {
    if (fullType == null) return 'Unknown';

    final match = RegExp(r':(\w+)').firstMatch(fullType);
    if (match == null) return 'Unknown';

    final pointType = match.group(1)!;
    if (pointType.contains('Boolean')) return 'Boolean';
    if (pointType.contains('Numeric')) return 'Numeric';
    if (pointType.contains('Enum')) return 'Enum';
    if (pointType.contains('String')) return 'String';
    return 'Unknown';
  }

  /// Build tree structure from equipment list
  TreeNode _buildTree(List<NiagaraEquipment> equipment) {
    final root = TreeNode(name: 'Station', path: '/', children: []);

    // Add all equipment paths and their parents to tree
    final allPaths = <String>{};
    for (final equip in equipment) {
      allPaths.add(equip.path);
      // Add parent paths
      final segments = equip.path.split('/').where((s) => s.isNotEmpty).toList();
      var buildPath = '';
      for (final segment in segments) {
        buildPath += '/$segment';
        allPaths.add(buildPath);
      }
    }

    // Build tree from paths
    for (final path in allPaths) {
      final parts = path.split('/').where((p) => p.isNotEmpty && p != 'points').toList();
      var current = root;

      for (final part in parts) {
        var child = current.children.firstWhere(
          (c) => c.name == part,
          orElse: () {
            final newChild = TreeNode(name: part, path: '', children: []);
            current.children.add(newChild);
            return newChild;
          },
        );
        current = child;
      }
    }

    // Mark equipment nodes and set paths
    _markEquipmentNodes(root, '', equipment);

    return root;
  }

  void _markEquipmentNodes(TreeNode node, String parentPath, List<NiagaraEquipment> equipment) {
    final currentPath = parentPath.isEmpty ? '/${node.name}' : '$parentPath/${node.name}';

    // Root node special case
    if (node.name == 'Station') {
      node.path = '/';
      for (final child in node.children) {
        _markEquipmentNodes(child, '', equipment);
      }
      return;
    }

    node.path = currentPath;

    // Check if this node is equipment
    final equip = equipment.where((e) =>
        e.path == currentPath ||
        e.path.replaceAll('/points', '') == currentPath
    ).firstOrNull;

    if (equip != null) {
      node.isEquipment = true;
      node.pointCount = equip.points.length;
    }

    // Recurse to children
    for (final child in node.children) {
      _markEquipmentNodes(child, currentPath, equipment);
    }

    // Mark parent nodes as having equipment
    if (node.isEquipment || node.children.any((c) => c.hasEquipment)) {
      node.hasEquipment = true;
    }
  }

  /// Fetch current point values for an equipment path
  /// Uses BQL: select slotPath, out.value as 'Value', status as 'Status' from control:ControlPoint
  Future<NiagaraSnapshotResult> fetchEquipmentSnapshot({
    required Station station,
    required String equipmentPath,
  }) async {
    final creds = await getCredentials(station.id);
    if (creds.username == null || creds.password == null) {
      return NiagaraSnapshotResult.error('No credentials stored for this station');
    }

    final client = _createClient();
    try {
      // BQL query from niagara-sidekick - gets current values and status
      final bqlQuery = "station:|slot:$equipmentPath|bql:select%20slotPath,%20out.value%20as%20'Value',%20status%20as%20'Status'%20from%20control:ControlPoint";

      final uri = Uri.parse('${station.baseUrl}/ord?$bqlQuery');
      final basicAuth = base64Encode(utf8.encode('${creds.username}:${creds.password}'));

      print('NiagaraClient: Fetching snapshot for: $equipmentPath');

      final response = await client.get(
        uri,
        headers: {
          'Authorization': 'Basic $basicAuth',
          'Accept': 'text/csv, text/plain, */*',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        String? csvContent;
        final data = response.body;

        // Check if response is HTML with iframe (like tree fetch)
        if (data.contains('<!DOCTYPE') || data.contains('<html')) {
          print('NiagaraClient: Got HTML response, checking for iframe...');
          csvContent = await _fetchIframeContent(data, station.baseUrl, basicAuth, client);
        } else {
          csvContent = data;
        }

        if (csvContent != null && csvContent.isNotEmpty) {
          final snapshot = _parseSnapshot(csvContent);
          print('NiagaraClient: Parsed ${snapshot.length} point values');
          return NiagaraSnapshotResult.success(snapshot);
        }
        return NiagaraSnapshotResult.error('Could not parse snapshot response');
      } else if (response.statusCode == 401) {
        return NiagaraSnapshotResult.authFailed('Authentication failed');
      } else {
        return NiagaraSnapshotResult.error('Failed to fetch snapshot: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      return NiagaraSnapshotResult.connectionFailed('Cannot connect: ${e.message}');
    } on TimeoutException {
      return NiagaraSnapshotResult.connectionFailed('Request timed out');
    } catch (e) {
      return NiagaraSnapshotResult.error('Error fetching snapshot: $e');
    } finally {
      client.close();
    }
  }

  /// Parse snapshot CSV into point values
  List<PointValue> _parseSnapshot(String csvContent) {
    final lines = csvContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];

    final header = _parseCsvLine(lines[0]);
    print('NiagaraClient: Snapshot header: $header');

    final pathIndex = header.indexWhere((col) =>
        col.toLowerCase().contains('slot') || col.toLowerCase().contains('path') || col.toLowerCase().contains('object'));
    final valueIndex = header.indexWhere((col) => col.toLowerCase().contains('value'));
    final statusIndex = header.indexWhere((col) => col.toLowerCase().contains('status'));

    print('NiagaraClient: Column indices - path:$pathIndex, value:$valueIndex, status:$statusIndex');

    if (pathIndex == -1) return [];

    final points = <PointValue>[];
    for (int i = 1; i < lines.length; i++) {
      final cols = _parseCsvLine(lines[i]);
      if (cols.length <= pathIndex) continue;

      // Debug first row
      if (i == 1) {
        print('NiagaraClient: First data row: $cols');
      }

      var path = cols[pathIndex].trim().replaceFirst('slot:', '');
      final name = path.split('/').last;
      final value = valueIndex >= 0 && cols.length > valueIndex ? cols[valueIndex].trim() : '--';
      final status = statusIndex >= 0 && cols.length > statusIndex ? cols[statusIndex].trim() : null;

      points.add(PointValue(
        path: path,
        name: name,
        value: value,
        status: status,
      ));
    }

    return points;
  }

  /// Read multiple points by their paths (original method for compatibility)
  Future<List<NiagaraPointResult>> readPoints({
    required Station station,
    required List<String> pointPaths,
  }) async {
    // Use snapshot query for efficiency
    if (pointPaths.isEmpty) return [];

    // Find common parent path
    final firstPath = pointPaths.first;
    final segments = firstPath.split('/').where((s) => s.isNotEmpty).toList();
    segments.removeLast(); // Remove point name
    if (segments.isNotEmpty && segments.last == 'points') {
      segments.removeLast();
    }
    final equipmentPath = '/${segments.join('/')}';

    final snapshotResult = await fetchEquipmentSnapshot(
      station: station,
      equipmentPath: equipmentPath,
    );

    if (snapshotResult is NiagaraSnapshotSuccess) {
      final snapshot = snapshotResult.points;
      return pointPaths.map((path) {
        final point = snapshot.firstWhere(
          (p) => p.path == path || p.path.endsWith(path),
          orElse: () => PointValue(path: path, name: path.split('/').last, value: '--', status: 'not found'),
        );
        return NiagaraPointResult.success(point);
      }).toList();
    } else if (snapshotResult is NiagaraSnapshotAuthFailed) {
      return pointPaths
          .map((path) => NiagaraPointResult.authFailed(snapshotResult.message))
          .toList();
    } else if (snapshotResult is NiagaraSnapshotConnectionFailed) {
      return pointPaths
          .map((path) => NiagaraPointResult.connectionFailed(snapshotResult.message))
          .toList();
    } else {
      // Return error for all points
      final errorMsg = snapshotResult is NiagaraSnapshotError
          ? snapshotResult.message
          : 'Failed to fetch snapshot';
      return pointPaths.map((path) => NiagaraPointResult.error(errorMsg)).toList();
    }
  }
}

// ============================================================================
// Data Models
// ============================================================================

/// Station tree structure
class StationTree {
  final List<NiagaraEquipment> equipment;
  final TreeNode root;

  StationTree({required this.equipment, required this.root});
}

/// Equipment in the station
class NiagaraEquipment {
  final String name;
  final String path;
  final List<NiagaraPoint> points;

  NiagaraEquipment({
    required this.name,
    required this.path,
    required this.points,
  });
}

/// Point in the station
class NiagaraPoint {
  final String name;
  final String path;
  final String type;

  NiagaraPoint({
    required this.name,
    required this.path,
    required this.type,
  });
}

/// Tree node for hierarchical display
class TreeNode {
  final String name;
  String path;
  final List<TreeNode> children;
  bool isEquipment;
  bool hasEquipment;
  int pointCount;

  TreeNode({
    required this.name,
    required this.path,
    required this.children,
    this.isEquipment = false,
    this.hasEquipment = false,
    this.pointCount = 0,
  });
}

// ============================================================================
// Result Types
// ============================================================================

/// Result of a connection test
sealed class NiagaraConnectionResult {
  const NiagaraConnectionResult();

  factory NiagaraConnectionResult.success() = NiagaraConnectionSuccess;
  factory NiagaraConnectionResult.authFailed(String message) = NiagaraConnectionAuthFailed;
  factory NiagaraConnectionResult.connectionFailed(String message) = NiagaraConnectionFailed;
  factory NiagaraConnectionResult.error(String message) = NiagaraConnectionError;

  bool get isSuccess => this is NiagaraConnectionSuccess;
  String? get errorMessage => switch (this) {
    NiagaraConnectionSuccess() => null,
    NiagaraConnectionAuthFailed(message: final m) => m,
    NiagaraConnectionFailed(message: final m) => m,
    NiagaraConnectionError(message: final m) => m,
  };
}

class NiagaraConnectionSuccess extends NiagaraConnectionResult {
  const NiagaraConnectionSuccess();
}

class NiagaraConnectionAuthFailed extends NiagaraConnectionResult {
  final String message;
  const NiagaraConnectionAuthFailed(this.message);
}

class NiagaraConnectionFailed extends NiagaraConnectionResult {
  final String message;
  const NiagaraConnectionFailed(this.message);
}

class NiagaraConnectionError extends NiagaraConnectionResult {
  final String message;
  const NiagaraConnectionError(this.message);
}

/// Result of fetching station tree
sealed class NiagaraTreeResult {
  const NiagaraTreeResult();

  factory NiagaraTreeResult.success(StationTree tree) = NiagaraTreeSuccess;
  factory NiagaraTreeResult.authFailed(String message) = NiagaraTreeAuthFailed;
  factory NiagaraTreeResult.connectionFailed(String message) = NiagaraTreeConnectionFailed;
  factory NiagaraTreeResult.error(String message) = NiagaraTreeError;

  bool get isSuccess => this is NiagaraTreeSuccess;
}

class NiagaraTreeSuccess extends NiagaraTreeResult {
  final StationTree tree;
  const NiagaraTreeSuccess(this.tree);
}

class NiagaraTreeAuthFailed extends NiagaraTreeResult {
  final String message;
  const NiagaraTreeAuthFailed(this.message);
}

class NiagaraTreeConnectionFailed extends NiagaraTreeResult {
  final String message;
  const NiagaraTreeConnectionFailed(this.message);
}

class NiagaraTreeError extends NiagaraTreeResult {
  final String message;
  const NiagaraTreeError(this.message);
}

/// Result of fetching equipment snapshot
sealed class NiagaraSnapshotResult {
  const NiagaraSnapshotResult();

  factory NiagaraSnapshotResult.success(List<PointValue> points) = NiagaraSnapshotSuccess;
  factory NiagaraSnapshotResult.authFailed(String message) = NiagaraSnapshotAuthFailed;
  factory NiagaraSnapshotResult.connectionFailed(String message) = NiagaraSnapshotConnectionFailed;
  factory NiagaraSnapshotResult.error(String message) = NiagaraSnapshotError;

  bool get isSuccess => this is NiagaraSnapshotSuccess;
}

class NiagaraSnapshotSuccess extends NiagaraSnapshotResult {
  final List<PointValue> points;
  const NiagaraSnapshotSuccess(this.points);
}

class NiagaraSnapshotAuthFailed extends NiagaraSnapshotResult {
  final String message;
  const NiagaraSnapshotAuthFailed(this.message);
}

class NiagaraSnapshotConnectionFailed extends NiagaraSnapshotResult {
  final String message;
  const NiagaraSnapshotConnectionFailed(this.message);
}

class NiagaraSnapshotError extends NiagaraSnapshotResult {
  final String message;
  const NiagaraSnapshotError(this.message);
}

/// Result of reading a single point
sealed class NiagaraPointResult {
  const NiagaraPointResult();

  factory NiagaraPointResult.success(PointValue point) = NiagaraPointSuccess;
  factory NiagaraPointResult.notFound(String message) = NiagaraPointNotFound;
  factory NiagaraPointResult.authFailed(String message) = NiagaraPointAuthFailed;
  factory NiagaraPointResult.connectionFailed(String message) = NiagaraPointConnectionFailed;
  factory NiagaraPointResult.error(String message) = NiagaraPointError;

  bool get isSuccess => this is NiagaraPointSuccess;
  PointValue? get point => this is NiagaraPointSuccess
      ? (this as NiagaraPointSuccess).point
      : null;
}

class NiagaraPointSuccess extends NiagaraPointResult {
  final PointValue point;
  const NiagaraPointSuccess(this.point);
}

class NiagaraPointNotFound extends NiagaraPointResult {
  final String message;
  const NiagaraPointNotFound(this.message);
}

class NiagaraPointAuthFailed extends NiagaraPointResult {
  final String message;
  const NiagaraPointAuthFailed(this.message);
}

class NiagaraPointConnectionFailed extends NiagaraPointResult {
  final String message;
  const NiagaraPointConnectionFailed(this.message);
}

class NiagaraPointError extends NiagaraPointResult {
  final String message;
  const NiagaraPointError(this.message);
}
