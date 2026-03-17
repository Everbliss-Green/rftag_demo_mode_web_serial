import 'dart:async';

import 'package:flutter/foundation.dart';

/// Result of executing an RFTag shell command.
@immutable
class CommandResult {
  final bool success;
  final String output;
  final String rawResponse;
  final int? errorCode;

  const CommandResult({
    required this.success,
    required this.output,
    required this.rawResponse,
    this.errorCode,
  });

  @override
  String toString() =>
      'CommandResult(success: $success, errorCode: $errorCode, output: $output)';
}

/// Status flags for RFTag members.
class StatusFlags {
  static const int leader = 0x0001; // Bit 0: LEADER
  static const int emergency = 0x0002; // Bit 1: EMERGENCY
  static const int fallen = 0x0004;
  static const int lowBattery = 0x0008;
  static const int noGps = 0x0010;

  /// Convert flags to hex string for shell command.
  static String toHex(int flags) =>
      '0x${flags.toRadixString(16).padLeft(4, '0')}';

  /// Create combined flags from a list of individual flags.
  static int combine(List<int> flags) => flags.fold(0, (a, b) => a | b);
}

/// RFTag shell command builder and response parser.
///
/// Ports the logic from Python `device.py` to handle communication
/// with the RFTag Zephyr shell over serial.
class RftagCommands {
  static const String shellPrompt = 'uart:~\$';
  static const Duration defaultTimeout = Duration(seconds: 3);

  final Future<bool> Function(Uint8List data) _sendBytes;
  final Future<String> Function(String command, {Duration timeout})
  _executeCommand;
  final void Function(String message) _onLog;

  RftagCommands({
    required Future<bool> Function(Uint8List data) sendBytes,
    required Future<String> Function(String command, {Duration timeout})
    executeCommand,
    required Stream<Uint8List>
    dataStream, // kept for compatibility but not used
    required void Function(String message) onLog,
  }) : _sendBytes = sendBytes,
       _executeCommand = executeCommand,
       _onLog = onLog;

  /// Send a raw command and wait for response until prompt.
  Future<CommandResult> sendCommand(
    String command, {
    Duration timeout = defaultTimeout,
  }) async {
    _onLog('TX: $command');

    try {
      final rawResponse = await _executeCommand(command, timeout: timeout);

      if (rawResponse.isEmpty) {
        _onLog('⏱️ Command timeout: $command');
        return CommandResult(
          success: false,
          output: 'Command timed out',
          rawResponse: '',
          errorCode: -1,
        );
      }

      final result = _parseResponse(command, rawResponse);
      _onLog('RX: ${result.output}');
      return result;
    } catch (e) {
      _onLog('❌ Command error: $e');
      return CommandResult(
        success: false,
        output: 'Command error: $e',
        rawResponse: '',
        errorCode: -1,
      );
    }
  }

  /// Parse raw response into structured result.
  ///
  /// Extracts error codes from format: "message (rc=X)"
  /// Success when no error code or rc=0.
  CommandResult _parseResponse(String command, String rawResponse) {
    final lines = rawResponse.split('\n');
    final outputLines = <String>[];
    var foundCommand = false;

    for (var line in lines) {
      line = line.replaceAll('\r', '').trim();

      // Skip echoed command
      if (!foundCommand && line.contains(command.trim())) {
        foundCommand = true;
        continue;
      }

      // Skip empty lines at start
      if (!foundCommand && line.isEmpty) {
        continue;
      }

      // Skip prompt lines
      if (line.contains(shellPrompt) || line.contains('uart:~')) {
        continue;
      }

      if (foundCommand && line.isNotEmpty) {
        outputLines.add(line);
      }
    }

    final output = outputLines.join('\n').trim();

    // Extract error code: "(rc=X)" or "(rc=-X)"
    final errorMatch = RegExp(r'\(rc=(-?\d+)\)').firstMatch(output);
    final errorCode = errorMatch != null
        ? int.parse(errorMatch.group(1)!)
        : null;

    // Success if no error code or rc=0
    final success = errorCode == null || errorCode == 0;

    return CommandResult(
      success: success,
      output: output,
      rawResponse: rawResponse,
      errorCode: errorCode,
    );
  }

  // ==================== High-Level Commands ====================

  /// Sync with shell by sending newlines.
  Future<void> syncShell() async {
    for (var i = 0; i < 3; i++) {
      await _sendBytes(Uint8List.fromList('\r\n'.codeUnits));
      await Future.delayed(const Duration(milliseconds: 50));
    }
    await Future.delayed(const Duration(milliseconds: 200));
    // Note: No buffer to clear with direct command execution
  }

