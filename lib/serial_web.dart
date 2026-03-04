import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:usb_device/usb_device.dart';

/// Web implementation using WebUSB API
/// Works on Android Chrome 61+, Chrome 61+, Edge 79+, Samsung Internet 8+
class PlatformSerial {
  final UsbDevice _usb = UsbDevice();
  dynamic _device;
  bool _isConnected = false;
  bool _isReading = false;
  int? _claimedInterface;

  // Endpoints
  int? _inEndpoint;
  int? _outEndpoint;

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

  Uint8List? _normalizeInData(dynamic data) {
    if (data == null) return null;
    if (data is Uint8List) return data;
    if (data is ByteBuffer) return Uint8List.view(data);
    if (data is List<int>) return Uint8List.fromList(data);
    return null;
  }

  Future<bool> connect() async {
    try {
      // Check if WebUSB is supported
      final supported = await _usb.isSupported();
      if (!supported) {
        _log('WebUSB not supported in this browser');
        return false;
      }
      _log('WebUSB supported');

      // nRF52840 USB VID/PIDs
      final filters = [
        DeviceFilter(
          vendorId: 0x1915,
          productId: 0x520F,
        ), // Nordic Semiconductor
        DeviceFilter(vendorId: 0x1915, productId: 0x521F),
        DeviceFilter(vendorId: 0x1915, productId: 0xCAFE),
      ];

      _log('Requesting USB device...');
      _device = await _usb.requestDevices(filters);

      if (_device == null) {
        _log('No device selected');
        return false;
      }

      // Get device info
      final info = await _usb.getPairedDeviceInfo(_device);
      _log(
        'Device: ${info.productName ?? "Unknown"} (VID: 0x${info.vendorId?.toRadixString(16)})',
      );

      // Open device
      await _usb.open(_device);
      _log('Device opened');

      // Select configuration
      await _usb.selectConfiguration(_device, 1);
      _log('Configuration selected');

      // Get configuration to find endpoints
      final config = await _usb.getSelectedConfiguration(_device);
      if (config == null) {
        _log('Could not get configuration');
        await _usb.close(_device);
        return false;
      }

      // Find CDC data interface (usually interface 1 for CDC ACM)
      int interfaceNum = 1; // Try interface 1 first (CDC data interface)

      if (config.usbInterfaces != null && config.usbInterfaces!.isNotEmpty) {
        _log('Found ${config.usbInterfaces!.length} interfaces');

        // Look for bulk endpoints
        for (var iface in config.usbInterfaces!) {
          if (iface.alternatesInterface != null) {
            for (var alt in iface.alternatesInterface!) {
              if (alt.endpoints != null) {
                for (var ep in alt.endpoints!) {
                  if (ep.type == 'bulk') {
                    interfaceNum = iface.interfaceNumber;
                    if (ep.direction == 'in') {
                      _inEndpoint = ep.endpointNumber;
                      _log('Found IN endpoint: ${ep.endpointNumber}');
                    } else if (ep.direction == 'out') {
                      _outEndpoint = ep.endpointNumber;
                      _log('Found OUT endpoint: ${ep.endpointNumber}');
                    }
                  }
                }
              }
            }
          }
        }
      }

      // Use default endpoints if not found
      _inEndpoint ??= 2;
      _outEndpoint ??= 2;

      // Claim interface
      await _usb.claimInterface(_device, interfaceNum);
      _log('Interface $interfaceNum claimed');
      _claimedInterface = interfaceNum;

      _isConnected = true;

      // Start reading data
      _startReading();

      return true;
    } catch (e) {
      _log('Connect error: $e');
      return false;
    }
  }

  void _startReading() {
    _isReading = true;
    _readLoop();
  }

  Future<void> _readLoop() async {
    while (_isReading && _isConnected && _device != null) {
      try {
        // Read from bulk IN endpoint
        final result = await _usb.transferIn(_device, _inEndpoint!, 64);

        final bytes = _normalizeInData(result.data);
        if (bytes != null && bytes.isNotEmpty) {
          _dataController.add(bytes);
          _log('RX: ${_bytesToHex(bytes)}');
        }
      } catch (e) {
        // Timeout or other read errors are normal for polling
        if (e.toString().contains('timeout')) continue;

        if (_isReading) {
          _log('Read error: $e');
        }
      }

      // Small delay between reads
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> disconnect() async {
    _isReading = false;
    _isConnected = false;

    if (_device != null) {
      try {
        if (_claimedInterface != null) {
          await _usb.releaseInterface(_device, _claimedInterface!);
        }
        await _usb.close(_device);
        _log('Disconnected');
      } catch (e) {
        _log('Disconnect error: $e');
      }
      _device = null;
    }

    _inEndpoint = null;
    _outEndpoint = null;
    _claimedInterface = null;
  }

  Future<bool> sendBytes(Uint8List data) async {
    if (!_isConnected || _device == null) {
      _log('Not connected');
      return false;
    }

    try {
      // Write to bulk OUT endpoint
      final result = await _usb.transferOut(
        _device,
        _outEndpoint!,
        data.buffer,
      );

      if (result.status == 'ok') {
        _log('TX: ${_bytesToHex(data)}');
        return true;
      } else {
        _log('TX failed: ${result.status}');
        return false;
      }
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
