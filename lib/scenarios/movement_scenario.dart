import 'dart:async';

import '../commands/rftag_commands.dart';
import '../services/geo_service.dart';
import 'base_scenario.dart';

/// Movement scenario: Simulates group members moving and demonstrates compass pointing.
///
/// Steps:
/// 1. Clear location repository
/// 2. Add 5 group members at varying distances
/// 3. Set one as leader
/// 4. Simulate movement updates (members getting closer/farther)
/// 5. Demonstrate follow feature
class MovementScenario extends BaseScenario {
  MovementScenario({required super.deviceService, required super.geoService});

  @override
  String get name => 'Group Movement';

  @override
  String get description => 'Track members with compass pointing';

  @override
  String get details =>
      'This scenario demonstrates real-time location tracking. '
      '5 group members will be created at different distances (50m-500m). '
      'One will be designated as the group leader. '
      'The compass will point toward the nearest member.';

  @override
  String get iconName => 'explore';

  @override
  int get accentColor => 0xFF43A047; // Green

  late List<FakeMember> _members;
  static const _leaderIndex = 0;

  @override
  List<ScenarioStep> buildSteps(GeoPosition userPosition) {
    // Generate members at random distances
    final distances = [80.0, 150.0, 250.0, 350.0, 500.0];
    final bearings = [0.0, 72.0, 144.0, 216.0, 288.0]; // Evenly spread

    _members = List.generate(
      5,
      (i) => FakeMember(
        mac: generateMac(),
        name: generateUsername(),
        position: geoService.offsetPosition(
          userPosition,
          distances[i],
          bearings[i],
        ),
        battery: generateBattery(),
        status: i == _leaderIndex ? StatusFlags.leader : 0,
      ),
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
      // Add all members
      ...List.generate(
        5,
        (i) => ScenarioStep(
          title: 'Add ${_members[i].name}',
          description: i == _leaderIndex
              ? '${_members[i].name} (Leader) at ${distances[i].toInt()}m'
              : '${_members[i].name} at ${distances[i].toInt()}m',
          execute: () => _addMember(_members[i]),
        ),
      ),
      ScenarioStep(
        title: 'Follow Leader',
        description: 'Set compass to track ${_members[_leaderIndex].name}',
        execute: () => _setFollowLeader(),
      ),
      // Simulate movement - members get closer
      ScenarioStep(
        title: 'Movement Update 1',
        description: '${_members[2].name} is approaching...',
        execute: () => _updateMemberLocation(2, userPosition, 180, 144),
      ),
      ScenarioStep(
        title: 'Movement Update 2',
        description: '${_members[4].name} moving closer...',
        execute: () => _updateMemberLocation(4, userPosition, 300, 288),
      ),
      ScenarioStep(
        title: 'Movement Update 3',
        description: '${_members[1].name} approaching...',
        execute: () => _updateMemberLocation(1, userPosition, 100, 72),
      ),
      ScenarioStep(
        title: 'Play Confirmation',
        description: 'All members tracked successfully',
        execute: () => _playConfirmation(),
      ),
    ];
  }

  Future<bool> _addMember(FakeMember member) async {
    final result = await deviceService.commands?.addLocation(
      mac: member.mac,
      lat: member.position.latitude,
      lon: member.position.longitude,
      battery: member.battery,
      status: member.status,
    );

    // Also store to history
    await deviceService.commands?.storeLocationHistory(
      mac: member.mac,
      lat: member.position.latitude,
      lon: member.position.longitude,
      battery: member.battery,
      status: member.status,
      skipThrottle: true,
    );

    await Future.delayed(const Duration(milliseconds: 200));
    return result?.success ?? false;
  }

  Future<bool> _setFollowLeader() async {
    final result = await deviceService.commands?.followLeader(
      _members[_leaderIndex].mac,
    );
    await Future.delayed(const Duration(milliseconds: 300));
    return result?.success ?? false;
  }

  Future<bool> _updateMemberLocation(
    int memberIndex,
    GeoPosition userPosition,
    double newDistance,
    double bearing,
  ) async {
    final member = _members[memberIndex];
    final newPosition = geoService.offsetPosition(
      userPosition,
      newDistance,
      bearing,
    );

    // Update position
    final result = await deviceService.commands?.addLocation(
      mac: member.mac,
      lat: newPosition.latitude,
      lon: newPosition.longitude,
      battery: member.battery,
      status: member.status,
    );

    // Store to history for BLE update
    await deviceService.commands?.storeLocationHistory(
      mac: member.mac,
      lat: newPosition.latitude,
      lon: newPosition.longitude,
      battery: member.battery,
      status: member.status,
      skipThrottle: true,
    );

    await Future.delayed(const Duration(milliseconds: 500));
    return result?.success ?? false;
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
