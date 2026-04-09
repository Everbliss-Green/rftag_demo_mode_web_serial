// Web implementation using JS interop for browser Geolocation API

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import 'geo_service.dart';

// JS interop for Geolocation API
@JS('navigator.geolocation')
external JSObject? get _geolocation;

/// Web implementation - uses browser Geolocation API.
Future<GeoPosition?> getBrowserPosition() async {
  final geo = _geolocation;
  if (geo == null) {
    debugPrint('Geolocation API not available');
    return null;
  }

  final completer = Completer<GeoPosition?>();

  // Success callback
  void onSuccess(JSObject position) {
    try {
      final coords = position.getProperty<JSObject>('coords'.toJS);
      final lat = (coords.getProperty<JSNumber>('latitude'.toJS)).toDartDouble;
      final lon = (coords.getProperty<JSNumber>('longitude'.toJS)).toDartDouble;
      debugPrint('Geolocation success: $lat, $lon');
      completer.complete(GeoPosition(latitude: lat, longitude: lon));
    } catch (e) {
      debugPrint('Error parsing position: $e');
      completer.complete(null);
    }
  }

  // Error callback
  void onError(JSObject error) {
    try {
      final code = error.getProperty<JSNumber?>('code'.toJS)?.toDartInt ?? -1;
      final message =
          error.getProperty<JSString?>('message'.toJS)?.toDart ??
          'Unknown error';
      debugPrint('Geolocation error ($code): $message');
    } catch (_) {
      debugPrint('Geolocation error (unknown)');
    }
    completer.complete(null);
  }

  // Call getCurrentPosition
  final getCurrentPositionFn = geo.getProperty<JSFunction>(
    'getCurrentPosition'.toJS,
  );

  // Options: high accuracy, 10 second timeout
  final options = JSObject();
  options.setProperty('enableHighAccuracy'.toJS, true.toJS);
  options.setProperty('timeout'.toJS, 10000.toJS);
  options.setProperty('maximumAge'.toJS, 60000.toJS);

  getCurrentPositionFn.callAsFunction(
    geo,
    onSuccess.toJS,
    onError.toJS,
    options,
  );

  // Timeout after 12 seconds
  return completer.future.timeout(
    const Duration(seconds: 12),
    onTimeout: () {
      debugPrint('Geolocation timeout');
      return null;
    },
  );
}

// JS interop helpers
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
