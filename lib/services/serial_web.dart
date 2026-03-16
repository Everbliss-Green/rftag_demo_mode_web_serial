import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

/// Web implementation using Web Serial API
///
/// IMPORTANT: Web Serial API is ONLY available on DESKTOP browsers:
/// - Chrome 89+ (desktop only)
/// - Edge 89+ (desktop only)
/// - Opera 76+ (desktop only)
///
/// NOT SUPPORTED on:
/// - Chrome for Android (Web Serial API is NOT available on mobile)
/// - Safari (iOS/macOS)
/// - Firefox (any platform)
///
/// On Android, the USB device is claimed by the Android USB subsystem
/// (creating /dev/ttyACM* nodes), which prevents WebUSB-based polyfills
/// from working.
///
/// For Android serial access, use the native Android app instead:
///   flutter build apk
class PlatformSerial {
  JSObject? _port;
  JSObject? _reader;
  JSObject? _writer;
  bool _isConnected = false;
  bool _isReading = false;

  // Stream controllers
  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  final _dataController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get dataStream => _dataController.stream;

  bool get isConnected => _isConnected;

  void _log(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    _logController.add('[$timestamp] $message');
    debugPrint('[SerialWeb] $message');
  }

  /// Convert bytes to hex string for display
  String _bytesToHex(Uint8List bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }

  Future<bool> connect() async {
    try {
      // Check if Web Serial is supported
      final serial = _getSerial();
      if (serial == null) {
        _log('❌ Web Serial API not supported');
        _log('');
        _log('⚠️  Web Serial is DESKTOP-ONLY!');
        _log('   It does NOT work on Android Chrome.');
        _log('');
        _log('   Supported: Chrome/Edge/Opera (desktop)');
        _log('   NOT supported: Android, iOS, Firefox');
        _log('');
        _log('   For Android: build and install the APK');
        _log('   Command: flutter build apk');
        return false;
      }
      _log('Web Serial API supported');

      // Request port from user
      _log('Requesting serial port...');

      // Create filter for Nordic Semiconductor devices
      final filter1 = _createObject();
      _setProperty(filter1, 'usbVendorId', 0x1915.toJS);
      _setProperty(filter1, 'usbProductId', 0x520F.toJS);

      final filter2 = _createObject();
      _setProperty(filter2, 'usbVendorId', 0x1915.toJS);
      _setProperty(filter2, 'usbProductId', 0x521F.toJS);

      final filter3 = _createObject();
      _setProperty(filter3, 'usbVendorId', 0x1915.toJS);
      _setProperty(filter3, 'usbProductId', 0xCAFE.toJS);

      final filters = <JSObject>[filter1, filter2, filter3].toJS;

      final options = _createObject();
      _setProperty(options, 'filters', filters);

      try {
        final requestPortFn = _getProperty(serial, 'requestPort') as JSFunction;
        final portPromise =
            requestPortFn.callAsFunction(serial, options) as JSPromise;
        _port = await portPromise.toDart as JSObject?;
      } catch (e) {
        _log('User cancelled or no device selected: $e');
        return false;
      }

      if (_port == null) {
        _log('No port selected');
        return false;
      }

      // Get port info
      try {
        final getInfoFn = _getProperty(_port!, 'getInfo') as JSFunction?;
        if (getInfoFn != null) {
          final info = getInfoFn.callAsFunction(_port!) as JSObject?;
          if (info != null) {
            final vid = _getIntProperty(info, 'usbVendorId');
            final pid = _getIntProperty(info, 'usbProductId');
            _log(
              'Port selected (VID: 0x${vid?.toRadixString(16) ?? "?"}, PID: 0x${pid?.toRadixString(16) ?? "?"})',
            );
          }
        }
      } catch (e) {
        _log('Could not get port info: $e');
      }

      // Open the port
      _log('Opening port at 115200 baud...');
      final openOptions = _createObject();
      _setProperty(openOptions, 'baudRate', 115200.toJS);
      _setProperty(openOptions, 'dataBits', 8.toJS);
      _setProperty(openOptions, 'stopBits', 1.toJS);
      _setProperty(openOptions, 'parity', 'none'.toJS);
      _setProperty(openOptions, 'flowControl', 'none'.toJS);

      final openFn = _getProperty(_port!, 'open') as JSFunction;
      final openPromise =
          openFn.callAsFunction(_port!, openOptions) as JSPromise;
      await openPromise.toDart;
      _log('✓ Port opened successfully');

      // Get reader and writer
      final readable = _getProperty(_port!, 'readable') as JSObject?;
      final writable = _getProperty(_port!, 'writable') as JSObject?;

      if (readable == null || writable == null) {
        _log('Could not get readable/writable streams');
        await _closePort();
        return false;
      }

      final getReaderFn = _getProperty(readable, 'getReader') as JSFunction;
      _reader = getReaderFn.callAsFunction(readable) as JSObject;

      final getWriterFn = _getProperty(writable, 'getWriter') as JSFunction;
      _writer = getWriterFn.callAsFunction(writable) as JSObject;

      _isConnected = true;
      _log('✓ Connected to serial port');

      // Start reading data
      _startReading();

      return true;
    } catch (e, st) {
      _log('Connect error: $e');
      debugPrint('Stack trace: $st');
      return false;
    }
  }

