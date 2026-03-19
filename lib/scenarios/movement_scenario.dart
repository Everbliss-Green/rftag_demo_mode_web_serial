import 'dart:async';

import '../commands/rftag_commands.dart';
import '../services/geo_service.dart';
import 'base_scenario.dart';

/// Movement scenario: Simulates 4 members orbiting around user for 8 hours.
///
/// Steps:
/// 1. Clear location repository
/// 2. Add 1 solo member and 3 clustered members
/// 3. Simulate movement updates every 5 seconds for 8 hours (5760 updates)
/// 4. All members orbit around user at 2000m distance
/// 5. History batching (async, every 30 mins - movement continues during waits):
///    5 history → 3 min wait → 5 history → 3 min wait → 5 history
class MovementScenario extends BaseScenario {
  MovementScenario({required super.deviceService, required super.geoService});

  @override
  String get name => 'Orbit (8 hr)';

  @override
  String get description => '4 users orbiting around you';

  @override
  String get details =>
      'This scenario runs for 8 hours with updates every 5 seconds. '
      '3 clustered users + 1 solo user orbit around you at 2km distance. '
      'History (async, every 30 mins): 5 entries → 3 min wait → 5 more → 3 min wait → 5 more.';

  @override
  String get iconName => 'explore';

  @override
  int get accentColor => 0xFF43A047; // Green

  late FakeMember _soloMember; // 1 solo member
  late List<FakeMember> _clusterGroup; // 3 members clustered

  // 8 hours = 28800 seconds / 5 seconds per update = 5760 updates
  static const int _totalUpdates = 5760;
  static const int _updateIntervalMs = 5000; // 5 seconds

  // Track history step counter for 5-minute separated timestamps
  int _historyStepCounter = 0;
  late int _baseTodayTimestamp; // Start of today in Unix seconds

  // History batching: every 360 updates (30 min), send history batch
  // (5 consecutive, wait 5 min, 5 more = 20 total per batch)
  static const int _historyBatchIntervalUpdates = 360; // Every 30 mins

  /// Get timestamp for history entry (5 minutes apart, same day)
  /// Each history entry is 5 minutes (300 seconds) apart
  int _getHistoryTimestamp() {
    final timestamp =
        _baseTodayTimestamp + (_historyStepCounter * 300); // 5 mins apart
    _historyStepCounter++;
    return timestamp;
  }

  @override
  List<ScenarioStep> buildSteps(GeoPosition userPosition) {
    // Initialize timestamps for today (start at 8:00 AM today)
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 8, 0, 0);
    _baseTodayTimestamp = todayStart.millisecondsSinceEpoch ~/ 1000;
    _historyStepCounter = 0;

    // All users orbit at 2000m distance
    // Cluster group: Start at bearing 0° (North)
    final clusterBasePos = geoService.offsetPosition(userPosition, 2000, 0);
    _clusterGroup = List.generate(
      3,
      (i) => FakeMember(
        mac: generateMac(),
        name: generateUsername(),
        position: geoService.offsetPosition(
          clusterBasePos,
          i * 10.0, // Cluster within 10m
          i * 120.0, // Spread in a triangle
        ),
        battery: generateBattery(),
        status: 0,
      ),
    );

    // Solo member: Start at bearing 180° (South, opposite side of circle)
    final soloStartPos = geoService.offsetPosition(userPosition, 2000, 180);
    _soloMember = FakeMember(
      mac: generateMac(),
      name: generateUsername(),
      position: soloStartPos,
      battery: generateBattery(),
      status: StatusFlags.leader,
    );

