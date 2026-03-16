import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_serial_communication/flutter_serial_communication.dart';

/// Android implementation using USB Serial
class PlatformSerial {
  final FlutterSerialCommunication _serial = FlutterSerialCommunication();
  bool _isConnected = false;
  StreamSubscription? _readSubscription;

  // Stream controllers
  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  final _dataController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get dataStream => _dataController.stream;

  bool get isConnected => _isConnected;

  void _log(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    _logController.add('[$timestamp] $message');
    debugPrint('[SerialAndroid] $message');
  }

  /// Convert bytes to hex string for display
  String _bytesToHex(Uint8List bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }

  Future<bool> connect() async {
    try {
      _log('Searching for USB devices...');

      final devices = await _serial.getAvailableDevices();

      if (devices.isEmpty) {
        _log('No USB devices found');
        return false;
      }

      _log('Found ${devices.length} device(s)');

      // Connect to first device
      final device = devices.first;
      _log('Connecting to: ${device.deviceName}');

      final connected = await _serial.connect(device, 115200);

      if (connected) {
        _log('Connected to ${device.deviceName}');

        // Listen for incoming data using EventChannel
        _readSubscription = _serial
            .getSerialMessageListener()
            .receiveBroadcastStream()
            .listen((data) {
              if (data is Uint8List) {
                _dataController.add(data);
                _log('RX: ${_bytesToHex(data)}');
              }
            });

        _isConnected = true;
        return true;
      }

      _log('Failed to connect');
      return false;
    } catch (e) {
      _log('Connect error: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    _isConnected = false;
    await _readSubscription?.cancel();
    _readSubscription = null;

    try {
      await _serial.disconnect();
      _log('Disconnected');
    } catch (e) {
      _log('Disconnect error: $e');
    }
  }

  Future<bool> sendBytes(Uint8List data) async {
    if (!_isConnected) {
      _log('Not connected');
      return false;
    }

    try {
      await _serial.write(data);
      _log('TX: ${_bytesToHex(data)}');
      return true;
    } catch (e) {
      _log('Send error: $e');
      return false;
    }
  }

  void dispose() {
    disconnect();
    _logController.close();
    _dataController.close();
  }
}
