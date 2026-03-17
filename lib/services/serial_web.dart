// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

// JS interop for Web Serial API
@JS('navigator.serial')
external JSObject? get _serial;

@JS('navigator.serial.requestPort')
external JSPromise _requestPort();

/// Web implementation using Web Serial API
///
/// IMPORTANT: Web Serial API is ONLY available on DESKTOP browsers:
/// - Chrome 89+ (desktop only)
/// - Edge 89+ (desktop only)
/// - Opera 76+ (desktop only)
///
/// NOT SUPPORTED on:
/// - Chrome for Android
/// - Safari (iOS/macOS)
/// - Firefox (any platform)
class PlatformSerial {
  JSObject? _port;
  bool _isConnected = false;
  bool _keepReading = false;

  // Persistent writer to avoid lock cycling issues with USB CDC ACM
  JSObject? _persistentWriter;

  // Response buffer - accumulates data from background read loop
  final StringBuffer _responseBuffer = StringBuffer();

  // Completer for waiting on responses
  Completer<String>? _responseCompleter;

  // Stream controller for log messages
  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  // Stream controller for raw data (Uint8List)
  final _dataController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get dataStream => _dataController.stream;

  // Stream controller for parsed lines
  final _responseController = StreamController<String>.broadcast();
  Stream<String> get responseStream => _responseController.stream;

  bool get isConnected => _isConnected;

  /// Direct command execution using on-demand reading (for external use)
  Future<String> executeCommand(
    String command, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final result = await sendCommandDirect(command, timeout: timeout);
    return result.response;
  }

  void _log(String message) {
    _logController.add('[SerialWeb] $message');
    debugPrint('[SerialWeb] $message');
  }

