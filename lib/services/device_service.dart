import 'dart:async';

import 'package:flutter/foundation.dart';

import '../commands/rftag_commands.dart';
import 'serial_web.dart' if (dart.library.io) 'serial_stub.dart' as serial_impl;

/// Log entry types for visual differentiation.
enum LogType { info, tx, rx, success, error, warning }

/// A log entry with type and message.
@immutable
class LogEntry {
  final DateTime timestamp;
  final LogType type;
  final String message;

  const LogEntry({
    required this.timestamp,
    required this.type,
    required this.message,
  });

  String get timestampStr => timestamp.toString().substring(11, 23);
}

/// Device information retrieved from RFTag.
@immutable
class DeviceInfo {
  final String version;
  final String mac;
  final String? battery;

  const DeviceInfo({required this.version, required this.mac, this.battery});
}

/// High-level service for controlling the RFTag device.
///
/// Wraps serial connection and command layer, providing:
/// - Connection management
/// - Command execution with logging
/// - Device info retrieval
class DeviceService {
  final serial_impl.PlatformSerial _serial = serial_impl.PlatformSerial();
  RftagCommands? _commands;

  bool _isConnected = false;
  DeviceInfo? _deviceInfo;

  // Log stream
  final _logController = StreamController<LogEntry>.broadcast();
  Stream<LogEntry> get logStream => _logController.stream;

  // Connection state stream
  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  bool get isConnected => _isConnected;
  DeviceInfo? get deviceInfo => _deviceInfo;
  RftagCommands? get commands => _commands;

  DeviceService() {
    // Forward serial logs
    _serial.logStream.listen((log) {
      _log(LogType.info, log);
    });
  }

  void _log(LogType type, String message) {
    _logController.add(
      LogEntry(timestamp: DateTime.now(), type: type, message: message),
    );
  }

  /// Connect to the RFTag device via serial.
  Future<bool> connect() async {
    _log(LogType.info, '🔌 Connecting to device...');

    final success = await _serial.connect();
    if (!success) {
      _log(LogType.error, '❌ Failed to connect');
      return false;
    }

    _isConnected = true;
    _connectionController.add(true);
    _log(LogType.success, '✅ Serial port connected');

    // Create command interface
    _commands = RftagCommands(
      sendBytes: _serial.sendBytes,
      executeCommand: _serial.executeCommand,
      dataStream: _serial.dataStream, // kept for compatibility
      onLog: (msg) =>
          _log(msg.startsWith('TX:') ? LogType.tx : LogType.rx, msg),
    );

    // Sync with shell
    _log(LogType.info, '🔄 Syncing with shell...');
    await _commands!.syncShell();

    // Skip device info fetch - go straight to commands
    _deviceInfo = DeviceInfo(version: 'Connected', mac: 'N/A', battery: null);
    _log(LogType.success, '✅ Ready for commands');

    return true;
  }

  /// Disconnect from the device.
  Future<void> disconnect() async {
    _log(LogType.info, '🔌 Disconnecting...');

    _commands?.dispose();
    _commands = null;
    await _serial.disconnect();

    _isConnected = false;
    _deviceInfo = null;
    _connectionController.add(false);

    _log(LogType.info, '🔌 Disconnected');
  }

  /// Execute a command and return the result.
  ///
  /// Wraps command execution with logging.
  Future<CommandResult> execute(
    Future<CommandResult> Function() command,
  ) async {
    if (_commands == null) {
      _log(LogType.error, '❌ Not connected');
      return const CommandResult(
        success: false,
        output: 'Not connected',
        rawResponse: '',
        errorCode: -1,
      );
    }

    final result = await command();

    if (result.success) {
      _log(LogType.success, '✓ ${result.output.split('\n').first}');
    } else {
      _log(LogType.error, '✗ ${result.output} (rc=${result.errorCode})');
    }

    return result;
  }

  /// Clear logs (for UI clear button).
  void clearLogs() {
    // Logs are streamed, UI maintains its own list
    _log(LogType.info, '--- Logs cleared ---');
  }

  void dispose() {
    disconnect();
    _logController.close();
    _connectionController.close();
  }
}
