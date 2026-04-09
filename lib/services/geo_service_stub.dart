// Stub for non-web platforms
// On Android/iOS, we use platform-specific location APIs (not implemented yet)

import 'geo_service.dart';

/// Stub implementation - returns null to fall back to default location.
Future<GeoPosition?> getBrowserPosition() async {
  return null; // Platform geolocation not implemented
}
