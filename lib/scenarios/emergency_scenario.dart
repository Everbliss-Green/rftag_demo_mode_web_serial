import 'dart:async';

import '../commands/rftag_commands.dart';
import '../services/geo_service.dart';
import 'base_scenario.dart';

/// Emergency scenario: Simulates a group member triggering an emergency alert.
///
/// Steps:
/// 1. Clear location repository
/// 2. Add 4 group members at different positions
/// 3. Trigger emergency on one member
/// 4. Show alert propagation
/// 5. Play emergency buzzer
class EmergencyScenario extends BaseScenario {
  EmergencyScenario({required super.deviceService, required super.geoService});

  @override
  String get name => 'Emergency Alert';

  @override
  String get description => 'Simulate SOS alert propagation';

  @override
  String get details =>
      'This scenario demonstrates the emergency alert system. '
      'A group of 4 members will be created around your location, '
      'then one member will trigger an SOS emergency. '
      'The device will sound an alert to demonstrate the warning system.';

  @override
  String get iconName => 'warning_amber';

  @override
  int get accentColor => 0xFFE53935; // Red

  late List<FakeMember> _members;
  late int _emergencyMemberIndex;

  @override
  List<ScenarioStep> buildSteps(GeoPosition userPosition) {
    // Generate members around user position
    final positions = geoService.generateCirclePositions(
      userPosition,
      4,
      200, // 200m radius
      startBearing: 45, // Start NE
    );

    _members = List.generate(
      4,
      (i) => FakeMember(
        mac: generateMac(),
        name: generateUsername(),
        position: positions[i],
        battery: generateBattery(),
        status: 0, // Normal status
      ),
    );

    // Pick random member for emergency
    _emergencyMemberIndex = 1; // Second member triggers emergency

    return [
      ScenarioStep(
        title: 'Initialize',
        description: 'Clear location repository',
        execute: () async {
          final result = await deviceService.commands?.initLocationRepo();
          return result?.success ?? false;
        },
      ),
      ScenarioStep(
        title: 'Add Member 1',
        description: 'Add ${_members[0].name} to the group',
        execute: () => _addMember(_members[0]),
      ),
      ScenarioStep(
        title: 'Add Member 2',
        description: 'Add ${_members[1].name} to the group',
        execute: () => _addMember(_members[1]),
      ),
      ScenarioStep(
        title: 'Add Member 3',
        description: 'Add ${_members[2].name} to the group',
        execute: () => _addMember(_members[2]),
      ),
      ScenarioStep(
        title: 'Add Member 4',
        description: 'Add ${_members[3].name} to the group',
        execute: () => _addMember(_members[3]),
      ),
      ScenarioStep(
        title: 'Trigger Emergency',
        description: '${_members[_emergencyMemberIndex].name} activates SOS!',
        execute: () => _triggerEmergency(_emergencyMemberIndex),
      ),
      ScenarioStep(
        title: 'Sound Alert',
        description: 'Playing emergency buzzer',
        execute: () => _playEmergencyBuzzer(),
      ),
      ScenarioStep(
        title: 'Complete',
        description: 'Emergency scenario finished',
        execute: () async => true,
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
    await Future.delayed(const Duration(milliseconds: 200));
    return result?.success ?? false;
  }

  Future<bool> _triggerEmergency(int memberIndex) async {
    final member = _members[memberIndex];

    // Update member with emergency status
    final result = await deviceService.commands?.addLocation(
      mac: member.mac,
      lat: member.position.latitude,
      lon: member.position.longitude,
      battery: member.battery,
      status: StatusFlags.emergency,
    );

    // Also store to history for BLE notification
    await deviceService.commands?.storeLocationHistory(
      mac: member.mac,
      lat: member.position.latitude,
      lon: member.position.longitude,
      battery: member.battery,
      status: StatusFlags.emergency,
      skipThrottle: true,
    );

    await Future.delayed(const Duration(milliseconds: 500));
    return result?.success ?? false;
  }

  Future<bool> _playEmergencyBuzzer() async {
    // Play warning tone pattern
    for (var i = 0; i < 3; i++) {
      final result = await deviceService.commands?.playBuzzer(
        frequencyHz: 2500,
        durationMs: 200,
        dutyCycle: 80,
      );
      if (result?.success != true) return false;
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return true;
  }
}
