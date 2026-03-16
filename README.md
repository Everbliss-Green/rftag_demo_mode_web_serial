# RFTag Interactive Demo

A beautiful Flutter web app for demonstrating RFTag device capabilities via serial connection.

## Features

- **Interactive Scenarios** - Pre-built demo sequences for different use cases
- **Emergency Alert** - Simulates SOS alert propagation with sound effects
- **Group Movement** - Demonstrates real-time location tracking and compass pointing
- **Join Group** - Shows the group join/announcement sequence
- **Group Chat** - Simulates receiving messages from group members
- **Real-time Logs** - Terminal-style display of all serial commands/responses
- **Beautiful Dark UI** - Modern Material 3 design optimized for demos

## Quick Start

### Web (Chrome/Edge Desktop Only)

```bash
# Build and serve
flutter build web --release
cd build/web
python3 -m http.server 8080
```

Open http://localhost:8080 in **Chrome or Edge desktop browser**.

> **Note:** Web Serial API only works on desktop browsers (Chrome 89+, Edge 89+, Opera 76+).
> It does NOT work on mobile browsers or Firefox.

### Connect Device

1. Connect your RFTag device via USB
2. Click "Connect" - browser will show serial port picker
3. Select your Nordic device (VID: 0x1915)
4. Device info will display after connection

### Run Scenarios

1. Click on a scenario card to see details
2. Click "Run Scenario" to execute
3. Watch the serial log for commands/responses
4. Each scenario requires location permission

## Scenarios

| Scenario | Description |
|----------|-------------|
| **Emergency Alert** | 4 members created, one triggers SOS, emergency buzzer plays |
| **Group Movement** | 5 members at varying distances, demonstrates follow/compass |
| **Join Group** | Broadcasts join announcement, simulates member responses |
| **Group Chat** | Simulates receiving messages with notification sounds |

## Architecture

```
lib/
├── main.dart                 # App entry point
├── theme/
│   └── app_theme.dart        # Material 3 dark theme
├── pages/
│   └── demo_home_page.dart   # Main UI with scenarios
├── widgets/
│   ├── connection_card.dart  # Device connection UI
│   ├── scenario_card.dart    # Scenario display cards
│   └── command_log_panel.dart # Terminal log panel
├── services/
│   ├── device_service.dart   # High-level device control
│   ├── geo_service.dart      # Browser geolocation
│   ├── serial_web.dart       # Web Serial API impl
│   └── serial_stub.dart      # Non-web stub
├── commands/
│   └── rftag_commands.dart   # Shell command builder/parser
└── scenarios/
    ├── base_scenario.dart    # Scenario base class
    ├── emergency_scenario.dart
    ├── movement_scenario.dart
    ├── join_scenario.dart
    └── messaging_scenario.dart
```

## Serial Command Reference

Commands are sent to the RFTag Zephyr shell over USB CDC ACM:

```bash
# Location
rftag loc add <mac> <lat> <lon> <battery> <status>
rftag loc init

# Settings
rftag settings status set <flags>
rftag settings username set <name>

# Protocol/LoRa
rftag protocol send_join <username>
rftag protocol send_location <battery> <lat> <lon>

# Messages
rftag msg incoming store <mac> "<text>"

# Buzzer
rftag buz play <freq> <duration> <duty>
```

Response parsing detects `(rc=X)` error codes. Success when rc=0 or no error code.

## Requirements

- Chrome 89+ or Edge 89+ (desktop only)
- HTTPS or localhost (secure context required for Web Serial)
- Location permission (for scenario positioning)
- RFTag device connected via USB

## Development

```bash
# Run in debug
flutter run -d chrome

# Build release
flutter build web --release
```
