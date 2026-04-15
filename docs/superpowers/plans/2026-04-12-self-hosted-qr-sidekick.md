# Self-Hosted QR Sidekick Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert QR Sidekick from a Flutter mobile app + Supabase backend into a self-hosted Dart server with web PWA frontend, where technicians scan QR codes containing URLs and see live BAS data with zero setup.

**Architecture:** A single Dart `shelf` server serves both a REST API and static web pages. SQLite (via `drift`) stores station configs, equipment, and encrypted credentials. A `BasConnector` interface abstracts BAS communication, with Niagara as the first implementation (ported from existing `niagara_client.dart`). Admin manages everything via web UI behind a password. Technicians access equipment pages via QR-encoded URLs with no auth required.

**Tech Stack:** Dart 3.x, shelf (HTTP server), drift (SQLite ORM), bcrypt (password hashing), qr (QR generation), multicast_dns (network discovery), plain HTML/CSS/JS (frontend)

---

## File Structure

```
server/
├── bin/
│   └── main.dart                          # Entry point: start shelf server, mDNS, setup wizard
├── lib/
│   ├── config.dart                        # Server config (port, data dir, etc.)
│   ├── database/
│   │   ├── database.dart                  # Drift database class
│   │   └── tables.dart                    # Table definitions (stations, equipment, settings)
│   ├── connectors/
│   │   ├── bas_connector.dart             # Abstract BAS connector interface
│   │   ├── connector_registry.dart        # Registry of available connectors
│   │   └── niagara/
│   │       ├── niagara_connector.dart     # Niagara implementation (ported from niagara_client.dart)
│   │       └── niagara_constants.dart     # BQL queries, format options (direct copy)
│   ├── auth/
│   │   └── admin_auth.dart               # Password hashing, token generation, middleware
│   ├── routes/
│   │   ├── router.dart                    # Top-level shelf router assembly
│   │   ├── api/
│   │   │   ├── stations_api.dart          # CRUD for stations
│   │   │   ├── equipment_api.dart         # CRUD for equipment configs
│   │   │   ├── live_data_api.dart         # Fetch live point values (public, keyed by qrId)
│   │   │   ├── setup_api.dart            # Initial setup (set admin password)
│   │   │   └── auth_api.dart             # Admin login/logout
│   │   └── middleware/
│   │       └── auth_middleware.dart        # Check admin token on /api/admin/* routes
│   └── services/
│       ├── qr_service.dart                # Generate QR code images with embedded URLs
│       └── mdns_service.dart              # Advertise server on local network
├── web/
│   ├── index.html                         # Landing page (link to admin)
│   ├── equipment.html                     # Tech view: live equipment data (public)
│   ├── admin/
│   │   ├── index.html                     # Admin dashboard
│   │   ├── login.html                     # Admin login
│   │   ├── setup.html                     # First-run setup wizard
│   │   ├── stations.html                  # Station list + add/edit
│   │   ├── station-form.html              # Station add/edit form
│   │   ├── equipment-list.html            # Equipment list
│   │   ├── equipment-form.html            # Equipment add/edit form + tree browser
│   │   └── qr-view.html                  # View/print QR code for equipment
│   ├── css/
│   │   └── style.css                      # Dark theme matching existing app colors
│   └── js/
│       ├── equipment.js                   # Tech view: fetch + render live points
│       ├── admin.js                       # Admin: shared auth, navigation, API calls
│       └── tree-browser.js                # Equipment tree browser (port of Flutter widget)
├── test/
│   ├── database/
│   │   └── database_test.dart
│   ├── connectors/
│   │   └── niagara_connector_test.dart
│   ├── routes/
│   │   ├── stations_api_test.dart
│   │   ├── equipment_api_test.dart
│   │   └── live_data_api_test.dart
│   └── auth/
│       └── admin_auth_test.dart
└── pubspec.yaml
```

---

## Task 1: Project Scaffold and Dependencies

**Files:**
- Create: `server/pubspec.yaml`
- Create: `server/bin/main.dart`
- Create: `server/lib/config.dart`
- Create: `server/analysis_options.yaml`

- [ ] **Step 1: Create server/pubspec.yaml**

```yaml
name: qr_sidekick_server
description: Self-hosted QR Sidekick companion server
version: 0.1.0
publish_to: none

environment:
  sdk: ^3.5.0

dependencies:
  shelf: ^1.4.2
  shelf_router: ^1.1.4
  shelf_static: ^1.1.3
  drift: ^2.22.1
  sqlite3_flutter_libs: ^0.5.28
  sqlite3: ^2.7.3
  http: ^1.3.0
  crypto: ^3.0.6
  uuid: ^4.5.1
  qr: ^3.0.2
  args: ^2.6.0
  path: ^1.9.1
  json_annotation: ^4.9.0
  multicast_dns: ^0.3.2+7
  image: ^4.5.3

dev_dependencies:
  test: ^1.25.8
  drift_dev: ^2.22.1
  build_runner: ^2.4.14
  json_serializable: ^6.9.4
  lints: ^5.1.1
```

- [ ] **Step 2: Create server/analysis_options.yaml**

```yaml
include: package:lints/recommended.yaml
```

- [ ] **Step 3: Create server/lib/config.dart**

```dart
import 'dart:io';
import 'package:path/path.dart' as p;

class ServerConfig {
  final int port;
  final String dataDir;
  final String webDir;

  ServerConfig({
    this.port = 8080,
    String? dataDir,
    String? webDir,
  })  : dataDir = dataDir ?? _defaultDataDir(),
        webDir = webDir ?? _defaultWebDir();

  String get databasePath => p.join(dataDir, 'qr_sidekick.db');

  static String _defaultDataDir() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return p.join(home, '.qr-sidekick');
  }

  static String _defaultWebDir() {
    // Relative to the executable location
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final webDir = p.join(exeDir, 'web');
    if (Directory(webDir).existsSync()) return webDir;
    // Fallback for development: relative to project root
    return p.join(Directory.current.path, 'web');
  }
}
```

- [ ] **Step 4: Create server/bin/main.dart (minimal, starts server)**

```dart
import 'dart:io';
import 'package:args/args.dart';
import 'package:qr_sidekick_server/config.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('port', abbr: 'p', defaultsTo: '8080', help: 'Port to listen on')
    ..addOption('data-dir', help: 'Directory for database and config')
    ..addFlag('help', abbr: 'h', negatable: false);

  final results = parser.parse(args);

  if (results['help'] as bool) {
    print('QR Sidekick Server');
    print(parser.usage);
    exit(0);
  }

  final config = ServerConfig(
    port: int.parse(results['port'] as String),
    dataDir: results['data-dir'] as String?,
  );

  // Ensure data directory exists
  await Directory(config.dataDir).create(recursive: true);

  print('QR Sidekick Server');
  print('  Data: ${config.dataDir}');
  print('  Web:  ${config.webDir}');
  print('  Port: ${config.port}');
  print('');
  print('Server will start after remaining tasks are implemented.');
}
```

- [ ] **Step 5: Run dart pub get to verify dependencies resolve**

Run: `cd server && dart pub get`
Expected: Dependencies resolve successfully.

- [ ] **Step 6: Verify the project compiles**

Run: `cd server && dart analyze`
Expected: No errors.

- [ ] **Step 7: Commit**

```bash
git add server/pubspec.yaml server/bin/main.dart server/lib/config.dart server/analysis_options.yaml
git commit -m "feat: scaffold self-hosted server project with dependencies"
```

---

## Task 2: Database Layer (Drift + SQLite)

**Files:**
- Create: `server/lib/database/tables.dart`
- Create: `server/lib/database/database.dart`
- Test: `server/test/database/database_test.dart`

- [ ] **Step 1: Write the database test**

```dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:qr_sidekick_server/database/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('settings', () {
    test('stores and retrieves admin password hash', () async {
      await db.setSetting('admin_password_hash', 'hashed_value');
      final value = await db.getSetting('admin_password_hash');
      expect(value, equals('hashed_value'));
    });

    test('returns null for missing setting', () async {
      final value = await db.getSetting('nonexistent');
      expect(value, isNull);
    });

    test('overwrites existing setting', () async {
      await db.setSetting('key', 'value1');
      await db.setSetting('key', 'value2');
      final value = await db.getSetting('key');
      expect(value, equals('value2'));
    });
  });

  group('stations', () {
    test('creates and retrieves a station', () async {
      final id = await db.createStation(
        name: 'Test JACE',
        host: '192.168.1.100',
        port: 443,
        protocol: 'https',
        connectorType: 'niagara',
        username: 'admin',
        password: 'encrypted_pass',
      );

      final station = await db.getStation(id);
      expect(station, isNotNull);
      expect(station!.name, equals('Test JACE'));
      expect(station.host, equals('192.168.1.100'));
      expect(station.port, equals(443));
      expect(station.connectorType, equals('niagara'));
    });

    test('lists all stations', () async {
      await db.createStation(
        name: 'Station 1', host: '10.0.0.1', port: 443,
        protocol: 'https', connectorType: 'niagara',
        username: 'u1', password: 'p1',
      );
      await db.createStation(
        name: 'Station 2', host: '10.0.0.2', port: 443,
        protocol: 'https', connectorType: 'niagara',
        username: 'u2', password: 'p2',
      );

      final stations = await db.listStations();
      expect(stations, hasLength(2));
    });

    test('deletes station cascades to equipment', () async {
      final stationId = await db.createStation(
        name: 'S1', host: '10.0.0.1', port: 443,
        protocol: 'https', connectorType: 'niagara',
        username: 'u', password: 'p',
      );

      await db.createEquipment(
        stationId: stationId,
        equipmentName: 'AHU-01',
        equipmentPath: '/Drivers/AHU01',
        bqlQuery: 'bql:select...',
        pointPaths: ['/points/Temp'],
      );

      await db.deleteStation(stationId);
      final equipment = await db.listEquipmentByStation(stationId);
      expect(equipment, isEmpty);
    });
  });

  group('equipment', () {
    late int stationId;

    setUp(() async {
      stationId = await db.createStation(
        name: 'S1', host: '10.0.0.1', port: 443,
        protocol: 'https', connectorType: 'niagara',
        username: 'u', password: 'p',
      );
    });

    test('creates equipment with generated qrId', () async {
      final qrId = await db.createEquipment(
        stationId: stationId,
        equipmentName: 'AHU-01',
        equipmentPath: '/Drivers/AHU01',
        bqlQuery: 'bql:select...',
        pointPaths: ['/points/Temp', '/points/Humidity'],
      );

      expect(qrId, isNotEmpty);

      final equip = await db.getEquipmentByQrId(qrId);
      expect(equip, isNotNull);
      expect(equip!.equipmentName, equals('AHU-01'));
      expect(equip.pointPaths, contains('/points/Temp'));
    });

    test('retrieves equipment with station info', () async {
      final qrId = await db.createEquipment(
        stationId: stationId,
        equipmentName: 'AHU-01',
        equipmentPath: '/Drivers/AHU01',
        bqlQuery: 'bql:select...',
        pointPaths: ['/points/Temp'],
      );

      final equip = await db.getEquipmentByQrId(qrId);
      expect(equip, isNotNull);
      expect(equip!.stationId, equals(stationId));
    });
  });

  group('notes', () {
    late int stationId;
    late String qrId;

    setUp(() async {
      stationId = await db.createStation(
        name: 'S1', host: '10.0.0.1', port: 443,
        protocol: 'https', connectorType: 'niagara',
        username: 'u', password: 'p',
      );
      qrId = await db.createEquipment(
        stationId: stationId,
        equipmentName: 'AHU-01',
        equipmentPath: '/Drivers/AHU01',
        bqlQuery: 'bql:select...',
        pointPaths: ['/points/Temp'],
      );
    });

    test('adds and retrieves notes', () async {
      await db.addNote(qrId: qrId, content: 'Filter replaced');
      await db.addNote(qrId: qrId, content: 'Belt tension checked');

      final notes = await db.getNotes(qrId);
      expect(notes, hasLength(2));
      expect(notes.first.content, equals('Belt tension checked')); // newest first
    });

    test('deletes a note', () async {
      final noteId = await db.addNote(qrId: qrId, content: 'To delete');
      await db.deleteNote(noteId);
      final notes = await db.getNotes(qrId);
      expect(notes, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && dart test test/database/database_test.dart`
