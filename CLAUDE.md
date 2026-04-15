# QR Sidekick - Project Instructions

## Project Overview
QR Sidekick is a Flutter app for HVAC technicians to scan QR codes on Building Automation System (BAS) equipment and view real-time data from Niagara stations.

## Tech Stack
- **Framework**: Flutter/Dart (SDK ^3.10.1)
- **State Management**: Riverpod with code generation
- **Backend**: Supabase
- **Purchases**: RevenueCat (per-station consumable IAP)
- **Navigation**: GoRouter
- **Models**: Freezed for immutable data classes
- **QR Scanning**: mobile_scanner

## Project Structure
```
lib/
├── app.dart              # App widget and router configuration
├── main.dart             # Entry point
├── core/
│   ├── config/           # Environment configuration
│   ├── constants/        # App and Niagara constants
│   ├── errors/           # Custom exceptions
│   └── theme/            # App colors and theme
├── data/
│   ├── datasources/      # Supabase data source
│   ├── models/           # Freezed data models
│   ├── repositories/     # Data repositories
│   └── services/         # Niagara client, scan history, station purchases
└── presentation/
    ├── providers/        # Riverpod providers
    ├── screens/          # UI screens (auth, admin, equipment, scan)
    └── widgets/          # Reusable widgets
```

## App Colors
- Primary (Amber): `#F5A623`
- Background (Dark): `#0A0A0A`
- Surface: `#141414`

## Environment Setup
1. Copy `.env.example` to `.env`
2. Add your Supabase credentials:
   ```
   SUPABASE_URL=https://cwdoklplunlaqakiyagb.supabase.co
   SUPABASE_ANON_KEY=<your-anon-key>
   ```
3. The anon key can also be found in `.vscode/launch.json`

## Development Commands

### Running the App
```bash
# Using VS Code launch configurations (recommended)
# Or via command line:
flutter run

# With explicit env var (if not using .env file):
flutter run --dart-define=SUPABASE_ANON_KEY=<key>
```

### Code Generation
Run after modifying Freezed models or Riverpod providers:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Testing
```bash
flutter test
```

### Building
```bash
# iOS
flutter build ipa

# Android
flutter build appbundle
```

## Key Routes
| Path | Screen | Description |
|------|--------|-------------|
| `/` | ScanScreen | QR scanner (home) |
| `/login` | LoginScreen | User login |
| `/register` | RegisterScreen | User registration |
| `/equipment/:qrId` | EquipmentScreen | Equipment details after scan |
| `/admin` | AdminScreen | Admin dashboard |
| `/admin/stations` | StationsScreen | Manage Niagara stations |
| `/admin/equipment` | EquipmentConfigsScreen | Manage equipment configs |
| `/account` | AccountScreen | User account settings |

## Data Models
All models use Freezed for immutability. Key models:
- `Station` - Niagara station connection info
- `EquipmentConfig` - Equipment QR code configuration
- `Point` - Data point from Niagara station
- `TreeNode` - Niagara navigation tree node
- `UserProfile` - User profile data

## Bundle IDs
- iOS: `com.basidekick.qrSidekick`
- Android: `com.basidekick.qr_sidekick`

## Monetization Model
- **Per-station purchase**: Each station requires a one-time consumable IAP purchase via RevenueCat
- **No free stations**: Every station requires purchase
- **Slot freed on deletion**: Deleting a station frees the slot (cascade deletes all equipment/QR codes)
- **Equipment unlimited**: No limits on equipment per station
- Key files: `station_purchase_service.dart` (StationPurchaseService), `station_purchase_provider.dart` (stationPurchaseStateProvider)
- Supabase `profiles.purchased_station_slots` tracks total slots purchased

## Supabase
- Project URL: https://cwdoklplunlaqakiyagb.supabase.co
- Tables: stations, equipment_configs, user_profiles, etc.
- `qsk_equipment_configs.station_id` has ON DELETE CASCADE to `qsk_stations.id`
