import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

// Web-specific imports for geolocation
import 'dart:js_interop';

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

  /// Get browser geolocation using JS interop.
  Future<GeoPosition?> _getBrowserPosition() async {
    final completer = Completer<GeoPosition?>();

    final navigator = _getNavigator();
    if (navigator == null) {
      return null;
    }

    final geolocation = _getGeolocation(navigator);
    if (geolocation == null) {
      return null;
    }

    // Create callbacks
    void onSuccess(JSObject position) {
      try {
        final coords = _getProperty(position, 'coords') as JSObject;
        final lat = _getDoubleProperty(coords, 'latitude');
        final lon = _getDoubleProperty(coords, 'longitude');

        if (lat != null && lon != null) {
          completer.complete(GeoPosition(latitude: lat, longitude: lon));
        } else {
          completer.complete(null);
        }
      } catch (e) {
        completer.complete(null);
      }
    }

    void onError(JSObject error) {
      debugPrint('Geolocation error: $error');
      completer.complete(null);
    }

    // Call getCurrentPosition
    final getCurrentPositionFn =
        _getProperty(geolocation, 'getCurrentPosition') as JSFunction;
    getCurrentPositionFn.callAsFunction(
      geolocation,
      onSuccess.toJS,
      onError.toJS,
    );

    return completer.future;
  }
}

// JS interop helpers

@JS('navigator')
external JSObject? _getNavigator();

JSObject? _getGeolocation(JSObject navigator) {
  return _getProperty(navigator, 'geolocation') as JSObject?;
}

@JS('Reflect.get')
external JSAny? _getProperty(JSObject obj, String key);

double? _getDoubleProperty(JSObject obj, String key) {
  final val = _getProperty(obj, key);
  if (val == null || val.isUndefinedOrNull) return null;
  return (val as JSNumber).toDartDouble;
}