  /// Get device firmware version.
  Future<CommandResult> getVersion() => sendCommand('rftag app version');

  /// Get device Bluetooth MAC address.
  Future<CommandResult> getMac() => sendCommand('rftag bt mac');

  /// Get battery state of charge.
  Future<CommandResult> getBattery() => sendCommand('rftag pmic soc');

  /// Enter test mode (events dropped, shell commands only).
  Future<CommandResult> enterTestMode() => sendCommand('rftag testmode enter');

  /// Exit test mode.
  Future<CommandResult> exitTestMode() => sendCommand('rftag testmode exit');

  /// Get test mode status.
  Future<CommandResult> getTestModeStatus() =>
      sendCommand('rftag testmode status');

  // ==================== Location Repository Commands ====================

  /// Initialize location repository.
  Future<CommandResult> initLocationRepo() => sendCommand('rftag loc init');

  /// Add or update a member's location.
  ///
  /// [mac] - 12-digit hex without colons (e.g., AABBCCDDEEFF)
  /// [lat] - Latitude as float
  /// [lon] - Longitude as float
  /// [battery] - 0-100 percentage
  /// [status] - Status flags in hex (use [StatusFlags.toHex])
  /// [timestamp] - Optional Unix timestamp (auto-generated if null)
  Future<CommandResult> addLocation({
    required String mac,
    required double lat,
    required double lon,
    required int battery,
    required int status,
    int? timestamp,
  }) {
    final statusHex = StatusFlags.toHex(status);
    // Round to 6 decimal places for shorter command strings
    final latStr = lat.toStringAsFixed(6);
    final lonStr = lon.toStringAsFixed(6);
    final cmd = timestamp != null
        ? 'rftag loc add $mac $latStr $lonStr $battery $statusHex $timestamp'
        : 'rftag loc add $mac $latStr $lonStr $battery $statusHex';
    return sendCommand(cmd);
  }

  /// Get location for a specific member.
  Future<CommandResult> getLocation(String mac) =>
      sendCommand('rftag loc get $mac');

  /// List all members in location repository.
  Future<CommandResult> listLocations() => sendCommand('rftag loc list');

  /// Get member count in location repository.
  Future<CommandResult> getLocationCount() => sendCommand('rftag loc count');

  /// Clear location repository.
  Future<CommandResult> clearLocations() => sendCommand('rftag loc init');

  /// Store location to history (triggers BLE notification).
  ///
  /// Firmware format: store_history <mac> <lat> <lon> <status> <battery> [timestamp] [skip_throttle]
  /// Note: Using 3 decimal places (~100m accuracy) to fit within 64 char buffer limit.
  Future<CommandResult> storeLocationHistory({
    required String mac,
    required double lat,
    required double lon,
    required int battery,
    required int status,
    int? timestamp,
    bool skipThrottle = true,
  }) {
    // Use decimal status (shorter than hex) and 3 decimal places to fit in 64 char buffer
    // Full command with skip_throttle: "rftag loc store_history AABBCCDDEE05 24.965 121.564 2 85 0 1" = 62 chars
    final latStr = lat.toStringAsFixed(3);
    final lonStr = lon.toStringAsFixed(3);
    // Build command with optional timestamp and skip_throttle flag
    final parts = [
      'rftag loc store_history',
      mac,
      latStr,
      lonStr,
      '$status', // Decimal is shorter than hex (2 vs 0x0002)
      '$battery',
    ];
    if (timestamp != null || skipThrottle) {
      // If we need skip_throttle, we must include timestamp (use 0 for "now")
      parts.add('${timestamp ?? 0}');
      if (skipThrottle) {
        parts.add('1'); // skip_throttle = 1 to bypass 300s throttle
      }
    }
    return sendCommand(parts.join(' '));
  }

  // ==================== Settings Commands ====================

  /// Get current group ID.
  Future<CommandResult> getGroupId() =>
      sendCommand('rftag settings groupid get');

  /// Set group ID.
  Future<CommandResult> setGroupId(String groupId) =>
      sendCommand('rftag settings groupid set $groupId');

  /// Get device username.
  Future<CommandResult> getUsername() =>
      sendCommand('rftag settings username get');

  /// Set device username.
  Future<CommandResult> setUsername(String username) =>
      sendCommand('rftag settings username set $username');

  /// Get current status flags.
  Future<CommandResult> getStatusFlags() =>
      sendCommand('rftag settings status get');

  /// Set status flags (replaces all).
  Future<CommandResult> setStatusFlags(int flags) =>
      sendCommand('rftag settings status set ${StatusFlags.toHex(flags)}');

