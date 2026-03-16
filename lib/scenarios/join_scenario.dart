import 'dart:async';

import '../services/geo_service.dart';
import 'base_scenario.dart';

/// Join Group scenario: Simulates the process of members joining a group.
///
/// Steps:
/// 1. Set device username and group ID
/// 2. Send join announcement via LoRa
/// 3. Simulate receiving join confirmations from other members
/// 4. Play welcome tone
class JoinGroupScenario extends BaseScenario {
  JoinGroupScenario({required super.deviceService, required super.geoService});

  @override
  String get name => 'Join Group';

  @override
  String get description => 'New member joining sequence';

  @override
  String get details =>
      'This scenario demonstrates the group join process. '
      'The device will broadcast a join announcement over LoRa, '
      'and you\'ll see simulated responses from existing group members.';

  @override
  String get iconName => 'group_add';

  @override
  int get accentColor => 0xFF1E88E5; // Blue

  late String _deviceUsername;
  late List<FakeMember> _existingMembers;

  @override
  List<ScenarioStep> buildSteps(GeoPosition userPosition) {
    _deviceUsername = 'Demo_${generateUsername()}';

    // Generate existing group members
    final positions = geoService.generateCirclePositions(
      userPosition,
      3,
      300, // 300m radius
    );

    _existingMembers = List.generate(
      3,
      (i) => FakeMember(
        mac: generateMac(),
        name: generateUsername(),
        position: positions[i],
        battery: generateBattery(),
        status: i == 0 ? 0x0002 : 0, // First one is leader
      ),
    );

    return [
      ScenarioStep(
        title: 'Set Username',
        description: 'Configure device as "$_deviceUsername"',
        execute: () => _setUsername(),
      ),
      ScenarioStep(
        title: 'Set Group ID',
        description: 'Join group "DEMO-2026"',
        execute: () => _setGroupId(),
      ),
      ScenarioStep(
        title: 'Broadcast Join',
        description: 'Sending join announcement via LoRa...',
        execute: () => _sendJoinAnnouncement(),
      ),
      ScenarioStep(
        title: 'Member Response 1',
        description: '${_existingMembers[0].name} (Leader) acknowledged',
        execute: () => _simulateJoinResponse(0),
      ),
      ScenarioStep(
        title: 'Member Response 2',
        description: '${_existingMembers[1].name} acknowledged',
        execute: () => _simulateJoinResponse(1),
      ),
      ScenarioStep(
        title: 'Member Response 3',
        description: '${_existingMembers[2].name} acknowledged',
        execute: () => _simulateJoinResponse(2),
      ),
      ScenarioStep(
        title: 'Welcome',
        description: 'Successfully joined group!',
        execute: () => _playWelcome(),
      ),
    ];
  }

  Future<bool> _setUsername() async {
    final result = await deviceService.commands?.setUsername(_deviceUsername);
    await Future.delayed(const Duration(milliseconds: 200));
    return result?.success ?? false;
  }

  Future<bool> _setGroupId() async {
    final result = await deviceService.commands?.setGroupId('DEMO2026');
    await Future.delayed(const Duration(milliseconds: 200));
    return result?.success ?? false;
  }

  Future<bool> _sendJoinAnnouncement() async {
    final result = await deviceService.commands?.sendJoin(_deviceUsername);
    // Wait a bit to simulate LoRa transmission
    await Future.delayed(const Duration(milliseconds: 1000));
    return result?.success ?? false;
  }

  Future<bool> _simulateJoinResponse(int memberIndex) async {
    final member = _existingMembers[memberIndex];

    // Simulate receiving their join message via bt join_sim
    final result = await deviceService.commands?.simulateJoin(
      member.mac,
      member.name,
    );

    // Add their location
    await deviceService.commands?.addLocation(
      mac: member.mac,
      lat: member.position.latitude,
      lon: member.position.longitude,
      battery: member.battery,
      status: member.status,
    );

    await Future.delayed(const Duration(milliseconds: 500));
    return result?.success ?? false;
  }

  Future<bool> _playWelcome() async {
    // Play welcoming tone sequence (ascending)
    for (final freq in [800, 1000, 1200, 1600]) {
      await deviceService.commands?.playBuzzer(
        frequencyHz: freq,
        durationMs: 80,
        dutyCycle: 50,
      );
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return true;
  }
}