Expected: FAIL — `database.dart` doesn't exist yet.

- [ ] **Step 3: Create server/lib/database/tables.dart**

```dart
import 'package:drift/drift.dart';

/// Server settings (admin password hash, server name, etc.)
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// BAS stations (Niagara or future connector types)
class Stations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get host => text()();
  IntColumn get port => integer().withDefault(const Constant(443))();
  TextColumn get protocol => text().withDefault(const Constant('https'))();
  /// Connector type: 'niagara', or future types
  TextColumn get connectorType => text().withDefault(const Constant('niagara'))();
  /// Encrypted credentials stored server-side
  TextColumn get username => text()();
  TextColumn get password => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Equipment configurations linked to stations
class EquipmentConfigs extends Table {
  /// UUID QR code identifier
  TextColumn get qrId => text()();
  IntColumn get stationId => integer().references(Stations, #id,
      onDelete: KeyAction.cascade)();
  TextColumn get equipmentName => text()();
  TextColumn get equipmentPath => text()();
  TextColumn get bqlQuery => text()();
  /// JSON-encoded list of point paths
  TextColumn get pointPaths => text()();
  TextColumn get location => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {qrId};
}

/// Notes on equipment (technician log entries)
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get qrId => text().references(EquipmentConfigs, #qrId,
      onDelete: KeyAction.cascade)();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

- [ ] **Step 4: Create server/lib/database/database.dart**

```dart
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Settings, Stations, EquipmentConfigs, Notes])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
      );

  // -- Settings --

  Future<String?> getSetting(String key) async {
    final row = await (select(settings)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) async {
    await into(settings).insertOnConflictUpdate(
      SettingsCompanion(
        key: Value(key),
        value: Value(value),
      ),
    );
  }

  // -- Stations --

  Future<int> createStation({
    required String name,
    required String host,
    required int port,
    required String protocol,
    required String connectorType,
    required String username,
    required String password,
  }) async {
    return into(stations).insert(
      StationsCompanion(
        name: Value(name),
        host: Value(host),
        port: Value(port),
        protocol: Value(protocol),
        connectorType: Value(connectorType),
        username: Value(username),
        password: Value(password),
      ),
    );
  }

  Future<Station?> getStation(int id) async {
    return (select(stations)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<Station>> listStations() async {
    return select(stations).get();
  }

  Future<void> updateStation({
    required int id,
    String? name,
    String? host,
    int? port,
    String? protocol,
    String? connectorType,
    String? username,
    String? password,
  }) async {
    await (update(stations)..where((t) => t.id.equals(id))).write(
      StationsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        host: host != null ? Value(host) : const Value.absent(),
        port: port != null ? Value(port) : const Value.absent(),
        protocol: protocol != null ? Value(protocol) : const Value.absent(),
        connectorType: connectorType != null ? Value(connectorType) : const Value.absent(),
        username: username != null ? Value(username) : const Value.absent(),
        password: password != null ? Value(password) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteStation(int id) async {
    await (delete(stations)..where((t) => t.id.equals(id))).go();
  }

  // -- Equipment --

  Future<String> createEquipment({
    required int stationId,
    required String equipmentName,
    required String equipmentPath,
    required String bqlQuery,
    required List<String> pointPaths,
    String? location,
  }) async {
    final qrId = const Uuid().v4();
    await into(equipmentConfigs).insert(
      EquipmentConfigsCompanion(
        qrId: Value(qrId),
        stationId: Value(stationId),
        equipmentName: Value(equipmentName),
        equipmentPath: Value(equipmentPath),
        bqlQuery: Value(bqlQuery),
        pointPaths: Value(jsonEncode(pointPaths)),
        location: Value(location),
      ),
    );
    return qrId;
  }

  Future<EquipmentConfig?> getEquipmentByQrId(String qrId) async {
    return (select(equipmentConfigs)..where((t) => t.qrId.equals(qrId)))
        .getSingleOrNull();
  }

  Future<List<EquipmentConfig>> listEquipmentByStation(int stationId) async {
    return (select(equipmentConfigs)
          ..where((t) => t.stationId.equals(stationId)))
        .get();
  }

  Future<List<EquipmentConfig>> listAllEquipment() async {
    return select(equipmentConfigs).get();
  }

  Future<void> updateEquipment({
    required String qrId,
    String? equipmentName,
    String? equipmentPath,
    String? bqlQuery,
    List<String>? pointPaths,
    String? location,
  }) async {
    await (update(equipmentConfigs)..where((t) => t.qrId.equals(qrId))).write(
      EquipmentConfigsCompanion(
        equipmentName: equipmentName != null ? Value(equipmentName) : const Value.absent(),
        equipmentPath: equipmentPath != null ? Value(equipmentPath) : const Value.absent(),
        bqlQuery: bqlQuery != null ? Value(bqlQuery) : const Value.absent(),
        pointPaths: pointPaths != null ? Value(jsonEncode(pointPaths)) : const Value.absent(),
        location: location != null ? Value(location) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteEquipment(String qrId) async {
    await (delete(equipmentConfigs)..where((t) => t.qrId.equals(qrId))).go();
  }

  // -- Notes --

  Future<int> addNote({required String qrId, required String content}) async {
    return into(notes).insert(
      NotesCompanion(
        qrId: Value(qrId),
        content: Value(content),
      ),
    );
  }

  Future<List<Note>> getNotes(String qrId) async {
    return (select(notes)
          ..where((t) => t.qrId.equals(qrId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<void> deleteNote(int noteId) async {
    await (delete(notes)..where((t) => t.id.equals(noteId))).go();
  }
}
```

- [ ] **Step 5: Run drift code generation**

Run: `cd server && dart run build_runner build --delete-conflicting-outputs`
Expected: Generates `database.g.dart` successfully.

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd server && dart test test/database/database_test.dart`
Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add server/lib/database/ server/test/database/
git commit -m "feat: add drift database layer with stations, equipment, notes tables"
```

---

## Task 3: BAS Connector Interface + Niagara Implementation

**Files:**
- Create: `server/lib/connectors/bas_connector.dart`
- Create: `server/lib/connectors/connector_registry.dart`
- Create: `server/lib/connectors/niagara/niagara_constants.dart`
- Create: `server/lib/connectors/niagara/niagara_connector.dart`
- Test: `server/test/connectors/niagara_connector_test.dart`

- [ ] **Step 1: Create the BAS connector interface**

```dart
// server/lib/connectors/bas_connector.dart

/// Result of testing a connection to a BAS station
sealed class ConnectionResult {
  const ConnectionResult();
  factory ConnectionResult.success() = ConnectionSuccess;
  factory ConnectionResult.authFailed(String message) = ConnectionAuthFailed;
  factory ConnectionResult.connectionFailed(String message) = ConnectionFailed;
  factory ConnectionResult.error(String message) = ConnectionError;

  bool get isSuccess => this is ConnectionSuccess;
  String? get errorMessage => switch (this) {
        ConnectionSuccess() => null,
        ConnectionAuthFailed(message: final m) => m,
        ConnectionFailed(message: final m) => m,
        ConnectionError(message: final m) => m,
      };
}

class ConnectionSuccess extends ConnectionResult {
  const ConnectionSuccess();
}

class ConnectionAuthFailed extends ConnectionResult {
  final String message;
  const ConnectionAuthFailed(this.message);
}

class ConnectionFailed extends ConnectionResult {
  final String message;
  const ConnectionFailed(this.message);
}

class ConnectionError extends ConnectionResult {
  final String message;
  const ConnectionError(this.message);
}

/// A live point value from a BAS station
class PointValue {
  final String path;
  final String name;
  final String value;
  final String? status;
  final String? type;

  const PointValue({
    required this.path,
    required this.name,
    required this.value,
    this.status,
    this.type,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'value': value,
        if (status != null) 'status': status,
        if (type != null) 'type': type,
      };
}

/// Equipment discovered from a BAS station
class DiscoveredEquipment {
  final String name;
  final String path;
  final List<DiscoveredPoint> points;

  const DiscoveredEquipment({
    required this.name,
    required this.path,
    required this.points,
  });
}

/// Point discovered during station tree browsing
class DiscoveredPoint {
  final String name;
  final String path;
  final String type;

  const DiscoveredPoint({
    required this.name,
    required this.path,
    required this.type,
  });
}

/// Tree node for hierarchical station browsing
class StationTreeNode {
  final String name;
  String path;
  final List<StationTreeNode> children;
  bool isEquipment;
  bool hasEquipment;
  int pointCount;

  StationTreeNode({
    required this.name,
    required this.path,
    required this.children,
    this.isEquipment = false,
    this.hasEquipment = false,
    this.pointCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'isEquipment': isEquipment,
        'hasEquipment': hasEquipment,
        'pointCount': pointCount,
        'children': children.map((c) => c.toJson()).toList(),
      };
}

/// Station tree with equipment list and hierarchical structure
class StationTree {
  final List<DiscoveredEquipment> equipment;
  final StationTreeNode root;

  const StationTree({required this.equipment, required this.root});
}

/// Result of fetching a station tree
sealed class TreeResult {
  const TreeResult();
  factory TreeResult.success(StationTree tree) = TreeSuccess;
  factory TreeResult.authFailed(String message) = TreeAuthFailed;
  factory TreeResult.connectionFailed(String message) = TreeConnectionFailed;
  factory TreeResult.error(String message) = TreeError;

  bool get isSuccess => this is TreeSuccess;
}

class TreeSuccess extends TreeResult {
  final StationTree tree;
  const TreeSuccess(this.tree);
}

class TreeAuthFailed extends TreeResult {
  final String message;
  const TreeAuthFailed(this.message);
}

class TreeConnectionFailed extends TreeResult {
  final String message;
  const TreeConnectionFailed(this.message);
}

class TreeError extends TreeResult {
  final String message;
  const TreeError(this.message);
}

/// Result of fetching live point values
sealed class SnapshotResult {
  const SnapshotResult();
  factory SnapshotResult.success(List<PointValue> points) = SnapshotSuccess;
  factory SnapshotResult.authFailed(String message) = SnapshotAuthFailed;
  factory SnapshotResult.connectionFailed(String message) = SnapshotConnectionFailed;
  factory SnapshotResult.error(String message) = SnapshotError;

  bool get isSuccess => this is SnapshotSuccess;
}

class SnapshotSuccess extends SnapshotResult {
  final List<PointValue> points;
  const SnapshotSuccess(this.points);
}

class SnapshotAuthFailed extends SnapshotResult {
  final String message;
  const SnapshotAuthFailed(this.message);
}

class SnapshotConnectionFailed extends SnapshotResult {
  final String message;
  const SnapshotConnectionFailed(this.message);
}

class SnapshotError extends SnapshotResult {
  final String message;
  const SnapshotError(this.message);
}

/// Abstract interface for BAS station connectors.
/// Implement this to add support for new BAS protocols beyond Niagara.
abstract class BasConnector {
  /// Human-readable name of this connector type (e.g., "Niagara 4")
  String get displayName;

  /// Machine identifier (e.g., "niagara") — matches station.connectorType in DB
  String get typeId;

  /// Test connectivity and authentication to a station
  Future<ConnectionResult> testConnection({
    required String host,
    required int port,
    required String protocol,
    required String username,
    required String password,
  });

  /// Fetch the equipment tree from a station (for admin browsing)
  Future<TreeResult> fetchStationTree({
    required String host,
    required int port,
    required String protocol,
    required String username,
    required String password,
  });

  /// Fetch live point values for an equipment path
  Future<SnapshotResult> fetchEquipmentSnapshot({
    required String host,
    required int port,
    required String protocol,
    required String username,
    required String password,
    required String equipmentPath,
  });
}
```

- [ ] **Step 2: Create the connector registry**

```dart
// server/lib/connectors/connector_registry.dart
import 'bas_connector.dart';

/// Registry of available BAS connectors.
/// Add new connector types here as they are implemented.
class ConnectorRegistry {
  final Map<String, BasConnector> _connectors = {};

  void register(BasConnector connector) {
    _connectors[connector.typeId] = connector;
  }

  BasConnector? get(String typeId) => _connectors[typeId];

  List<BasConnector> get all => _connectors.values.toList();

  List<String> get availableTypes => _connectors.keys.toList();
}
```

- [ ] **Step 3: Copy and adapt niagara_constants.dart**

```dart
// server/lib/connectors/niagara/niagara_constants.dart

/// Niagara-specific constants for BQL queries and API
class NiagaraConstants {
  NiagaraConstants._();

  static const int defaultPort = 443;
  static const String defaultProtocol = 'https';

  static const String baseControlPointQuery =
      "station:|slot:/Drivers|bql:select%20slotPath,%20type%20as%20'Point%20Type',%20facets%20from%20control:ControlPoint";

  static const List<String> formatOptions = [
    '&format=csv',
    '&export=csv',
    '&view=csv',
    '|view:web:CsvView',
    '|view:web:TextView',
    '|view:web:TableToCsv',
    '', // Fallback: attempt to parse HTML table
  ];

  static const List<String> expectedHeaders = [
    'slotPath',
    'Point Type',
    'facets',
  ];

  static const String slotPathPattern = r'^slot:/';
  static const String pointTypePattern = r':(\w+)$';
}
```

- [ ] **Step 4: Create NiagaraConnector (port of niagara_client.dart)**

```dart
// server/lib/connectors/niagara/niagara_connector.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../bas_connector.dart';
import 'niagara_constants.dart';

class NiagaraConnector extends BasConnector {
  @override
  String get displayName => 'Niagara 4';

  @override
  String get typeId => 'niagara';

  http.Client _createClient() {
    final httpClient = HttpClient()
      ..badCertificateCallback = (cert, host, port) => true;
    return IOClient(httpClient);
  }

  String _basicAuth(String username, String password) =>
      base64Encode(utf8.encode('$username:$password'));

  @override
  Future<ConnectionResult> testConnection({
    required String host,
    required int port,
    required String protocol,
    required String username,
    required String password,
  }) async {
    final client = _createClient();
    try {
      final uri = Uri.parse('$protocol://$host:$port/ord');
      final auth = _basicAuth(username, password);

      final response = await client.get(uri, headers: {
        'Authorization': 'Basic $auth',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 404) {
        return ConnectionResult.success();
      } else if (response.statusCode == 401) {
        return ConnectionResult.authFailed('Invalid username or password');
      } else if (response.statusCode == 403) {
        return ConnectionResult.authFailed('Access forbidden - check user permissions');
      } else {
        return ConnectionResult.error('Unexpected response: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      return ConnectionResult.connectionFailed('Cannot connect to $host: ${e.message}');
    } on TimeoutException {
      return ConnectionResult.connectionFailed('Connection timed out');
    } on HandshakeException catch (e) {
      return ConnectionResult.connectionFailed('SSL/TLS error: ${e.message}');
    } catch (e) {
      return ConnectionResult.error('Connection error: $e');
    } finally {
      client.close();
    }
  }

  @override
  Future<TreeResult> fetchStationTree({
    required String host,
    required int port,
    required String protocol,
    required String username,
    required String password,
  }) async {
    final client = _createClient();
    final baseUrl = '$protocol://$host:$port';
    try {
      final auth = _basicAuth(username, password);
      const bqlQuery = NiagaraConstants.baseControlPointQuery;

      String? csvContent;
      http.Response? lastResponse;

      for (final formatParam in NiagaraConstants.formatOptions) {
        final testUrl = '$baseUrl/ord?$bqlQuery$formatParam';

        try {
          final response = await client.get(
            Uri.parse(testUrl),
            headers: {
              'Authorization': 'Basic $auth',
              'Accept': 'text/csv, text/plain, application/xml, */*',
            },
          ).timeout(const Duration(seconds: 30));

          lastResponse = response;
          if (response.statusCode != 200) continue;

          final data = response.body;

          if (!data.contains('<!DOCTYPE') && !data.contains('<html')) {
            csvContent = data;
            break;
          }

          if (formatParam == '') {
            csvContent = await _fetchIframeContent(data, baseUrl, auth, client);
            if (csvContent != null) break;
          }
        } catch (_) {
          // Try next format
        }
      }

      if (csvContent != null) {
        final tree = _parseStationTree(csvContent);
        return TreeResult.success(tree);
      }

      if (lastResponse == null) {
        return TreeResult.error('No response from station');
      }

      if (lastResponse.statusCode == 200) {
        final body = lastResponse.body;
        final extracted = _parseHtmlTableToCsv(body);
        if (extracted != null) {
          final tree = _parseStationTree(extracted);
          return TreeResult.success(tree);
        }
        final format = body.contains('<!DOCTYPE')
            ? 'HTML'
            : (body.contains('<?xml') ? 'XML' : 'Unknown');
        return TreeResult.error(
            'Could not parse station response (format: $format, len: ${body.length})');
      } else if (lastResponse.statusCode == 401) {
        return TreeResult.authFailed('Authentication failed');
      } else {
        return TreeResult.error('Failed to fetch tree: ${lastResponse.statusCode}');
      }
    } on SocketException catch (e) {
      return TreeResult.connectionFailed('Cannot connect: ${e.message}');
    } on TimeoutException {
      return TreeResult.connectionFailed('Request timed out');
    } catch (e) {
      return TreeResult.error('Error fetching tree: $e');
    } finally {
      client.close();
    }
  }

  @override
  Future<SnapshotResult> fetchEquipmentSnapshot({
    required String host,
    required int port,
    required String protocol,
    required String username,
    required String password,
    required String equipmentPath,
  }) async {
    final client = _createClient();
    final baseUrl = '$protocol://$host:$port';
    try {
      final auth = _basicAuth(username, password);
      final bqlQuery =
          "station:|slot:$equipmentPath|bql:select%20slotPath,%20out.value%20as%20'Value',%20status%20as%20'Status'%20from%20control:ControlPoint";

      final uri = Uri.parse('$baseUrl/ord?$bqlQuery');

      final response = await client.get(uri, headers: {
        'Authorization': 'Basic $auth',
        'Accept': 'text/csv, text/plain, */*',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        String? csvContent;
        final data = response.body;

        if (data.contains('<!DOCTYPE') || data.contains('<html')) {
          csvContent = await _fetchIframeContent(data, baseUrl, auth, client);
        } else {
          csvContent = data;
        }

        if (csvContent != null && csvContent.isNotEmpty) {
          final snapshot = _parseSnapshot(csvContent);
          return SnapshotResult.success(snapshot);
        }
        return SnapshotResult.error('Could not parse snapshot response');
      } else if (response.statusCode == 401) {
        return SnapshotResult.authFailed('Authentication failed');
      } else {
        return SnapshotResult.error('Failed to fetch snapshot: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      return SnapshotResult.connectionFailed('Cannot connect: ${e.message}');
    } on TimeoutException {
      return SnapshotResult.connectionFailed('Request timed out');
    } catch (e) {
      return SnapshotResult.error('Error fetching snapshot: $e');
    } finally {
      client.close();
    }
  }

  // -- Private helpers (ported from niagara_client.dart) --

  Future<String?> _fetchIframeContent(
      String html, String baseUrl, String basicAuth, http.Client client) async {
    try {
      final iframeMatch = RegExp(
        r'''<iframe[^>]+id=['"]servletViewWidget['"][^>]+src=['"]([^'"]+)['"]''',
        caseSensitive: false,
      ).firstMatch(html);

      if (iframeMatch != null) {
        var iframeUrl = iframeMatch.group(1)!
            .replaceAll('&#x27;', "'")
            .replaceAll('&#39;', "'")
            .replaceAll('&quot;', '"')
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>');

        if (iframeUrl.startsWith('/')) {
          iframeUrl = baseUrl + iframeUrl;
        }
        iframeUrl = Uri.decodeFull(iframeUrl);

        final iframeResponse = await client.get(
          Uri.parse(iframeUrl),
          headers: {
            'Authorization': 'Basic $basicAuth',
            'Accept': 'text/html, */*',
          },
        ).timeout(const Duration(seconds: 30));

        if (iframeResponse.statusCode == 200) {
          final csv = _parseHtmlTableToCsv(iframeResponse.body);
          if (csv != null && csv.isNotEmpty) return csv;
        }
      }

      return _parseHtmlTableToCsv(html);
    } catch (_) {
      return null;
    }
  }

  String? _parseHtmlTableToCsv(String html) {
    try {
      final tableMatch = RegExp(r'<table[^>]*>(.*?)</table>',
              dotAll: true, caseSensitive: false)
          .firstMatch(html);

      if (tableMatch == null) {
        if (html.contains('<pre>')) {
          final preMatch =
              RegExp(r'<pre[^>]*>(.*?)</pre>', dotAll: true).firstMatch(html);
          if (preMatch != null) return preMatch.group(1)?.trim();
        }
        return null;
      }

      final tableContent = tableMatch.group(1)!;
      final rows = RegExp(r'<tr[^>]*>(.*?)</tr>',
              dotAll: true, caseSensitive: false)
          .allMatches(tableContent);

      final csvLines = <String>[];
      for (final row in rows) {
        final rowContent = row.group(1)!;
        final cells = RegExp(r'<t[hd][^>]*>(.*?)</t[hd]>',
                dotAll: true, caseSensitive: false)
            .allMatches(rowContent);
        final values = cells.map((c) {
          var text = c
              .group(1)!
              .replaceAll(RegExp(r'<[^>]+>'), '')
              .replaceAll('&nbsp;', ' ')
              .replaceAll('&amp;', '&')
              .replaceAll('&lt;', '<')
              .replaceAll('&gt;', '>')
              .replaceAll('&#39;', "'")
              .replaceAll('&quot;', '"')
              .trim();
          if (text.contains(',') || text.contains('"') || text.contains('\n')) {
            text = '"${text.replaceAll('"', '""')}"';
          }
          return text;
        }).toList();
        if (values.isNotEmpty) csvLines.add(values.join(','));
      }

      return csvLines.isNotEmpty ? csvLines.join('\n') : null;
    } catch (_) {
      return null;
    }
  }

  StationTree _parseStationTree(String csvContent) {
    final lines =
        csvContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) {
      return StationTree(
          equipment: [],
          root: StationTreeNode(name: 'Station', path: '/', children: []));
    }

    final header = _parseCsvLine(lines[0]);
    final slotPathIndex = header.indexWhere((col) =>
        col.toLowerCase().contains('object') ||
        col.toLowerCase().contains('slot path') ||
        (col.toLowerCase().contains('slot') &&
            col.toLowerCase().contains('path')));

    if (slotPathIndex == -1) {
      return StationTree(
          equipment: [],
          root: StationTreeNode(name: 'Station', path: '/', children: []));
    }

    final pointTypeIndex = header.indexWhere((col) =>
        col.toLowerCase().contains('point type') ||
        col.toLowerCase().contains('type'));

    final pointPaths = <String>[];
    final pointTypes = <String, String>{};

    for (int i = 1; i < lines.length; i++) {
      final cols = _parseCsvLine(lines[i]);
      if (cols.length <= slotPathIndex) continue;

      var pointPath = cols[slotPathIndex].trim();
      if (!pointPath.startsWith('slot:/Drivers/')) continue;

      pointPath = pointPath.replaceFirst('slot:', '');
      pointPaths.add(pointPath);

      if (pointTypeIndex != -1 && cols.length > pointTypeIndex) {
        pointTypes[pointPath] = cols[pointTypeIndex].trim();
      }
    }

    final equipmentMap = <String, DiscoveredEquipment>{};

    for (final pointPath in pointPaths) {
      final segments =
          pointPath.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) continue;

      final pointName = segments.removeLast();

      if (segments.isNotEmpty && segments.last == 'points') {
        segments.removeLast();
      }
      if (segments.isEmpty) continue;

      final equipmentName = segments.last;
      final equipmentPath = '/${segments.join('/')}';

      if (!equipmentMap.containsKey(equipmentPath)) {
        equipmentMap[equipmentPath] = DiscoveredEquipment(
          name: equipmentName,
          path: equipmentPath,
          points: [],
        );
      }

      final pointType = pointTypes[pointPath];
      equipmentMap[equipmentPath]!.points.add(DiscoveredPoint(
        name: pointName,
        path: pointPath,
        type: _extractSimpleType(pointType),
      ));
    }

    final equipment = equipmentMap.values.toList();
    final root = _buildTree(equipment);

    return StationTree(equipment: equipment, root: root);
  }

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

  StationTreeNode _buildTree(List<DiscoveredEquipment> equipment) {
    final root =
        StationTreeNode(name: 'Station', path: '/', children: []);

    final allPaths = <String>{};
    for (final equip in equipment) {
      allPaths.add(equip.path);
      final segments =
          equip.path.split('/').where((s) => s.isNotEmpty).toList();
      var buildPath = '';
      for (final segment in segments) {
        buildPath += '/$segment';
        allPaths.add(buildPath);
      }
    }

    for (final path in allPaths) {
      final parts = path
          .split('/')
          .where((p) => p.isNotEmpty && p != 'points')
          .toList();
      var current = root;

      for (final part in parts) {
        var child = current.children.cast<StationTreeNode?>().firstWhere(
              (c) => c!.name == part,
              orElse: () {
                final newChild =
                    StationTreeNode(name: part, path: '', children: []);
                current.children.add(newChild);
                return newChild;
              },
            )!;
        current = child;
      }
    }

    _markEquipmentNodes(root, '', equipment);
    return root;
  }

  void _markEquipmentNodes(StationTreeNode node, String parentPath,
      List<DiscoveredEquipment> equipment) {
    final currentPath =
        parentPath.isEmpty ? '/${node.name}' : '$parentPath/${node.name}';

    if (node.name == 'Station') {
      node.path = '/';
      for (final child in node.children) {
        _markEquipmentNodes(child, '', equipment);
      }
      return;
    }

    node.path = currentPath;

    final equip = equipment
        .where((e) =>
            e.path == currentPath ||
            e.path.replaceAll('/points', '') == currentPath)
        .firstOrNull;

    if (equip != null) {
      node.isEquipment = true;
      node.pointCount = equip.points.length;
    }

    for (final child in node.children) {
      _markEquipmentNodes(child, currentPath, equipment);
    }

    if (node.isEquipment || node.children.any((c) => c.hasEquipment)) {
      node.hasEquipment = true;
    }
  }

  List<PointValue> _parseSnapshot(String csvContent) {
    final lines =
        csvContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];

    final header = _parseCsvLine(lines[0]);

    final pathIndex = header.indexWhere((col) =>
        col.toLowerCase().contains('slot') ||
        col.toLowerCase().contains('path') ||
        col.toLowerCase().contains('object'));
    final valueIndex =
        header.indexWhere((col) => col.toLowerCase().contains('value'));
    final statusIndex =
        header.indexWhere((col) => col.toLowerCase().contains('status'));

    if (pathIndex == -1) return [];

    final points = <PointValue>[];
    for (int i = 1; i < lines.length; i++) {
      final cols = _parseCsvLine(lines[i]);
      if (cols.length <= pathIndex) continue;

      final path = cols[pathIndex].trim().replaceFirst('slot:', '');
      final name = path.split('/').last;
      final value = valueIndex >= 0 && cols.length > valueIndex
          ? cols[valueIndex].trim()
          : '--';
      final status = statusIndex >= 0 && cols.length > statusIndex
          ? cols[statusIndex].trim()
          : null;

      points.add(PointValue(path: path, name: name, value: value, status: status));
    }

    return points;
  }
}
```

- [ ] **Step 5: Write unit test for NiagaraConnector CSV parsing**

```dart
// server/test/connectors/niagara_connector_test.dart
import 'package:test/test.dart';
import 'package:qr_sidekick_server/connectors/niagara/niagara_connector.dart';
import 'package:qr_sidekick_server/connectors/bas_connector.dart';

void main() {
  late NiagaraConnector connector;

  setUp(() {
    connector = NiagaraConnector();
  });

  test('typeId is niagara', () {
    expect(connector.typeId, equals('niagara'));
  });

  test('displayName is Niagara 4', () {
    expect(connector.displayName, equals('Niagara 4'));
  });

  test('implements BasConnector', () {
    expect(connector, isA<BasConnector>());
  });
}
```

- [ ] **Step 6: Run tests**

Run: `cd server && dart test test/connectors/niagara_connector_test.dart`
Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add server/lib/connectors/ server/test/connectors/
git commit -m "feat: add BAS connector interface with Niagara implementation"
```

---

## Task 4: Admin Authentication

**Files:**
- Create: `server/lib/auth/admin_auth.dart`
- Test: `server/test/auth/admin_auth_test.dart`

- [ ] **Step 1: Write the auth test**

```dart
// server/test/auth/admin_auth_test.dart
import 'package:test/test.dart';
import 'package:drift/native.dart';
import 'package:qr_sidekick_server/auth/admin_auth.dart';
import 'package:qr_sidekick_server/database/database.dart';

void main() {
  late AppDatabase db;
  late AdminAuth auth;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    auth = AdminAuth(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('isSetupComplete returns false initially', () async {
    expect(await auth.isSetupComplete(), isFalse);
  });

  test('setPassword makes setup complete', () async {
    await auth.setPassword('admin123');
    expect(await auth.isSetupComplete(), isTrue);
  });

  test('verifyPassword returns true for correct password', () async {
    await auth.setPassword('admin123');
    expect(await auth.verifyPassword('admin123'), isTrue);
  });

  test('verifyPassword returns false for wrong password', () async {
    await auth.setPassword('admin123');
    expect(await auth.verifyPassword('wrong'), isFalse);
  });

  test('generateToken returns valid token', () async {
    await auth.setPassword('admin123');
    final token = await auth.login('admin123');
    expect(token, isNotNull);
    expect(auth.validateToken(token!), isTrue);
  });

  test('login returns null for wrong password', () async {
    await auth.setPassword('admin123');
    final token = await auth.login('wrong');
    expect(token, isNull);
  });

  test('logout invalidates token', () async {
    await auth.setPassword('admin123');
    final token = await auth.login('admin123');
    expect(auth.validateToken(token!), isTrue);
    auth.logout(token);
    expect(auth.validateToken(token), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && dart test test/auth/admin_auth_test.dart`
Expected: FAIL — `admin_auth.dart` doesn't exist yet.

- [ ] **Step 3: Implement AdminAuth**

```dart
// server/lib/auth/admin_auth.dart
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../database/database.dart';

class AdminAuth {
  final AppDatabase _db;
  final Set<String> _validTokens = {};

  AdminAuth(this._db);

  static const _settingKey = 'admin_password_hash';

  /// Check if admin password has been set (first-run setup)
  Future<bool> isSetupComplete() async {
    final hash = await _db.getSetting(_settingKey);
    return hash != null;
  }

  /// Set the admin password (hashed with SHA-256 + salt)
  Future<void> setPassword(String password) async {
    final salt = _generateSalt();
    final hash = _hashPassword(password, salt);
    await _db.setSetting(_settingKey, '$salt:$hash');
  }

  /// Verify a password against the stored hash
  Future<bool> verifyPassword(String password) async {
    final stored = await _db.getSetting(_settingKey);
    if (stored == null) return false;

    final parts = stored.split(':');
    if (parts.length != 2) return false;

    final salt = parts[0];
    final storedHash = parts[1];
    final hash = _hashPassword(password, salt);

    return hash == storedHash;
  }

  /// Login with password, returns a session token or null
  Future<String?> login(String password) async {
    if (!await verifyPassword(password)) return null;

    final token = _generateToken();
    _validTokens.add(token);
    return token;
  }

  /// Validate a session token
  bool validateToken(String token) => _validTokens.contains(token);

  /// Logout (invalidate token)
  void logout(String token) => _validTokens.remove(token);

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt$password');
    return sha256.convert(bytes).toString();
  }

  String _generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }
}
```

- [ ] **Step 4: Run tests**

Run: `cd server && dart test test/auth/admin_auth_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add server/lib/auth/ server/test/auth/
git commit -m "feat: add admin password auth with session tokens"
```

---

## Task 5: API Routes (Shelf Router)

**Files:**
- Create: `server/lib/routes/router.dart`
- Create: `server/lib/routes/middleware/auth_middleware.dart`
- Create: `server/lib/routes/api/setup_api.dart`
- Create: `server/lib/routes/api/auth_api.dart`
- Create: `server/lib/routes/api/stations_api.dart`
- Create: `server/lib/routes/api/equipment_api.dart`
- Create: `server/lib/routes/api/live_data_api.dart`
- Test: `server/test/routes/stations_api_test.dart`
- Test: `server/test/routes/equipment_api_test.dart`
- Test: `server/test/routes/live_data_api_test.dart`

- [ ] **Step 1: Create auth middleware**

```dart
// server/lib/routes/middleware/auth_middleware.dart
import 'package:shelf/shelf.dart';
import '../../auth/admin_auth.dart';

/// Middleware that requires a valid admin token for requests.
/// Token must be in Authorization header as: Bearer <token>
Middleware adminAuthMiddleware(AdminAuth auth) {
  return (Handler innerHandler) {
    return (Request request) {
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response(401,
            body: '{"error":"Authentication required"}',
            headers: {'content-type': 'application/json'});
      }

      final token = authHeader.substring(7);
      if (!auth.validateToken(token)) {
        return Response(401,
            body: '{"error":"Invalid or expired token"}',
            headers: {'content-type': 'application/json'});
      }

      return innerHandler(request);
    };
  };
}
```

- [ ] **Step 2: Create setup API**

```dart
// server/lib/routes/api/setup_api.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../auth/admin_auth.dart';

class SetupApi {
  final AdminAuth _auth;

  SetupApi(this._auth);

  Router get router {
    final router = Router();

    // GET /api/setup/status — check if setup is complete
    router.get('/status', (Request request) async {
      final complete = await _auth.isSetupComplete();
      return Response.ok(
        jsonEncode({'setupComplete': complete}),
        headers: {'content-type': 'application/json'},
      );
    });

    // POST /api/setup/init — set admin password (only works once)
    router.post('/init', (Request request) async {
      if (await _auth.isSetupComplete()) {
        return Response(409,
            body: jsonEncode({'error': 'Setup already complete'}),
            headers: {'content-type': 'application/json'});
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final password = body['password'] as String?;

      if (password == null || password.length < 4) {
        return Response(400,
            body: jsonEncode({'error': 'Password must be at least 4 characters'}),
            headers: {'content-type': 'application/json'});
      }

      await _auth.setPassword(password);
      final token = await _auth.login(password);

      return Response.ok(
        jsonEncode({'token': token}),
        headers: {'content-type': 'application/json'},
      );
    });

    return router;
  }
}
```

- [ ] **Step 3: Create auth API**

```dart
// server/lib/routes/api/auth_api.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../auth/admin_auth.dart';

class AuthApi {
  final AdminAuth _auth;

  AuthApi(this._auth);

  Router get router {
    final router = Router();

    // POST /api/auth/login
    router.post('/login', (Request request) async {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final password = body['password'] as String?;

      if (password == null) {
        return Response(400,
            body: jsonEncode({'error': 'Password required'}),
            headers: {'content-type': 'application/json'});
      }

      final token = await _auth.login(password);
      if (token == null) {
        return Response(401,
            body: jsonEncode({'error': 'Invalid password'}),
            headers: {'content-type': 'application/json'});
      }

      return Response.ok(
        jsonEncode({'token': token}),
        headers: {'content-type': 'application/json'},
      );
    });

    // POST /api/auth/logout
    router.post('/logout', (Request request) async {
      final authHeader = request.headers['authorization'];
      if (authHeader != null && authHeader.startsWith('Bearer ')) {
        _auth.logout(authHeader.substring(7));
      }
      return Response.ok(
        jsonEncode({'ok': true}),
        headers: {'content-type': 'application/json'},
      );
    });

    return router;
  }
}
```

- [ ] **Step 4: Create stations API**

```dart
// server/lib/routes/api/stations_api.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../database/database.dart';
import '../../connectors/connector_registry.dart';

class StationsApi {
  final AppDatabase _db;
  final ConnectorRegistry _connectors;

  StationsApi(this._db, this._connectors);

  Router get router {
    final router = Router();

    // GET /api/admin/stations
    router.get('/', (Request request) async {
      final stations = await _db.listStations();
      final list = stations
          .map((s) => {
                'id': s.id,
                'name': s.name,
                'host': s.host,
                'port': s.port,
                'protocol': s.protocol,
                'connectorType': s.connectorType,
                'createdAt': s.createdAt.toIso8601String(),
              })
          .toList();
      return Response.ok(jsonEncode(list),
          headers: {'content-type': 'application/json'});
    });

    // GET /api/admin/stations/<id>
    router.get('/<id>', (Request request, String id) async {
      final station = await _db.getStation(int.parse(id));
      if (station == null) {
        return Response(404,
            body: jsonEncode({'error': 'Station not found'}),
            headers: {'content-type': 'application/json'});
      }
      return Response.ok(
          jsonEncode({
            'id': station.id,
            'name': station.name,
            'host': station.host,
            'port': station.port,
            'protocol': station.protocol,
            'connectorType': station.connectorType,
            'createdAt': station.createdAt.toIso8601String(),
          }),
          headers: {'content-type': 'application/json'});
    });

    // POST /api/admin/stations
    router.post('/', (Request request) async {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final id = await _db.createStation(
        name: body['name'] as String,
        host: body['host'] as String,
        port: body['port'] as int? ?? 443,
        protocol: body['protocol'] as String? ?? 'https',
        connectorType: body['connectorType'] as String? ?? 'niagara',
        username: body['username'] as String,
        password: body['password'] as String,
      );
      return Response.ok(jsonEncode({'id': id}),
          headers: {'content-type': 'application/json'});
    });

    // PUT /api/admin/stations/<id>
    router.put('/<id>', (Request request, String id) async {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      await _db.updateStation(
        id: int.parse(id),
        name: body['name'] as String?,
        host: body['host'] as String?,
        port: body['port'] as int?,
        protocol: body['protocol'] as String?,
        connectorType: body['connectorType'] as String?,
        username: body['username'] as String?,
        password: body['password'] as String?,
      );
      return Response.ok(jsonEncode({'ok': true}),
          headers: {'content-type': 'application/json'});
    });

    // DELETE /api/admin/stations/<id>
    router.delete('/<id>', (Request request, String id) async {
      await _db.deleteStation(int.parse(id));
      return Response.ok(jsonEncode({'ok': true}),
          headers: {'content-type': 'application/json'});
    });

    // POST /api/admin/stations/<id>/test — test connection
    router.post('/<id>/test', (Request request, String id) async {
      final station = await _db.getStation(int.parse(id));
      if (station == null) {
        return Response(404,
            body: jsonEncode({'error': 'Station not found'}),
            headers: {'content-type': 'application/json'});
      }

      final connector = _connectors.get(station.connectorType);
      if (connector == null) {
        return Response(400,
            body: jsonEncode({'error': 'Unknown connector type: ${station.connectorType}'}),
            headers: {'content-type': 'application/json'});
      }

      final result = await connector.testConnection(
        host: station.host,
        port: station.port,
        protocol: station.protocol,
        username: station.username,
        password: station.password,
      );

      return Response.ok(
          jsonEncode({
            'success': result.isSuccess,
            'error': result.errorMessage,
          }),
          headers: {'content-type': 'application/json'});
    });

    // GET /api/admin/stations/<id>/tree — browse station tree
    router.get('/<id>/tree', (Request request, String id) async {
      final station = await _db.getStation(int.parse(id));
      if (station == null) {
        return Response(404,
            body: jsonEncode({'error': 'Station not found'}),
            headers: {'content-type': 'application/json'});
      }

      final connector = _connectors.get(station.connectorType);
      if (connector == null) {
        return Response(400,
            body: jsonEncode({'error': 'Unknown connector type'}),
            headers: {'content-type': 'application/json'});
      }

      final result = await connector.fetchStationTree(
        host: station.host,
        port: station.port,
        protocol: station.protocol,
        username: station.username,
        password: station.password,
      );

      if (result is TreeSuccess) {
        return Response.ok(jsonEncode(result.tree.root.toJson()),
            headers: {'content-type': 'application/json'});
      } else {
        final msg = switch (result) {
          TreeAuthFailed(message: final m) => m,
          TreeConnectionFailed(message: final m) => m,
          TreeError(message: final m) => m,
          _ => 'Unknown error',
        };
        return Response(502,
            body: jsonEncode({'error': msg}),
            headers: {'content-type': 'application/json'});
      }
    });

    // GET /api/admin/connectors — list available connector types
    router.get('/connectors', (Request request) async {
      final types = _connectors.all
          .map((c) => {'typeId': c.typeId, 'displayName': c.displayName})
          .toList();
      return Response.ok(jsonEncode(types),
          headers: {'content-type': 'application/json'});
    });

    return router;
  }
}
```

- [ ] **Step 5: Create equipment API**

```dart
// server/lib/routes/api/equipment_api.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../database/database.dart';

class EquipmentApi {
  final AppDatabase _db;

  EquipmentApi(this._db);

  Router get router {
    final router = Router();

    // GET /api/admin/equipment
    router.get('/', (Request request) async {
      final equipment = await _db.listAllEquipment();
      final list = equipment
          .map((e) => {
                'qrId': e.qrId,
                'stationId': e.stationId,
                'equipmentName': e.equipmentName,
                'equipmentPath': e.equipmentPath,
                'location': e.location,
                'pointPaths': jsonDecode(e.pointPaths) as List<dynamic>,
                'createdAt': e.createdAt.toIso8601String(),
              })
          .toList();
      return Response.ok(jsonEncode(list),
          headers: {'content-type': 'application/json'});
    });

    // GET /api/admin/equipment/<qrId>
    router.get('/<qrId>', (Request request, String qrId) async {
      final equip = await _db.getEquipmentByQrId(qrId);
      if (equip == null) {
        return Response(404,
            body: jsonEncode({'error': 'Equipment not found'}),
            headers: {'content-type': 'application/json'});
      }
      return Response.ok(
          jsonEncode({
            'qrId': equip.qrId,
            'stationId': equip.stationId,
            'equipmentName': equip.equipmentName,
            'equipmentPath': equip.equipmentPath,
            'bqlQuery': equip.bqlQuery,
            'location': equip.location,
            'pointPaths': jsonDecode(equip.pointPaths) as List<dynamic>,
            'createdAt': equip.createdAt.toIso8601String(),
          }),
          headers: {'content-type': 'application/json'});
    });

    // POST /api/admin/equipment
    router.post('/', (Request request) async {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final qrId = await _db.createEquipment(
        stationId: body['stationId'] as int,
        equipmentName: body['equipmentName'] as String,
        equipmentPath: body['equipmentPath'] as String,
        bqlQuery: body['bqlQuery'] as String,
        pointPaths: (body['pointPaths'] as List<dynamic>).cast<String>(),
        location: body['location'] as String?,
      );
      return Response.ok(jsonEncode({'qrId': qrId}),
          headers: {'content-type': 'application/json'});
    });

    // PUT /api/admin/equipment/<qrId>
    router.put('/<qrId>', (Request request, String qrId) async {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      await _db.updateEquipment(
        qrId: qrId,
        equipmentName: body['equipmentName'] as String?,
        equipmentPath: body['equipmentPath'] as String?,
        bqlQuery: body['bqlQuery'] as String?,
        pointPaths: (body['pointPaths'] as List<dynamic>?)?.cast<String>(),
        location: body['location'] as String?,
      );
      return Response.ok(jsonEncode({'ok': true}),
          headers: {'content-type': 'application/json'});
    });

    // DELETE /api/admin/equipment/<qrId>
    router.delete('/<qrId>', (Request request, String qrId) async {
      await _db.deleteEquipment(qrId);
      return Response.ok(jsonEncode({'ok': true}),
          headers: {'content-type': 'application/json'});
    });

    // GET /api/admin/equipment/<qrId>/notes
    router.get('/<qrId>/notes', (Request request, String qrId) async {
      final notes = await _db.getNotes(qrId);
      final list = notes
          .map((n) => {
                'id': n.id,
                'content': n.content,
                'createdAt': n.createdAt.toIso8601String(),
              })
          .toList();
      return Response.ok(jsonEncode(list),
          headers: {'content-type': 'application/json'});
    });

    return router;
  }
}
```

- [ ] **Step 6: Create live data API (public, no auth)**

```dart
// server/lib/routes/api/live_data_api.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../database/database.dart';
import '../../connectors/connector_registry.dart';
import '../../connectors/bas_connector.dart';

class LiveDataApi {
  final AppDatabase _db;
  final ConnectorRegistry _connectors;

  LiveDataApi(this._db, this._connectors);

  Router get router {
    final router = Router();

    // GET /api/equipment/<qrId> — public: fetch equipment config + live points
    router.get('/<qrId>', (Request request, String qrId) async {
      final equip = await _db.getEquipmentByQrId(qrId);
      if (equip == null) {
        return Response(404,
            body: jsonEncode({'error': 'Equipment not found'}),
            headers: {'content-type': 'application/json'});
      }

      final station = await _db.getStation(equip.stationId);
      if (station == null) {
        return Response(404,
            body: jsonEncode({'error': 'Station not found'}),
            headers: {'content-type': 'application/json'});
      }

      final connector = _connectors.get(station.connectorType);
      if (connector == null) {
        return Response(500,
            body: jsonEncode({'error': 'Unknown connector type: ${station.connectorType}'}),
            headers: {'content-type': 'application/json'});
      }

      // Fetch live data from BAS station
      final result = await connector.fetchEquipmentSnapshot(
        host: station.host,
        port: station.port,
        protocol: station.protocol,
        username: station.username,
        password: station.password,
        equipmentPath: equip.equipmentPath,
      );

      final pointPaths = jsonDecode(equip.pointPaths) as List<dynamic>;
      List<Map<String, dynamic>> points;

      if (result is SnapshotSuccess) {
        // Filter and order points based on configured pointPaths
        points = pointPaths.map((configuredPath) {
          final match = result.points.firstWhere(
            (p) => p.path == configuredPath || p.path.endsWith(configuredPath as String),
            orElse: () => PointValue(
              path: configuredPath as String,
              name: (configuredPath as String).split('/').last,
              value: '--',
            ),
          );
          return match.toJson();
        }).toList();
      } else {
        // Return placeholder data with error info
        points = pointPaths
            .map((p) => {
                  'path': p,
                  'name': (p as String).split('/').last,
                  'value': '--',
                  'status': 'offline',
                })
            .toList();
      }

      final errorMessage = switch (result) {
        SnapshotAuthFailed(message: final m) => m,
        SnapshotConnectionFailed(message: final m) => m,
        SnapshotError(message: final m) => m,
        _ => null,
      };

      return Response.ok(
          jsonEncode({
            'equipmentName': equip.equipmentName,
            'equipmentPath': equip.equipmentPath,
            'stationName': station.name,
            'location': equip.location,
            'points': points,
            'online': result.isSuccess,
            if (errorMessage != null) 'error': errorMessage,
            'queriedAt': DateTime.now().toIso8601String(),
          }),
          headers: {'content-type': 'application/json'});
    });

    // POST /api/equipment/<qrId>/notes — public: add note (techs can leave notes)
    router.post('/<qrId>/notes', (Request request, String qrId) async {
      final equip = await _db.getEquipmentByQrId(qrId);
      if (equip == null) {
        return Response(404,
            body: jsonEncode({'error': 'Equipment not found'}),
            headers: {'content-type': 'application/json'});
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final content = body['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'Note content required'}),
            headers: {'content-type': 'application/json'});
      }

      final noteId = await _db.addNote(qrId: qrId, content: content.trim());
      return Response.ok(jsonEncode({'id': noteId}),
          headers: {'content-type': 'application/json'});
    });

    // GET /api/equipment/<qrId>/notes — public: get notes
    router.get('/<qrId>/notes', (Request request, String qrId) async {
      final notes = await _db.getNotes(qrId);
      final list = notes
          .map((n) => {
                'id': n.id,
                'content': n.content,
                'createdAt': n.createdAt.toIso8601String(),
              })
          .toList();
      return Response.ok(jsonEncode(list),
          headers: {'content-type': 'application/json'});
    });

    return router;
  }
}
```

- [ ] **Step 7: Create the top-level router assembly**

```dart
// server/lib/routes/router.dart
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import '../auth/admin_auth.dart';
import '../database/database.dart';
import '../connectors/connector_registry.dart';
import 'middleware/auth_middleware.dart';
import 'api/setup_api.dart';
import 'api/auth_api.dart';
import 'api/stations_api.dart';
import 'api/equipment_api.dart';
import 'api/live_data_api.dart';

Handler createHandler({
  required AppDatabase db,
  required AdminAuth auth,
  required ConnectorRegistry connectors,
  required String webDir,
}) {
  final router = Router();

  // Public APIs (no auth)
  router.mount('/api/setup', SetupApi(auth).router.call);
  router.mount('/api/auth', AuthApi(auth).router.call);
  router.mount('/api/equipment', LiveDataApi(db, connectors).router.call);

  // Admin APIs (auth required)
  final adminPipeline = const Pipeline()
      .addMiddleware(adminAuthMiddleware(auth))
      .addHandler(Router()
        ..mount('/stations', StationsApi(db, connectors).router.call)
        ..mount('/equipment', EquipmentApi(db).router.call));

  router.mount('/api/admin/', adminPipeline);

  // Static file serving for web UI
  final staticHandler = createStaticHandler(webDir, defaultDocument: 'index.html');

  // Fallback: serve static files for any non-API route
  router.all('/<path|.*>', (Request request) async {
    final response = await staticHandler(request);
    return response;
  });

  // CORS for local development
  return const Pipeline()
      .addMiddleware(_corsMiddleware())
      .addHandler(router.call);
}

Middleware _corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }
      final response = await innerHandler(request);
      return response.change(headers: _corsHeaders);
    };
  };
}

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};
```

- [ ] **Step 8: Write integration test for stations API**

```dart
// server/test/routes/stations_api_test.dart
import 'dart:convert';
import 'package:drift/native.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:qr_sidekick_server/auth/admin_auth.dart';
import 'package:qr_sidekick_server/database/database.dart';
import 'package:qr_sidekick_server/connectors/connector_registry.dart';
import 'package:qr_sidekick_server/connectors/niagara/niagara_connector.dart';
import 'package:qr_sidekick_server/routes/router.dart' as app_router;

void main() {
  late AppDatabase db;
  late AdminAuth auth;
  late Handler handler;
  late String token;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    auth = AdminAuth(db);
    final connectors = ConnectorRegistry()..register(NiagaraConnector());

    handler = app_router.createHandler(
      db: db,
      auth: auth,
      connectors: connectors,
      webDir: '.', // Not used in tests
    );

    // Setup admin and get token
    await auth.setPassword('test123');
    token = (await auth.login('test123'))!;
  });

  tearDown(() async {
    await db.close();
  });

  test('POST /api/admin/stations creates station', () async {
    final response = await handler(Request(
      'POST',
      Uri.parse('http://localhost/api/admin/stations'),
      headers: {
        'authorization': 'Bearer $token',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'name': 'Test JACE',
        'host': '192.168.1.100',
        'port': 443,
        'protocol': 'https',
        'connectorType': 'niagara',
        'username': 'admin',
        'password': 'pass',
      }),
    ));

    expect(response.statusCode, equals(200));
    final body = jsonDecode(await response.readAsString());
    expect(body['id'], isNotNull);
  });

  test('GET /api/admin/stations lists stations', () async {
    await db.createStation(
      name: 'S1', host: '10.0.0.1', port: 443,
      protocol: 'https', connectorType: 'niagara',
      username: 'u', password: 'p',
    );

    final response = await handler(Request(
      'GET',
      Uri.parse('http://localhost/api/admin/stations'),
      headers: {'authorization': 'Bearer $token'},
    ));

    expect(response.statusCode, equals(200));
    final body = jsonDecode(await response.readAsString()) as List;
    expect(body, hasLength(1));
    expect(body[0]['name'], equals('S1'));
    // Verify credentials are NOT in the response
    expect(body[0].containsKey('username'), isFalse);
  });

  test('returns 401 without auth token', () async {
    final response = await handler(Request(
      'GET',
      Uri.parse('http://localhost/api/admin/stations'),
    ));

    expect(response.statusCode, equals(401));
  });
}
```

- [ ] **Step 9: Run tests**

Run: `cd server && dart test test/routes/`
Expected: All tests PASS.

- [ ] **Step 10: Commit**

```bash
git add server/lib/routes/ server/test/routes/
git commit -m "feat: add shelf API routes for setup, auth, stations, equipment, live data"
```

---

## Task 6: Wire Up Server Entry Point

**Files:**
- Modify: `server/bin/main.dart`

- [ ] **Step 1: Update bin/main.dart to start the full server**

```dart
// server/bin/main.dart
import 'dart:io';
import 'package:args/args.dart';
import 'package:drift/native.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:qr_sidekick_server/config.dart';
import 'package:qr_sidekick_server/database/database.dart';
import 'package:qr_sidekick_server/auth/admin_auth.dart';
import 'package:qr_sidekick_server/connectors/connector_registry.dart';
import 'package:qr_sidekick_server/connectors/niagara/niagara_connector.dart';
import 'package:qr_sidekick_server/routes/router.dart' as app_router;

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('port', abbr: 'p', defaultsTo: '8080', help: 'Port to listen on')
    ..addOption('data-dir', help: 'Directory for database and config')
    ..addFlag('help', abbr: 'h', negatable: false);

  final results = parser.parse(args);

  if (results['help'] as bool) {
    print('QR Sidekick Server');
    print(parser.usage);
    exit(0);
  }

  final config = ServerConfig(
    port: int.parse(results['port'] as String),
    dataDir: results['data-dir'] as String?,
  );

  // Ensure data directory exists
  await Directory(config.dataDir).create(recursive: true);

  // Initialize database
  final db = AppDatabase(NativeDatabase(File(config.databasePath)));
  final auth = AdminAuth(db);

  // Register BAS connectors
  final connectors = ConnectorRegistry()
    ..register(NiagaraConnector());

  // Create handler
  final handler = app_router.createHandler(
    db: db,
    auth: auth,
    connectors: connectors,
    webDir: config.webDir,
  );

  // Start server
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, config.port);
  final setupDone = await auth.isSetupComplete();

  print('');
  print('  QR Sidekick Server running');
  print('  ─────────────────────────');
  print('  Local:   http://localhost:${server.port}');
  print('  Network: http://${_getLocalIp()}:${server.port}');
  print('  Data:    ${config.dataDir}');
  print('');

  if (!setupDone) {
    print('  >> First run: open the URL above to set your admin password.');
  } else {
    print('  >> Admin: http://localhost:${server.port}/admin/');
  }
  print('');
}

String _getLocalIp() {
  try {
    final interfaces = NetworkInterface.list(type: InternetAddressType.IPv4);
    // This is synchronous in practice for most platforms
    return 'your-ip';
  } catch (_) {
    return 'your-ip';
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd server && dart analyze`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add server/bin/main.dart
git commit -m "feat: wire up server entry point with database, connectors, and routes"
```

---

## Task 7: Tech Web Frontend (Equipment View)

**Files:**
- Create: `server/web/css/style.css`
- Create: `server/web/equipment.html`
- Create: `server/web/js/equipment.js`
- Create: `server/web/index.html`

- [ ] **Step 1: Create CSS theme (matching existing app colors)**

```css
/* server/web/css/style.css */
:root {
  --primary: #F5A623;
  --background: #0A0A0A;
  --surface: #141414;
  --surface-hover: #1E1E1E;
  --border: #2A2A2A;
  --text-primary: #E8E8E8;
  --text-secondary: #999999;
  --text-tertiary: #666666;
  --success: #34C759;
  --error: #FF3B30;
  --warning: #FFD60A;

  /* Niagara status colors */
  --niagara-alarm: #CF1624;
  --niagara-fault: #FC7734;
  --niagara-down: #FAC600;
  --niagara-stale: #D9C09D;
  --niagara-overridden: #BFADDD;
  --niagara-disabled: #D6D6D6;
}

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  background: var(--background);
  color: var(--text-primary);
  min-height: 100vh;
}

.mono {
  font-family: 'JetBrains Mono', 'SF Mono', 'Fira Code', monospace;
}

.container {
  max-width: 600px;
  margin: 0 auto;
  padding: 16px;
}

/* Cards */
.card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 16px;
  margin-bottom: 12px;
}

/* Status badges */
.badge {
  display: inline-block;
  padding: 2px 8px;
  border: 1px solid;
  font-family: 'JetBrains Mono', monospace;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.5px;
}

.badge-online { color: var(--success); border-color: var(--success); background: rgba(52,199,89,0.1); }
.badge-offline { color: var(--error); border-color: var(--error); background: rgba(255,59,48,0.1); }

/* Points list */
.point-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 16px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  margin-bottom: 8px;
}

.point-name {
  font-size: 14px;
  color: var(--text-secondary);
}

.point-value {
  font-family: 'JetBrains Mono', monospace;
  font-size: 16px;
  font-weight: 600;
  text-align: right;
}

.point-status {
  font-size: 10px;
  margin-top: 2px;
  text-align: right;
}

/* Section headers */
.section-header {
  font-family: 'JetBrains Mono', monospace;
  font-size: 14px;
  font-weight: 500;
  color: var(--text-secondary);
  letter-spacing: 1px;
  padding: 8px 4px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

/* Notes */
.note-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 10px 12px;
  margin-bottom: 6px;
}

.note-date {
  font-family: 'JetBrains Mono', monospace;
  font-size: 11px;
  font-weight: 600;
  color: var(--primary);
}

.note-content {
  font-size: 13px;
  margin-top: 4px;
  color: var(--text-primary);
}

/* Buttons */
.btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  border: none;
  border-radius: 6px;
  font-size: 14px;
  cursor: pointer;
  transition: opacity 0.2s;
}

.btn:hover { opacity: 0.85; }
.btn-primary { background: var(--primary); color: #000; font-weight: 600; }
.btn-outline { background: transparent; border: 1px solid var(--border); color: var(--text-secondary); }

/* Loading */
.loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 60vh;
  gap: 16px;
  color: var(--text-secondary);
}

.spinner {
  width: 32px;
  height: 32px;
  border: 3px solid var(--border);
  border-top-color: var(--primary);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin { to { transform: rotate(360deg); } }

/* Error state */
.error-state {
  text-align: center;
  padding: 48px 24px;
}

.error-state h2 { color: var(--error); margin-bottom: 8px; }

/* Textarea */
textarea, input[type="text"], input[type="password"] {
  width: 100%;
  padding: 10px 12px;
  background: var(--background);
  border: 1px solid var(--border);
  border-radius: 6px;
  color: var(--text-primary);
  font-size: 14px;
  font-family: inherit;
}

textarea:focus, input:focus {
  outline: none;
  border-color: var(--primary);
}

/* Responsive */
@media (max-width: 480px) {
  .container { padding: 12px; }
}

/* PWA install prompt */
.install-banner {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  background: var(--surface);
  border-top: 1px solid var(--border);
  padding: 12px 16px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  z-index: 100;
}
```

- [ ] **Step 2: Create equipment.html (tech view)**

```html
<!-- server/web/equipment.html -->
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="theme-color" content="#0A0A0A">
  <title>Equipment - QR Sidekick</title>
  <link rel="stylesheet" href="/css/style.css">
</head>
<body>
  <div class="container" id="app">
    <div class="loading" id="loading">
      <div class="spinner"></div>
      <span class="mono">Loading equipment data...</span>
    </div>

    <div id="error" style="display:none" class="error-state">
      <h2 class="mono">[ ERROR ]</h2>
      <p id="error-msg" style="color:var(--text-secondary);margin-top:8px"></p>
      <button class="btn btn-primary" style="margin-top:24px" onclick="loadData()">Retry</button>
    </div>

    <div id="content" style="display:none">
      <!-- Header card -->
      <div class="card" style="margin-top:8px">
        <div style="display:flex;align-items:flex-start;gap:12px">
          <div style="padding:10px;background:rgba(245,166,35,0.1);border-radius:8px">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#F5A623" stroke-width="2"><path d="M9 3H5a2 2 0 0 0-2 2v4m6-6h10a2 2 0 0 1 2 2v4M9 3v18m0 0h10a2 2 0 0 0 2-2V9M9 21H5a2 2 0 0 1-2-2V9m0 0h18"/></svg>
          </div>
          <div style="flex:1">
            <h1 id="equip-name" class="mono" style="font-size:18px;font-weight:600"></h1>
            <p id="station-name" style="color:var(--text-secondary);font-size:13px"></p>
          </div>
          <span id="status-badge" class="badge"></span>
        </div>
        <p id="location" style="display:none;margin-top:12px;font-size:13px;color:var(--text-secondary)"></p>
        <p id="equip-path" class="mono" style="margin-top:8px;font-size:11px;color:var(--text-tertiary)"></p>
      </div>

      <!-- Notes section -->
      <div class="section-header">
        <span>[ NOTES ]</span>
        <button class="btn btn-outline" style="padding:4px 8px;font-size:12px" onclick="toggleNoteForm()">+ Add</button>
      </div>

      <div id="note-form" style="display:none" class="card">
        <textarea id="note-input" rows="3" placeholder="Write a note..."></textarea>
        <div style="display:flex;justify-content:flex-end;gap:8px;margin-top:8px">
          <button class="btn btn-outline" onclick="toggleNoteForm()">Cancel</button>
          <button class="btn btn-primary" onclick="submitNote()">Add</button>
        </div>
      </div>

      <div id="notes-list"></div>

      <!-- Points section -->
      <div class="section-header" style="margin-top:16px">
        <span>[ POINTS ]</span>
        <span id="point-count" class="mono" style="font-size:12px;color:var(--text-tertiary)"></span>
      </div>

      <div id="points-list"></div>

      <!-- Footer -->
      <p id="last-update" class="mono" style="text-align:center;font-size:11px;color:var(--text-tertiary);margin-top:24px"></p>
      <p id="qr-id" class="mono" style="text-align:center;font-size:10px;color:var(--text-tertiary);margin-top:8px;margin-bottom:24px"></p>

      <!-- Refresh button -->
      <div style="text-align:center;margin-bottom:32px">
        <button class="btn btn-outline" onclick="loadData()">Refresh</button>
      </div>
    </div>
  </div>

  <script src="/js/equipment.js"></script>
</body>
</html>
```

- [ ] **Step 3: Create equipment.js**

```javascript
// server/web/js/equipment.js
const qrId = new URLSearchParams(window.location.search).get('id');

if (!qrId) {
  showError('No equipment ID provided.');
}

function showError(msg) {
  document.getElementById('loading').style.display = 'none';
  document.getElementById('content').style.display = 'none';
  document.getElementById('error').style.display = 'block';
  document.getElementById('error-msg').textContent = msg;
}

function getStatusColor(status) {
  if (!status) return null;
  const s = status.toLowerCase();
  if (s.includes('alarm')) return 'var(--niagara-alarm)';
  if (s.includes('fault')) return 'var(--niagara-fault)';
  if (s.includes('down')) return 'var(--niagara-down)';
  if (s.includes('stale')) return 'var(--niagara-stale)';
  if (s.includes('overridden')) return 'var(--niagara-overridden)';
  if (s.includes('disabled')) return 'var(--niagara-disabled)';
  return null;
}

function formatTime(iso) {
  const d = new Date(iso);
  const now = new Date();
  const diff = Math.floor((now - d) / 1000);
  if (diff < 5) return 'just now';
  if (diff < 60) return diff + 's ago';
  if (diff < 3600) return Math.floor(diff / 60) + 'm ago';
  return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

async function loadData() {
  document.getElementById('loading').style.display = 'flex';
  document.getElementById('content').style.display = 'none';
  document.getElementById('error').style.display = 'none';

  try {
    const res = await fetch('/api/equipment/' + qrId);
    if (res.status === 404) {
      showError('Equipment not found. This QR code is not registered.');
      return;
    }
    if (!res.ok) throw new Error('Server error: ' + res.status);

    const data = await res.json();

    // Header
    document.getElementById('equip-name').textContent = data.equipmentName;
    document.getElementById('station-name').textContent = data.stationName;
    document.getElementById('equip-path').textContent = data.equipmentPath;
    document.getElementById('qr-id').textContent = 'QR: ' + qrId;

    if (data.location) {
      const loc = document.getElementById('location');
      loc.style.display = 'block';
      loc.textContent = data.location;
    }

    // Status badge
    const badge = document.getElementById('status-badge');
    if (data.online) {
      badge.className = 'badge badge-online';
      badge.textContent = 'ONLINE';
    } else {
      badge.className = 'badge badge-offline';
      badge.textContent = 'OFFLINE';
    }

    // Points
    const pointsList = document.getElementById('points-list');
    pointsList.innerHTML = '';
    document.getElementById('point-count').textContent = data.points.length + ' configured';

    for (const point of data.points) {
      const statusColor = getStatusColor(point.status);
      const rawStatus = (point.status || '').toLowerCase();
      const isOk = rawStatus.includes('ok') || rawStatus === '';
      const statusText = isOk ? '' : (point.status || '').replace(/[{}]/g, '');

      const row = document.createElement('div');
      row.className = 'point-row';
      row.innerHTML = `
        <span class="point-name">${point.name}</span>
        <div>
          <div class="point-value" ${statusColor && !isOk ? `style="color:${statusColor}"` : ''}>${point.value}</div>
          ${statusText ? `<div class="point-status" style="color:${statusColor}">${statusText}</div>` : ''}
        </div>
      `;
      pointsList.appendChild(row);
    }

    // Last update
    document.getElementById('last-update').textContent = 'Last updated: ' + formatTime(data.queriedAt);

    // Load notes
    await loadNotes();

    document.getElementById('loading').style.display = 'none';
    document.getElementById('content').style.display = 'block';
  } catch (e) {
    showError(e.message || 'Failed to load equipment data');
  }
}

async function loadNotes() {
  try {
    const res = await fetch('/api/equipment/' + qrId + '/notes');
    if (!res.ok) return;
    const notes = await res.json();

    const list = document.getElementById('notes-list');
    list.innerHTML = '';

    if (notes.length === 0) {
      list.innerHTML = '<div class="card" style="text-align:center;color:var(--text-secondary);padding:24px">No notes yet</div>';
      return;
    }

    for (const note of notes) {
      const card = document.createElement('div');
      card.className = 'note-card';
      card.innerHTML = `
        <div class="note-date">${new Date(note.createdAt).toLocaleDateString([], { month: 'short', day: 'numeric' })} @ ${new Date(note.createdAt).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })}</div>
        <div class="note-content">${note.content}</div>
      `;
      list.appendChild(card);
    }
  } catch (_) {}
}

function toggleNoteForm() {
  const form = document.getElementById('note-form');
  form.style.display = form.style.display === 'none' ? 'block' : 'none';
  if (form.style.display === 'block') {
    document.getElementById('note-input').focus();
  }
}

async function submitNote() {
  const input = document.getElementById('note-input');
  const content = input.value.trim();
  if (!content) return;

  try {
    await fetch('/api/equipment/' + qrId + '/notes', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ content }),
    });
    input.value = '';
    toggleNoteForm();
    await loadNotes();
  } catch (_) {}
}

// Auto-refresh every 30 seconds
if (qrId) {
  loadData();
  setInterval(loadData, 30000);
}
```

- [ ] **Step 4: Create index.html (landing page)**

```html
<!-- server/web/index.html -->
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="theme-color" content="#0A0A0A">
  <title>QR Sidekick</title>
  <link rel="stylesheet" href="/css/style.css">
</head>
<body>
  <div class="container" style="display:flex;flex-direction:column;align-items:center;justify-content:center;min-height:100vh;text-align:center">
    <h1 class="mono" style="font-size:24px;color:var(--primary);margin-bottom:8px">QR Sidekick</h1>
    <p style="color:var(--text-secondary);margin-bottom:32px">Scan a QR code on equipment to view live data.</p>
    <a href="/admin/" class="btn btn-outline">Admin Dashboard</a>
  </div>
</body>
</html>
```

- [ ] **Step 5: Commit**

```bash
git add server/web/
git commit -m "feat: add tech-facing equipment web view with dark theme"
```

---

## Task 8: Admin Web Frontend

**Files:**
- Create: `server/web/admin/index.html`
- Create: `server/web/admin/login.html`
- Create: `server/web/admin/setup.html`
- Create: `server/web/admin/stations.html`
- Create: `server/web/admin/station-form.html`
- Create: `server/web/admin/equipment-list.html`
- Create: `server/web/admin/equipment-form.html`
- Create: `server/web/admin/qr-view.html`
- Create: `server/web/js/admin.js`
- Create: `server/web/js/tree-browser.js`

This is the largest task. The admin frontend is a set of HTML pages that call the admin API with Bearer token auth. Since these are plain HTML pages, they share `admin.js` for auth state and API helpers.

- [ ] **Step 1: Create admin.js (shared admin utilities)**

```javascript
// server/web/js/admin.js
const API = {
  token: localStorage.getItem('admin_token'),

  async fetch(path, options = {}) {
    const headers = { 'Content-Type': 'application/json', ...options.headers };
    if (this.token) headers['Authorization'] = 'Bearer ' + this.token;

    const res = await fetch(path, { ...options, headers });

    if (res.status === 401) {
      this.token = null;
      localStorage.removeItem('admin_token');
      window.location.href = '/admin/login.html';
      return;
    }

    return res;
  },

  async get(path) { return this.fetch(path); },

  async post(path, body) {
    return this.fetch(path, { method: 'POST', body: JSON.stringify(body) });
  },

  async put(path, body) {
    return this.fetch(path, { method: 'PUT', body: JSON.stringify(body) });
  },

  async del(path) {
    return this.fetch(path, { method: 'DELETE' });
  },

  login(token) {
    this.token = token;
    localStorage.setItem('admin_token', token);
  },

  logout() {
    this.post('/api/auth/logout');
    this.token = null;
    localStorage.removeItem('admin_token');
    window.location.href = '/admin/login.html';
  },

  requireAuth() {
    if (!this.token) window.location.href = '/admin/login.html';
  },
};

// Check setup status on admin pages
async function checkSetup() {
  const res = await fetch('/api/setup/status');
  const data = await res.json();
  if (!data.setupComplete && !window.location.pathname.includes('setup')) {
    window.location.href = '/admin/setup.html';
  }
}
```

- [ ] **Step 2: Create setup.html**

```html
<!-- server/web/admin/setup.html -->
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Setup - QR Sidekick</title>
  <link rel="stylesheet" href="/css/style.css">
</head>
<body>
  <div class="container" style="max-width:400px;margin-top:15vh">
    <h1 class="mono" style="text-align:center;color:var(--primary);margin-bottom:8px">QR Sidekick</h1>
    <p style="text-align:center;color:var(--text-secondary);margin-bottom:32px">Set an admin password to get started.</p>

    <div class="card">
      <label style="display:block;margin-bottom:8px;color:var(--text-secondary);font-size:13px">Admin Password</label>
      <input type="password" id="password" placeholder="Choose a password" autofocus>
      <div style="height:12px"></div>
      <label style="display:block;margin-bottom:8px;color:var(--text-secondary);font-size:13px">Confirm Password</label>
      <input type="password" id="confirm" placeholder="Confirm password">
      <p id="error" style="display:none;color:var(--error);font-size:13px;margin-top:12px"></p>
      <button class="btn btn-primary" style="width:100%;margin-top:16px;justify-content:center" onclick="setup()">Set Password & Continue</button>
    </div>
  </div>

  <script>
    async function setup() {
      const password = document.getElementById('password').value;
      const confirm = document.getElementById('confirm').value;
      const errorEl = document.getElementById('error');

      if (password.length < 4) {
        errorEl.textContent = 'Password must be at least 4 characters';
        errorEl.style.display = 'block';
        return;
      }
      if (password !== confirm) {
        errorEl.textContent = 'Passwords do not match';
        errorEl.style.display = 'block';
        return;
      }

      const res = await fetch('/api/setup/init', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ password }),
      });

      if (res.ok) {
        const data = await res.json();
        localStorage.setItem('admin_token', data.token);
        window.location.href = '/admin/';
      } else {
        const data = await res.json();
        errorEl.textContent = data.error || 'Setup failed';
        errorEl.style.display = 'block';
      }
    }

    // Enter key submits
    document.getElementById('confirm').addEventListener('keydown', e => {
      if (e.key === 'Enter') setup();
    });
  </script>
</body>
</html>
```

- [ ] **Step 3: Create login.html**

```html
<!-- server/web/admin/login.html -->
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Login - QR Sidekick</title>
  <link rel="stylesheet" href="/css/style.css">
</head>
<body>
  <div class="container" style="max-width:400px;margin-top:20vh">
    <h1 class="mono" style="text-align:center;color:var(--primary);margin-bottom:32px">QR Sidekick</h1>

    <div class="card">
      <label style="display:block;margin-bottom:8px;color:var(--text-secondary);font-size:13px">Admin Password</label>
      <input type="password" id="password" placeholder="Enter admin password" autofocus>
      <p id="error" style="display:none;color:var(--error);font-size:13px;margin-top:12px"></p>
      <button class="btn btn-primary" style="width:100%;margin-top:16px;justify-content:center" onclick="login()">Login</button>
    </div>
  </div>

  <script>
    async function login() {
      const password = document.getElementById('password').value;
      const errorEl = document.getElementById('error');

      const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ password }),
      });

      if (res.ok) {
        const data = await res.json();
        localStorage.setItem('admin_token', data.token);
        window.location.href = '/admin/';
      } else {
        errorEl.textContent = 'Invalid password';
        errorEl.style.display = 'block';
      }
    }

    document.getElementById('password').addEventListener('keydown', e => {
      if (e.key === 'Enter') login();
    });

    // Redirect if already logged in
    (async () => {
      const res = await fetch('/api/setup/status');
      const data = await res.json();
      if (!data.setupComplete) {
        window.location.href = '/admin/setup.html';
      }
    })();
  </script>
</body>
</html>
```

- [ ] **Step 4: Create admin/index.html (dashboard)**

```html
<!-- server/web/admin/index.html -->
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Admin - QR Sidekick</title>
  <link rel="stylesheet" href="/css/style.css">
</head>
<body>
  <div class="container">
    <div style="display:flex;justify-content:space-between;align-items:center;margin:16px 0">
      <h1 class="mono" style="font-size:20px;color:var(--primary)">QR Sidekick</h1>
      <button class="btn btn-outline" style="font-size:12px" onclick="API.logout()">Logout</button>
    </div>

    <div class="section-header">[ MANAGEMENT ]</div>

    <a href="/admin/stations.html" class="card" style="display:flex;align-items:center;gap:12px;text-decoration:none;color:inherit;cursor:pointer">
      <div style="padding:10px;background:rgba(245,166,35,0.1);border-radius:8px">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#F5A623" stroke-width="2"><rect x="2" y="3" width="20" height="14" rx="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>
      </div>
      <div>
        <div style="font-weight:600">Stations</div>
        <div style="font-size:13px;color:var(--text-secondary)">Manage BAS station connections</div>
      </div>
    </a>

    <a href="/admin/equipment-list.html" class="card" style="display:flex;align-items:center;gap:12px;text-decoration:none;color:inherit;cursor:pointer">
      <div style="padding:10px;background:rgba(245,166,35,0.1);border-radius:8px">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#F5A623" stroke-width="2"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></svg>
      </div>
      <div>
        <div style="font-weight:600">Equipment & QR Codes</div>
        <div style="font-size:13px;color:var(--text-secondary)">Configure equipment and generate QR codes</div>
      </div>
    </a>
  </div>

  <script src="/js/admin.js"></script>
  <script>checkSetup(); API.requireAuth();</script>
</body>
</html>
```

- [ ] **Step 5: Create stations.html, station-form.html, equipment-list.html, equipment-form.html, qr-view.html**

These follow the same pattern — HTML page that calls `admin.js` API helpers. The station and equipment forms mirror the existing Flutter form fields. The QR view page generates a QR code using the `qr` library server-side (via a new API endpoint `/api/admin/equipment/<qrId>/qr.png`).

Due to the size, implement these as straightforward CRUD pages that:
- `stations.html`: Lists stations with add/edit/delete, test connection button
- `station-form.html`: Form with name, host, port, protocol, connector type dropdown, username, password, test connection
- `equipment-list.html`: Lists equipment grouped by station, with add/edit/delete
- `equipment-form.html`: Station selector, browse equipment button (opens tree-browser), name, path, BQL query, point paths
- `qr-view.html`: Shows generated QR code image with equipment name, print button

Each page is standalone HTML loading `/js/admin.js` and calling the appropriate API endpoints documented in Task 5.

- [ ] **Step 6: Create tree-browser.js**

```javascript
// server/web/js/tree-browser.js
// Opens a modal tree browser for selecting equipment from a station

function openTreeBrowser(stationId, onSelect) {
  const overlay = document.createElement('div');
  overlay.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,0.7);z-index:1000;display:flex;align-items:center;justify-content:center';

  const modal = document.createElement('div');
  modal.style.cssText = 'background:var(--surface);border:1px solid var(--border);border-radius:12px;width:90%;max-width:500px;max-height:80vh;overflow-y:auto;padding:16px';
  modal.innerHTML = `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px">
      <h2 class="mono" style="font-size:16px">[ BROWSE EQUIPMENT ]</h2>
      <button class="btn btn-outline" style="padding:4px 8px" onclick="this.closest('[style*=fixed]').remove()">Close</button>
    </div>
    <div id="tree-loading" class="loading" style="min-height:200px"><div class="spinner"></div><span>Loading station tree...</span></div>
    <div id="tree-content" style="display:none"></div>
  `;

  overlay.appendChild(modal);
  overlay.addEventListener('click', e => { if (e.target === overlay) overlay.remove(); });
  document.body.appendChild(overlay);

  // Fetch tree
  API.get('/api/admin/stations/' + stationId + '/tree').then(async res => {
    if (!res || !res.ok) {
      modal.querySelector('#tree-loading').innerHTML = '<p style="color:var(--error)">Failed to load station tree</p>';
      return;
    }
    const tree = await res.json();
    modal.querySelector('#tree-loading').style.display = 'none';
    modal.querySelector('#tree-content').style.display = 'block';
    renderTree(modal.querySelector('#tree-content'), tree, onSelect, overlay);
  });
}

function renderTree(container, node, onSelect, overlay) {
  if (!node.children || node.children.length === 0) return;

  for (const child of node.children) {
    if (!child.hasEquipment && !child.isEquipment) continue;

    const item = document.createElement('div');
    item.style.cssText = 'padding:8px 12px;margin:4px 0;border-radius:6px;cursor:pointer';

    if (child.isEquipment) {
      item.style.background = 'rgba(245,166,35,0.1)';
      item.style.border = '1px solid rgba(245,166,35,0.3)';
      item.innerHTML = `
        <div style="font-weight:500">${child.name}</div>
        <div style="font-size:11px;color:var(--text-tertiary)" class="mono">${child.path}</div>
        <div style="font-size:11px;color:var(--text-secondary);margin-top:2px">${child.pointCount} points</div>
      `;
      item.onclick = () => {
        onSelect({ name: child.name, path: child.path, pointCount: child.pointCount });
        overlay.remove();
      };
    } else {
      item.innerHTML = `<div style="color:var(--text-secondary)">${child.name}</div>`;
      const childContainer = document.createElement('div');
      childContainer.style.cssText = 'padding-left:16px;display:none';
      item.onclick = (e) => {
        e.stopPropagation();
        childContainer.style.display = childContainer.style.display === 'none' ? 'block' : 'none';
      };
      renderTree(childContainer, child, onSelect, overlay);
      container.appendChild(item);
      container.appendChild(childContainer);
      continue;
    }

    container.appendChild(item);
  }
}
```

- [ ] **Step 7: Commit**

```bash
git add server/web/admin/ server/web/js/admin.js server/web/js/tree-browser.js
git commit -m "feat: add admin web UI with setup, login, stations, equipment management"
```

---

## Task 9: QR Code Generation Service

**Files:**
- Create: `server/lib/services/qr_service.dart`
- Modify: `server/lib/routes/api/equipment_api.dart` (add QR image endpoint)

- [ ] **Step 1: Create QR service**

```dart
// server/lib/services/qr_service.dart
import 'dart:typed_data';
import 'package:qr/qr.dart';
import 'package:image/image.dart' as img;

class QrService {
  /// Generate a QR code PNG image for a URL
  Uint8List generateQrPng({
    required String data,
    int moduleSize = 10,
    int quietZone = 4,
  }) {
    final qr = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final moduleCount = qr.moduleCount;
    final imageSize = (moduleCount + quietZone * 2) * moduleSize;

    final image = img.Image(width: imageSize, height: imageSize);
    // Fill white background
    img.fill(image, color: img.ColorUint8.rgb(255, 255, 255));

    // Draw QR modules
    for (int x = 0; x < moduleCount; x++) {
      for (int y = 0; y < moduleCount; y++) {
        if (qr.isDark(y, x)) {
          final px = (x + quietZone) * moduleSize;
          final py = (y + quietZone) * moduleSize;
          img.fillRect(
            image,
            x1: px,
            y1: py,
            x2: px + moduleSize,
            y2: py + moduleSize,
            color: img.ColorUint8.rgb(0, 0, 0),
          );
        }
      }
    }

    return Uint8List.fromList(img.encodePng(image));
  }
}
```

- [ ] **Step 2: Add QR image endpoint to equipment API**

Add to `EquipmentApi.router`:

```dart
// GET /api/admin/equipment/<qrId>/qr.png
router.get('/<qrId>/qr.png', (Request request, String qrId) async {
  final equip = await _db.getEquipmentByQrId(qrId);
  if (equip == null) {
    return Response(404, body: 'Equipment not found');
  }

  // Build the tech-facing URL
  final host = request.requestedUri.host;
  final port = request.requestedUri.port;
  final scheme = request.requestedUri.scheme;
  final equipmentUrl = '$scheme://$host:$port/equipment.html?id=$qrId';

  final qrService = QrService();
  final pngBytes = qrService.generateQrPng(data: equipmentUrl);

  return Response.ok(pngBytes, headers: {
    'content-type': 'image/png',
    'cache-control': 'no-cache',
  });
});
```

- [ ] **Step 3: Commit**

```bash
git add server/lib/services/qr_service.dart server/lib/routes/api/equipment_api.dart
git commit -m "feat: add QR code PNG generation for equipment URLs"
```

---

## Task 10: Server Packaging and README

**Files:**
- Create: `server/README.md`
- Modify: `server/bin/main.dart` (fix local IP detection)

- [ ] **Step 1: Fix local IP detection to be async**

In `bin/main.dart`, replace `_getLocalIp()` with:

```dart
Future<String> _getLocalIp() async {
  try {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }
  } catch (_) {}
  return 'localhost';
}
```

And update the call site to `await _getLocalIp()`.

- [ ] **Step 2: Verify the full server compiles and runs**

Run: `cd server && dart analyze && dart run bin/main.dart --help`
Expected: No errors, help text printed.

- [ ] **Step 3: Create README.md**

```markdown
# QR Sidekick Server

Self-hosted companion server for QR Sidekick. Runs on your local network — technicians scan QR codes on equipment and see live BAS data in their browser. No app install, no cloud, no accounts.

## Quick Start

1. Download the server for your OS from Releases
2. Run it: `./qr-sidekick-server`
3. Open `http://localhost:8080` in your browser
4. Set an admin password
5. Add your BAS stations and configure equipment
6. Print QR codes and stick them on equipment
7. Technicians scan → see live data

## Building from Source

```bash
cd server
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart run bin/main.dart
```

## Compiling to Executable

```bash
dart compile exe bin/main.dart -o qr-sidekick-server
```

## CLI Options

| Flag | Default | Description |
|------|---------|-------------|
| `--port`, `-p` | 8080 | Port to listen on |
| `--data-dir` | `~/.qr-sidekick` | Directory for database |

## Supported BAS Systems

- **Niagara 4** — full support (station tree browsing, live point values, status colors)
- More connectors planned — the architecture supports adding new BAS protocols
```

- [ ] **Step 4: Commit**

```bash
git add server/bin/main.dart server/README.md
git commit -m "feat: finalize server packaging with README and local IP detection"
```

---

## Summary

| Task | What it builds | Dependencies |
|------|---------------|-------------|
| 1 | Project scaffold, pubspec, config | None |
| 2 | SQLite database (drift) | Task 1 |
| 3 | BAS connector interface + Niagara impl | Task 1 |
| 4 | Admin auth (password + tokens) | Task 2 |
| 5 | All API routes (shelf) | Tasks 2, 3, 4 |
| 6 | Server entry point wiring | Task 5 |
| 7 | Tech web frontend (equipment view) | Task 5 |
| 8 | Admin web frontend | Task 5 |
| 9 | QR code generation | Task 5 |
| 10 | Packaging + README | All |