    return [
      ScenarioStep(
        title: 'Initialize',
        description: 'Clear location repository',
        execute: () async {
          final result = await deviceService.commands?.initLocationRepo();
          return result?.success ?? false;
        },
      ),
      // Add solo member
      ScenarioStep(
        title: 'Add Solo',
        description: 'Adding ${_soloMember.name} (following behind)',
        execute: () => _addSoloMember(),
      ),
      // Add cluster group
      ScenarioStep(
        title: 'Add Cluster',
        description:
            'Adding ${_clusterGroup[0].name}, ${_clusterGroup[1].name}, ${_clusterGroup[2].name} (in front)',
        execute: () => _addClusterGroup(),
      ),
      // 5760 movement updates (8 hours at 5-second intervals)
      ...List.generate(_totalUpdates, (i) {
        final stepNum = i + 1;
        final totalSeconds = stepNum * 5;
        final hours = totalSeconds ~/ 3600;
        final minutesPassed = (totalSeconds % 3600) ~/ 60;
        final secondsPassed = totalSeconds % 60;
        final timeStr =
            '${hours}:${minutesPassed.toString().padLeft(2, '0')}:${secondsPassed.toString().padLeft(2, '0')}';
        return ScenarioStep(
          title: 'Move $stepNum/$_totalUpdates ($timeStr)',
          description: _getMovementDescription(stepNum),
          execute: () => _updateMovement(userPosition, stepNum),
        );
      }),
      ScenarioStep(
        title: 'Complete',
        description: '8 hour movement complete!',
        execute: () => _playConfirmation(),
      ),
    ];
  }

  String _getMovementDescription(int step) {
    // Full orbit = 360 steps, show current bearing
    final bearing = step % 360;
    final direction = bearing < 90
        ? 'NE'
        : bearing < 180
            ? 'SE'
            : bearing < 270
                ? 'SW'
                : 'NW';
    return 'Orbiting at 2km ($direction, ${bearing}°)';
  }

  Future<bool> _addSoloMember() async {
    final result = await deviceService.commands?.addLocation(
      mac: _soloMember.mac,
      lat: _soloMember.position.latitude,
      lon: _soloMember.position.longitude,
      battery: _soloMember.battery,
      status: _soloMember.status,
    );

    return result?.success ?? false;
  }

  Future<bool> _addClusterGroup() async {
    for (final member in _clusterGroup) {
      final result = await deviceService.commands?.addLocation(
        mac: member.mac,
        lat: member.position.latitude,
        lon: member.position.longitude,
        battery: member.battery,
        status: member.status,
      );

      if (!(result?.success ?? false)) return false;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return true;
  }

  Future<bool> _updateMovement(GeoPosition userPosition, int step) async {
    // Circular orbit: 1° per step = full circle in 360 steps (30 min)
    // Cluster starts at 0°, solo starts at 180° (opposite side)
    final clusterBearing = (step % 360).toDouble(); // 0-359°
    final soloBearing = ((step + 180) % 360).toDouble(); // 180° offset

    // Fixed orbit distance: 2000m
    const orbitDistance = 2000.0;

    // Update real-time locations (orbiting around user)
    await _updateClusterGroup(userPosition, orbitDistance, clusterBearing);
    await _updateSoloMember(userPosition, orbitDistance, soloBearing);

    // Only send history batch every 30 minutes (360 updates)
    // Run async (unawaited) so movement updates continue during 3-min waits
    if (step % _historyBatchIntervalUpdates == 0) {
      // ignore: unawaited_futures
      _sendHistoryBatchCycle(userPosition, orbitDistance, clusterBearing);
    }

    // Wait 5 seconds between updates
    await Future.delayed(const Duration(milliseconds: _updateIntervalMs));
    return true;
  }

  /// Send history batch cycle (runs async): 5 history → 3 min wait → 5 history → 3 min wait → 5 history
  /// Total 15 history entries per cycle (3 batches of 5)
  /// Movement updates continue independently during the waits
  Future<void> _sendHistoryBatchCycle(
    GeoPosition userPosition,
    double orbitDistance,
    double clusterBearing,
  ) async {
    // Solo is on opposite side (180° offset)
    final soloBearing = (clusterBearing + 180) % 360;

    // First batch: 5 consecutive history entries
    await _sendHistoryBatch(
        userPosition, orbitDistance, clusterBearing, soloBearing, 5);

    // Wait 3 minutes (movement continues in main loop)
    await Future.delayed(const Duration(minutes: 3));

    // Second batch: 5 more history entries
    await _sendHistoryBatch(
        userPosition, orbitDistance, clusterBearing, soloBearing, 5);

    // Wait 3 minutes (movement continues in main loop)
    await Future.delayed(const Duration(minutes: 3));

    // Third batch: 5 more history entries
    await _sendHistoryBatch(
        userPosition, orbitDistance, clusterBearing, soloBearing, 5);
  }

  /// Send N history entries for all 4 members
  Future<void> _sendHistoryBatch(
    GeoPosition userPosition,
    double orbitDistance,
    double clusterBearing,
    double soloBearing,
    int count,
  ) async {
    for (int i = 0; i < count; i++) {
      final timestamp = _getHistoryTimestamp();

      // Add slight bearing variation for each history entry
      final variation = i * 1.0; // 1° variation per entry

      // Solo member history - clear line first to avoid buffer corruption
      await deviceService.commands?.sendClearLine();
      final soloPos = geoService.offsetPosition(
        userPosition,
        orbitDistance,
        soloBearing + variation,
      );
      await deviceService.commands?.storeLocationHistory(
        mac: _soloMember.mac,
        lat: soloPos.latitude,
        lon: soloPos.longitude,
        battery: _soloMember.battery,
        status: _soloMember.status,
        timestamp: timestamp,
        skipThrottle: true,
      );
      await Future.delayed(const Duration(milliseconds: 500));

      // Cluster members history (same timestamp for all 3)
      final clusterBasePos = geoService.offsetPosition(
        userPosition,
        orbitDistance,
        clusterBearing + variation,
      );
      for (int j = 0; j < _clusterGroup.length; j++) {
        await deviceService.commands?.sendClearLine();
        final member = _clusterGroup[j];
        final memberPos = geoService.offsetPosition(
          clusterBasePos,
          j * 10.0,
          j * 120.0,
        );
        await deviceService.commands?.storeLocationHistory(
          mac: member.mac,
          lat: memberPos.latitude,
          lon: memberPos.longitude,
          battery: member.battery,
          status: member.status,
          timestamp: timestamp,
          skipThrottle: true,
        );
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Future<void> _updateSoloMember(
    GeoPosition userPosition,
    double distance,
    double bearing,
  ) async {
    final newPosition = geoService.offsetPosition(
      userPosition,
      distance,
      bearing,
    );

    // Clear line before command to avoid buffer corruption
    await deviceService.commands?.sendClearLine();
    await deviceService.commands?.addLocation(
      mac: _soloMember.mac,
      lat: newPosition.latitude,
      lon: newPosition.longitude,
      battery: _soloMember.battery,
      status: _soloMember.status,
    );
    // Wait for firmware to process
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _updateClusterGroup(
    GeoPosition userPosition,
    double distance,
    double bearing,
  ) async {
    final basePos = geoService.offsetPosition(userPosition, distance, bearing);

    for (int i = 0; i < _clusterGroup.length; i++) {
      final member = _clusterGroup[i];
      final newPosition = geoService.offsetPosition(
        basePos,
        i * 10.0, // Keep cluster tight (10m apart)
        i * 120.0,
      );

      // Clear line before command to avoid buffer corruption
      await deviceService.commands?.sendClearLine();
      await deviceService.commands?.addLocation(
        mac: member.mac,
        lat: newPosition.latitude,
        lon: newPosition.longitude,
        battery: member.battery,
        status: member.status,
      );
      // Wait for firmware to process
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<bool> _playConfirmation() async {
    // Play friendly confirmation tone
    final result = await deviceService.commands?.playBuzzer(
      frequencyHz: 1500,
      durationMs: 100,
      dutyCycle: 50,
    );
    await Future.delayed(const Duration(milliseconds: 150));
    await deviceService.commands?.playBuzzer(
      frequencyHz: 2000,
      durationMs: 150,
      dutyCycle: 50,
    );
    return result?.success ?? false;
  }
}
