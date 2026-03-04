# RFTag Demo Web

A Flutter web/Android app for demonstrating RFTag serial communication.

## Features

- **Web Serial API** support for Chrome/Edge browsers
- **Android USB OTG** serial support
- Single "Demo Button" to run serial command sequences
- Real-time serial log display
- Connect/Disconnect functionality

## Usage

### Web (Chrome/Edge)

1. Build and serve:
   ```bash
   flutter build web --release
   cd build/web
   python3 -m http.server 8080
   ```

2. Open http://localhost:8080 in Chrome or Edge

3. Click "Connect" - browser will show serial port picker

4. Select your device and click "Demo Button" to run commands

### Android

1. Build and install:
   ```bash
   flutter build apk --release
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

2. Connect RFTag device via USB OTG cable

3. Open app, click "Connect"

4. Click "Demo Button" to run commands

## Adding Serial Commands

Edit `lib/serial_service.dart` and update the `runDemoCommands()` method:

```dart
Future<void> runDemoCommands() async {
  _log('--- Demo Command Sequence ---');
  
  // Send text command
  await sendCommand('AT\r\n');
  await Future.delayed(Duration(milliseconds: 500));
  
  // Send raw bytes
  await sendBytes(Uint8List.fromList([0x01, 0x02, 0x03]));
  await Future.delayed(Duration(milliseconds: 500));
  
  _log('Demo complete!');
}
```

## Libraries Used

- **serial** (^0.0.7+1) - Web Serial API wrapper for Flutter web
- **flutter_serial_communication** (^0.2.8) - USB Serial for Android

## Requirements

### Web
- Chrome 89+ or Edge 89+ (Web Serial API support)
- HTTPS or localhost (secure context required)

### Android
- Android 5.0+ (API 21+)
- USB OTG support
- USB host permission
