# QR Sidekick - Project Instructions

## CRITICAL: Project Location
**This is the ONLY correct project folder:**
```
/Users/benhansen/Developer/qr-sidekick/qr_sidekick
```

DO NOT use `/Users/benhansen/Documents/Personal/Github/qr-sidekick/` - that is an old/duplicate folder.

## Project Overview
QR Sidekick - A Flutter app for scanning QR codes on BAS (Building Automation System) equipment.

## Tech Stack
- Flutter/Dart
- Riverpod for state management
- Supabase for backend
- RevenueCat for subscriptions
- GoRouter for navigation

## App Colors
- Primary (Amber): #F5A623
- Background (Dark): #0A0A0A
- Surface: #141414

## Supabase
- URL: https://cwdoklplunlaqakiyagb.supabase.co
- Anon key is configured in `.vscode/launch.json`

## Running the App
Use VS Code launch configurations or:
```bash
flutter run --dart-define=SUPABASE_ANON_KEY=<key>
```

## Build Commands
```bash
# iOS
flutter build ipa

# Android
flutter build appbundle
```

## Bundle IDs
- iOS: com.basidekick.qrSidekick
- Android: com.basidekick.qr_sidekick
