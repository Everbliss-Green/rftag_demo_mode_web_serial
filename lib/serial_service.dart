import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

// Conditional imports
import 'serial_web.dart'
    if (dart.library.io) 'serial_android.dart'
    as serial_impl;

/// SerialService handles serial port communication for both web and Android.
class SerialService {
  final serial_impl.PlatformSerial _platformSerial =
      serial_impl.PlatformSerial();

  // Stream for logging
  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  // Received data stream
  final _dataController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get dataStream => _dataController.stream;

  bool get isConnected => _platformSerial.isConnected;

  SerialService() {
    // Forward logs from platform implementation
    _platformSerial.logStream.listen((log) {
      _logController.add(log);
    });
    _platformSerial.dataStream.listen((data) {
      _dataController.add(data);
    });
  }

  /// Connect to serial port
  Future<bool> connect() async {
    return _platformSerial.connect();
  }

  /// Disconnect from serial port
  Future<void> disconnect() async {
    await _platformSerial.disconnect();
  }

  /// Send raw bytes
  Future<bool> sendBytes(Uint8List data) async {
    return _platformSerial.sendBytes(data);
  }

  /// Send string command
  Future<bool> sendCommand(String command) async {
    final data = Uint8List.fromList(command.codeUnits);
    return sendBytes(data);
  }

  /// Run demo sequence - placeholder for your commands
  Future<void> runDemoCommands() async {
    _log('--- Demo Command Sequence ---');

    // Test buzzer command from firmware shell:
    // rftag buz play <frequencyHz> <durationMs> [dutyCycle]
    const command = 'rftag buz play 2000 200 50\r\n';
    _log('TX: $command');

    final ok = await sendCommand(command);
    if (ok) {
      _log('Buzzer command sent');
    } else {
      _log('Failed to send buzzer command');
    }

    await Future.delayed(const Duration(milliseconds: 200));
  }

  void _log(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    _logController.add('[$timestamp] $message');
    debugPrint('[SerialService] $message');
  }

  void dispose() {
    _platformSerial.dispose();
    _logController.close();
    _dataController.close();
  }
}