  void _startReading() {
    _isReading = true;
    _readLoop();
  }

  Future<void> _readLoop() async {
    while (_isReading && _isConnected && _reader != null) {
      try {
        final readFn = _getProperty(_reader!, 'read') as JSFunction;
        final readPromise = readFn.callAsFunction(_reader!) as JSPromise;
        final result = await readPromise.toDart as JSObject;

        final done = _getBoolProperty(result, 'done');
        if (done == true) {
          _log('Read stream ended');
          break;
        }

        final value = _getProperty(result, 'value') as JSObject?;
        if (value != null) {
          final bytes = _uint8ArrayToList(value);
          if (bytes.isNotEmpty) {
            _dataController.add(bytes);

            // Try to decode as text for logging
            try {
              final text = String.fromCharCodes(bytes);
              _log('RX: $text');
            } catch (_) {
              _log('RX: ${_bytesToHex(bytes)}');
            }
          }
        }
      } catch (e) {
        if (_isReading) {
          _log('Read error: $e');
          break;
        }
      }
    }
  }

  Uint8List _uint8ArrayToList(JSObject jsArray) {
    final length = _getIntProperty(jsArray, 'length') ?? 0;
    final result = Uint8List(length);
    for (var i = 0; i < length; i++) {
      final val = _getProperty(jsArray, i.toString());
      if (val != null) {
        result[i] = (val as JSNumber).toDartInt;
      }
    }
    return result;
  }

  Future<void> _closePort() async {
    if (_port != null) {
      try {
        final closeFn = _getProperty(_port!, 'close') as JSFunction?;
        if (closeFn != null) {
          final closePromise = closeFn.callAsFunction(_port!) as JSPromise;
          await closePromise.toDart;
        }
      } catch (e) {
        _log('Close port error: $e');
      }
    }
  }

  Future<void> disconnect() async {
    _isReading = false;
    _isConnected = false;

    try {
      if (_reader != null) {
        try {
          final cancelFn = _getProperty(_reader!, 'cancel') as JSFunction?;
          if (cancelFn != null) {
            final cancelPromise =
                cancelFn.callAsFunction(_reader!) as JSPromise;
            await cancelPromise.toDart;
          }
        } catch (_) {}
        try {
          final releaseFn =
              _getProperty(_reader!, 'releaseLock') as JSFunction?;
          if (releaseFn != null) {
            releaseFn.callAsFunction(_reader!);
          }
        } catch (_) {}
        _reader = null;
      }

      if (_writer != null) {
        try {
          final closeFn = _getProperty(_writer!, 'close') as JSFunction?;
          if (closeFn != null) {
            final closePromise = closeFn.callAsFunction(_writer!) as JSPromise;
            await closePromise.toDart;
          }
        } catch (_) {}
        try {
          final releaseFn =
              _getProperty(_writer!, 'releaseLock') as JSFunction?;
          if (releaseFn != null) {
            releaseFn.callAsFunction(_writer!);
          }
        } catch (_) {}
        _writer = null;
      }

      await _closePort();
      _port = null;
      _log('Disconnected');
    } catch (e) {
      _log('Disconnect error: $e');
    }
  }

  Future<bool> sendBytes(Uint8List data) async {
    if (!_isConnected || _writer == null) {
      _log('Not connected');
      return false;
    }

    try {
      // Convert Uint8List to JSUint8Array
      final jsArray = _listToUint8Array(data);

      final writeFn = _getProperty(_writer!, 'write') as JSFunction;
      final writePromise =
          writeFn.callAsFunction(_writer!, jsArray) as JSPromise;
      await writePromise.toDart;

      // Log the sent data as text
      try {
        final text = String.fromCharCodes(data);
        _log('TX: $text');
      } catch (_) {
        _log('TX: ${_bytesToHex(data)}');
      }

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

// JS interop helpers using dart:js_interop_unsafe for proper access

@JS('navigator')
external JSObject? get _navigator;

@JS('Object.create')
external JSObject _objectCreate(JSObject? proto);

@JS('Reflect.set')
external void _reflectSet(JSObject obj, String key, JSAny? value);

@JS('Reflect.get')
external JSAny? _reflectGet(JSObject obj, String key);

/// Get the Web Serial API object from navigator.serial
JSObject? _getSerial() {
  try {
    final nav = _navigator;
    if (nav == null) return null;
    final serial = _reflectGet(nav, 'serial');
    if (serial == null || serial.isUndefinedOrNull) return null;
    return serial as JSObject;
  } catch (e) {
    debugPrint('Error getting serial: $e');
    return null;
  }
}

JSObject _createObject() {
  return _objectCreate(null);
}

void _setProperty(JSObject obj, String key, JSAny? value) {
  _reflectSet(obj, key, value);
}

JSAny? _getProperty(JSObject obj, String key) {
  return _reflectGet(obj, key);
}

int? _getIntProperty(JSObject obj, String key) {
  final val = _getProperty(obj, key);
  if (val == null || val.isUndefinedOrNull) return null;
  return (val as JSNumber).toDartInt;
}

bool? _getBoolProperty(JSObject obj, String key) {
  final val = _getProperty(obj, key);
  if (val == null || val.isUndefinedOrNull) return null;
  return (val as JSBoolean).toDart;
}

JSObject _listToUint8Array(Uint8List data) {
  return data.toJS;
}
