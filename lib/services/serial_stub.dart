// Stub for non-web platforms (Android uses different implementation)
// This file is only used when conditional import falls back

import 'dart:async';

import 'package:flutter/foundation.dart';

class PlatformSerial {
  bool _isConnected = false;

  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  final _dataController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get dataStream => _dataController.stream;

  bool get isConnected => _isConnected;

  Future<bool> connect() async {
    _logController.add('Platform not supported');
    return false;
  }

  Future<void> disconnect() async {
    _isConnected = false;
  }

  Future<bool> sendBytes(Uint8List data) async {
    return false;
  }

  void dispose() {
    _logController.close();
    _dataController.close();
  }
}