  /// Check if Web Serial API is supported
  bool get isSupported {
    try {
      return _serial != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> connect() async {
    try {
      if (!isSupported) {
        _log('❌ Web Serial API not supported');
        _log('⚠️  Web Serial is DESKTOP-ONLY!');
        _log('   Supported: Chrome/Edge/Opera (desktop)');
        _log('   NOT supported: Android, iOS, Firefox');
        return false;
      }
      _log('Web Serial API supported');

      // Request port from user
      _log('Requesting serial port...');

      try {
        final portPromise = _requestPort();
        _port = await portPromise.toDart as JSObject?;
      } catch (e) {
        _log('User cancelled or no device: $e');
        return false;
      }

      if (_port == null) {
        _log('No port selected');
        return false;
      }

      // Open port at 115200 baud with explicit settings
      _log('Opening port at 115200 baud...');
      final openOptions = _createOptions({
        'baudRate': 115200,
        'dataBits': 8,
        'stopBits': 1,
        'parity': 'none',
        'flowControl': 'none',
        'bufferSize': 4096,
      });
      final openFn = _port!.getProperty<JSFunction>('open'.toJS);
      await (openFn.callAsFunction(_port!, openOptions) as JSPromise).toDart;
      _log('✓ Port opened');

      _isConnected = true;
      _keepReading = true;

      // Give port time to stabilize - USB CDC ACM devices need this
      await Future.delayed(const Duration(milliseconds: 300));

      // Acquire persistent writer only
      final writable = _port!.getProperty<JSObject?>('writable'.toJS);
      if (writable != null) {
        final getWriterFn = writable.getProperty<JSFunction>('getWriter'.toJS);
        _persistentWriter = getWriterFn.callAsFunction(writable) as JSObject;
        _log('✓ Persistent writer acquired');
      }

      // Start background read loop - this is the key change
      // The read loop runs continuously and accumulates responses
      _startBackgroundReadLoop();

      _log('✓ Connected to serial port (background reader mode)');
      return true;
    } catch (e, st) {
      _log('Connect error: $e');
      debugPrint('Stack trace: $st');
      return false;
    }
  }

  /// Background read loop - runs continuously and accumulates responses.
  /// This approach is more robust than on-demand reading for USB CDC ACM devices.
  Future<void> _startBackgroundReadLoop() async {
    while (_keepReading && _isConnected && _port != null) {
      final readable = _port!.getProperty<JSObject?>('readable'.toJS);
      if (readable == null) {
        await Future.delayed(const Duration(milliseconds: 50));
        continue;
      }

      JSObject? reader;
      try {
        final getReaderFn = readable.getProperty<JSFunction>('getReader'.toJS);
        reader = getReaderFn.callAsFunction(readable) as JSObject;
      } catch (e) {
        _log('Failed to get reader: $e');
        await Future.delayed(const Duration(milliseconds: 100));
        continue;
      }

      try {
        while (_keepReading && _isConnected) {
          final readFn = reader.getProperty<JSFunction>('read'.toJS);
          final resultPromise = readFn.callAsFunction(reader) as JSPromise;
          final result = await resultPromise.toDart as JSObject;

          final done =
              result.getProperty<JSBoolean?>('done'.toJS)?.toDart ?? false;
          if (done) break;

          final value = result.getProperty<JSUint8Array?>('value'.toJS);
          if (value != null) {
            final data = value.toDart;

            // Emit raw bytes
            _dataController.add(data);

            // Accumulate text in buffer
            final text = String.fromCharCodes(data);
            _responseBuffer.write(text);

            // Parse lines for streaming listeners (also handles RX logging)
            _emitParsedLines(text);

            // Check if we have a complete response (shell prompt received)
            final bufferContent = _responseBuffer.toString();
            if (bufferContent.contains('uart:~\$') &&
                _responseCompleter != null) {
              final completer = _responseCompleter!;
              _responseCompleter = null;
              completer.complete(bufferContent);
              _responseBuffer.clear();
            }
          }
        }
      } catch (e) {
        if (_keepReading && _isConnected) {
          _log('Read loop error: $e');
          // Mark as disconnected on device lost error
          if (e.toString().contains('device has been lost')) {
            _isConnected = false;
            _log('❌ Device disconnected');
          }
        }
      } finally {
        try {
          final releaseFn = reader.getProperty<JSFunction?>('releaseLock'.toJS);
          releaseFn?.callAsFunction(reader);
        } catch (_) {}
      }

      // Brief delay before reconnecting reader if needed
      if (_keepReading && _isConnected) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  // Line buffer for streaming line parsing
  String _lineBuffer = '';

  /// Emit parsed lines to the response stream and log complete lines
  void _emitParsedLines(String text) {
    _lineBuffer += text;
    final lines = _lineBuffer.split(RegExp(r'\r\n|\n|\r'));
    _lineBuffer = lines.removeLast(); // Keep incomplete line

    for (final line in lines) {
      final clean = line.replaceAll(RegExp(r'\x1B\[[0-9;]*[A-Za-z]'), '');
      if (clean.trim().isNotEmpty) {
        _responseController.add(clean);
        // Log complete lines only (not fragments)
        _log('RX: $clean');
      }
    }
  }

  /// Write string to serial port (using persistent writer)
  Future<void> _writeRaw(String text) async {
    if (_port == null || _persistentWriter == null) return;

    final writer = _persistentWriter!;
    final data = Uint8List.fromList(text.codeUnits);
    final writeFn = writer.getProperty<JSFunction>('write'.toJS);
    await (writeFn.callAsFunction(writer, data.toJS) as JSPromise).toDart;
    // Note: Don't release the writer lock - keep it persistent
  }

  /// Send bytes to serial port with logging
  Future<bool> sendBytes(Uint8List data) async {
    if (!_isConnected || _port == null) {
      _log('Not connected');
      return false;
    }

    try {
      final text = String.fromCharCodes(data);
      await _writeRaw(text);

      // Log without the newline for cleaner output
      final logText = text.replaceAll(RegExp(r'[\r\n]+$'), '');
      if (logText.isNotEmpty) {
        _log('TX: $logText');
      }
      return true;
    } catch (e) {
      _log('Send error: $e');
      return false;
    }
  }

  /// Send a command and wait for expected response pattern
  ///
  /// This method sends a command and waits until either:
  /// 1. A line containing [expectedPattern] is received (success)
  /// 2. A line containing '(rc=-' is received (error)
  /// 3. The shell prompt 'uart:~$' is received
  /// 4. Timeout expires
  Future<({bool success, String response})> sendCommand(
    String command,
    String expectedPattern, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (!_isConnected || _port == null) {
      return (success: false, response: 'Not connected');
    }

    final completer = Completer<({bool success, String response})>();
    final responses = <String>[];

    // Listen for response lines
    final subscription = _responseController.stream.listen((line) {
      responses.add(line);

      // Check for success pattern
      if (line.contains(expectedPattern)) {
        if (!completer.isCompleted) {
          completer.complete((success: true, response: line));
        }
      }
      // Check for error pattern
      else if (line.contains('(rc=-')) {
        if (!completer.isCompleted) {
          completer.complete((success: false, response: line));
        }
      }
    });

    // Send command
    _log('TX: $command');
    await _writeRaw('$command\r\n');

    // Wait for response or timeout
    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () => (
          success: false,
          response: responses.isEmpty ? 'Timeout' : responses.join('\n'),
        ),
      );
    } finally {
      await subscription.cancel();
    }
  }

  /// Send a command and wait for response using the background reader.
  /// No hard timeout - waits for shell prompt or error response.
  Future<({bool success, String response})> sendCommandDirect(
    String command, {
    Duration timeout = const Duration(seconds: 10), // soft timeout for safety
  }) async {
    if (!_isConnected || _port == null) {
      return (success: false, response: 'Not connected');
    }

    // Clear any pending buffer content
    _responseBuffer.clear();

    // Set up completer to wait for response
    _responseCompleter = Completer<String>();

    // Send command
    _log('TX: $command');
    try {
      await _writeRaw('$command\r\n');
    } catch (e) {
      _responseCompleter = null;
      _log('Write failed: $e');
      return (success: false, response: 'Write failed: $e');
    }

    // Wait for response with soft timeout
    String response;
    try {
      response = await _responseCompleter!.future.timeout(
        timeout,
        onTimeout: () {
          // On timeout, return whatever we have so far
          final partial = _responseBuffer.toString();
          _responseBuffer.clear();
          _responseCompleter = null;
          return partial.isEmpty ? 'No response' : partial;
        },
      );
    } catch (e) {
      _responseCompleter = null;
      return (success: false, response: 'Error waiting for response: $e');
    }

    // Parse response - check for error codes
    final hasError =
        response.contains('(rc=-') || response.contains('wrong parameter');
    final success = !hasError && response.isNotEmpty;

    // Extract just the output lines (skip echo and prompt)
    final lines = response
        .split(RegExp(r'\r?\n'))
        .map((l) => l.replaceAll(RegExp(r'\x1B\[[0-9;]*[A-Za-z]'), '').trim())
        .where((l) => l.isNotEmpty && !l.contains('uart:~'))
        .where((l) => !l.startsWith(command.split(' ').first))
        .toList();

    return (success: success, response: lines.join('\n'));
  }

  Future<void> disconnect() async {
    _keepReading = false;
    _isConnected = false;

    // Cancel any pending response waiter
    if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
      _responseCompleter!.complete('');
      _responseCompleter = null;
    }

    // Release persistent writer lock before closing port
    if (_persistentWriter != null) {
      try {
        final releaseFn = _persistentWriter!.getProperty<JSFunction?>(
          'releaseLock'.toJS,
        );
        releaseFn?.callAsFunction(_persistentWriter!);
        _log('Released writer lock');
      } catch (e) {
        _log('Release writer error: $e');
      }
      _persistentWriter = null;
    }

    if (_port != null) {
      try {
        final closeFn = _port!.getProperty<JSFunction?>('close'.toJS);
        if (closeFn != null) {
          await (closeFn.callAsFunction(_port!) as JSPromise).toDart;
        }
      } catch (e) {
        _log('Close error: $e');
      }
    }
    _port = null;
    _responseBuffer.clear();
    _log('Disconnected');
  }

  void dispose() {
    disconnect();
    _logController.close();
    _dataController.close();
    _responseController.close();
  }
}

/// Create a JS object with the given properties
JSObject _createOptions(Map<String, dynamic> options) {
  final obj = JSObject();
  for (final entry in options.entries) {
    final value = entry.value;
    if (value is int) {
      obj.setProperty(entry.key.toJS, value.toJS);
    } else if (value is String) {
      obj.setProperty(entry.key.toJS, value.toJS);
    } else if (value is bool) {
      obj.setProperty(entry.key.toJS, value.toJS);
    }
  }
  return obj;
}

extension on JSObject {
  T getProperty<T extends JSAny?>(JSString name) {
    return _jsGetProperty(this, name) as T;
  }

  void setProperty(JSString name, JSAny? value) {
    _jsSetProperty(this, name, value);
  }
}

@JS('Reflect.get')
external JSAny? _jsGetProperty(JSObject obj, JSString name);

@JS('Reflect.set')
external void _jsSetProperty(JSObject obj, JSString name, JSAny? value);
