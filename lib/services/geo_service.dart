import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

// JS interop for Geolocation API
@JS('navigator.geolocation')
external JSObject? get _geolocation;

/// Geographic position.
@immutable
class GeoPosition {
  final double latitude;
  final double longitude;

  const GeoPosition({required this.latitude, required this.longitude});

  @override
  String toString() => 'GeoPosition($latitude, $longitude)';
}

/// Service for browser geolocation and geographic calculations.
class GeoService {
  static const double _earthRadiusMeters = 6371000;

  /// Default demo location (San Francisco) used when geolocation is unavailable.
  static const GeoPosition defaultLocation = GeoPosition(
    latitude: 37.7749,
    longitude: -122.4194,
  );

  /// Get current position from browser geolocation API.
  ///
  /// Returns a default demo location if geolocation is not available or denied.
  Future<GeoPosition> getCurrentPosition() async {
    try {
      final position = await _getBrowserPosition();
      if (position != null) {
        debugPrint('Got browser location: $position');
        return position;
      }
    } catch (e) {
      debugPrint('Geolocation error: $e');
    }

    // Return default location for demo purposes
    debugPrint('Using default demo location: $defaultLocation');
    return defaultLocation;
  }

  /// Get browser geolocation using JS interop.
  Future<GeoPosition?> _getBrowserPosition() async {
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
        final lat = (coords.getProperty<JSNumber>(
          'latitude'.toJS,
        )).toDartDouble;
        final lon = (coords.getProperty<JSNumber>(
          'longitude'.toJS,
        )).toDartDouble;
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

  /// Calculate a new position offset from origin by distance and bearing.
  ///
  /// [origin] - Starting position
  /// [distanceMeters] - Distance to offset
  /// [bearingDegrees] - Bearing in compass degrees (0=North, 90=East, etc.)
  GeoPosition offsetPosition(
    GeoPosition origin,
    double distanceMeters,
    double bearingDegrees,
  ) {
    // Convert to radians
    final lat1 = _toRadians(origin.latitude);
    final lon1 = _toRadians(origin.longitude);
    final bearing = _toRadians(bearingDegrees);
    final angularDistance = distanceMeters / _earthRadiusMeters;

    // Calculate new position using spherical geometry
    final lat2 = math.asin(
      math.sin(lat1) * math.cos(angularDistance) +
          math.cos(lat1) * math.sin(angularDistance) * math.cos(bearing),
    );

    final lon2 =
        lon1 +
        math.atan2(
          math.sin(bearing) * math.sin(angularDistance) * math.cos(lat1),
          math.cos(angularDistance) - math.sin(lat1) * math.sin(lat2),
        );

    return GeoPosition(latitude: _toDegrees(lat2), longitude: _toDegrees(lon2));
  }

  /// Generate positions arranged in a circle around a center point.
  ///
  /// [center] - Center position
  /// [count] - Number of positions to generate
  /// [radiusMeters] - Radius of the circle
  /// [startBearing] - Bearing of first position (default: 0 = North)
  List<GeoPosition> generateCirclePositions(
    GeoPosition center,
    int count,
    double radiusMeters, {
    double startBearing = 0,
  }) {
    final positions = <GeoPosition>[];
    final angleStep = 360.0 / count;

    for (var i = 0; i < count; i++) {
      final bearing = startBearing + (i * angleStep);
      positions.add(offsetPosition(center, radiusMeters, bearing));
    }

    return positions;
  }

  /// Generate random positions within a radius of a center point.
  ///
  /// [center] - Center position
  /// [count] - Number of positions to generate
  /// [minRadius] - Minimum distance from center
  /// [maxRadius] - Maximum distance from center
  List<GeoPosition> generateRandomPositions(
    GeoPosition center,
    int count,
    double minRadius,
    double maxRadius,
  ) {
    final random = math.Random();
    final positions = <GeoPosition>[];

    for (var i = 0; i < count; i++) {
      final distance =
          minRadius + random.nextDouble() * (maxRadius - minRadius);
      final bearing = random.nextDouble() * 360;
      positions.add(offsetPosition(center, distance, bearing));
    }

    return positions;
  }

  /// Calculate distance between two positions in meters.
  double distanceBetween(GeoPosition pos1, GeoPosition pos2) {
    final lat1 = _toRadians(pos1.latitude);
    final lat2 = _toRadians(pos2.latitude);
    final dLat = _toRadians(pos2.latitude - pos1.latitude);
    final dLon = _toRadians(pos2.longitude - pos1.longitude);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return _earthRadiusMeters * c;
  }

  /// Calculate bearing from pos1 to pos2 in compass degrees.
  double bearingBetween(GeoPosition pos1, GeoPosition pos2) {
    final lat1 = _toRadians(pos1.latitude);
    final lat2 = _toRadians(pos2.latitude);
    final dLon = _toRadians(pos2.longitude - pos1.longitude);

    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final bearing = _toDegrees(math.atan2(y, x));
    return (bearing + 360) % 360; // Normalize to 0-360
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;
  double _toDegrees(double radians) => radians * 180 / math.pi;
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