  /// Add status flags (OR operation).
  Future<CommandResult> addStatusFlags(int flags) =>
      sendCommand('rftag settings status add ${StatusFlags.toHex(flags)}');

  /// Remove status flags.
  Future<CommandResult> removeStatusFlags(int flags) =>
      sendCommand('rftag settings status remove ${StatusFlags.toHex(flags)}');

  // ==================== Protocol/LoRa Commands ====================

  /// Send join/announce message via LoRa.
  Future<CommandResult> sendJoin(String username) =>
      sendCommand('rftag protocol send_join $username');

  /// Send location update via LoRa.
  Future<CommandResult> sendLocation({
    required int battery,
    required double lat,
    required double lon,
  }) => sendCommand('rftag protocol send_location $battery $lat $lon');

  /// Send group text message via LoRa.
  Future<CommandResult> sendText(String text) =>
      sendCommand('rftag protocol send_text "$text"');

  /// Send direct message to specific member.
  Future<CommandResult> sendDirect(String targetMac, String text) =>
      sendCommand('rftag protocol send_direct $targetMac "$text"');

  /// Inject a fake LoRa alert (triggers device alarm via LoRa RX path).
  ///
  /// Format: rftag proto inject_alert <mac> <status_flags_hex> [lat] [lon] [battery]
  /// This simulates receiving an alert via LoRa, properly triggering emergency mode.
  Future<CommandResult> injectAlert({
    required String mac,
    required int status,
    double? lat,
    double? lon,
    int? battery,
  }) {
    final statusHex = StatusFlags.toHex(status);
    // Use 4 decimal places for coordinates to keep command short
    final latStr = lat?.toStringAsFixed(4) ?? '';
    final lonStr = lon?.toStringAsFixed(4) ?? '';
    final batStr = battery?.toString() ?? '';

    // Build command with optional params
    var cmd = 'rftag proto inject_alert $mac $statusHex';
    if (lat != null && lon != null) {
      cmd += ' $latStr $lonStr';
      if (battery != null) {
        cmd += ' $batStr';
      }
    }
    return sendCommand(cmd);
  }

  // ==================== Message Repository Commands ====================

  /// Store incoming message (simulates receiving a message).
  /// Note: Command kept short to fit serial buffer (~64 chars max).
  Future<CommandResult> storeIncomingMessage({
    required String fromMac,
    required String text,
    int? timestamp,
    int status = 0,
  }) {
    final ts = timestamp ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    // Truncate text to keep command short (buffer limit)
    final shortText = text.length > 8 ? text.substring(0, 8) : text;
    final statusHex = StatusFlags.toHex(status);
    return sendCommand(
      'rftag msg incoming store $fromMac "$shortText" $ts $statusHex',
    );
  }

  /// Get incoming message count.
  Future<CommandResult> getIncomingMessageCount() =>
      sendCommand('rftag msg incoming count');

  /// Read and pop next incoming message.
  Future<CommandResult> readIncomingMessage() =>
      sendCommand('rftag msg incoming read');

  /// Clear all incoming messages.
  Future<CommandResult> clearIncomingMessages() =>
      sendCommand('rftag msg incoming clear');

  // ==================== Bluetooth Commands ====================

  /// Simulate a joined member notification (for testing).
  Future<CommandResult> simulateJoin(String mac, String username) =>
      sendCommand('rftag bt join_sim $mac $username');

  // ==================== Follow Commands ====================

  /// Set member to follow.
  Future<CommandResult> followMember(String mac) =>
      sendCommand('rftag follow member $mac');

  /// Set leader to follow.
  Future<CommandResult> followLeader(String mac) =>
      sendCommand('rftag follow leader $mac');

  /// Clear followed member.
  Future<CommandResult> clearFollowMember() =>
      sendCommand('rftag follow clear member');

  /// Clear followed leader.
  Future<CommandResult> clearFollowLeader() =>
      sendCommand('rftag follow clear leader');

  /// Show current follow targets.
  Future<CommandResult> showFollow() => sendCommand('rftag follow show');

  // ==================== Buzzer Commands ====================

  /// Play buzzer tone.
  Future<CommandResult> playBuzzer({
    int frequencyHz = 2000,
    int durationMs = 200,
    int dutyCycle = 50,
  }) => sendCommand('rftag buz play $frequencyHz $durationMs $dutyCycle');

  /// Stop buzzer.
  Future<CommandResult> stopBuzzer() => sendCommand('rftag buz stop');

  void dispose() {
    // No cleanup needed - using direct command execution
  }
}
