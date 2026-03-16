import 'dart:async';

import '../services/geo_service.dart';
import 'base_scenario.dart';

/// Messaging scenario: Simulates receiving messages from group members.
///
/// Steps:
/// 1. Set up a few group members
/// 2. Receive messages from different members
/// 3. Demonstrate message notification sounds
class MessagingScenario extends BaseScenario {
  MessagingScenario({required super.deviceService, required super.geoService});

  @override
  String get name => 'Group Chat';

  @override
  String get description => 'Receive messages from members';

  @override
  String get details =>
      'This scenario demonstrates the group messaging feature. '
      'Messages will arrive from different group members, '
      'with notification sounds for each new message.';

  @override
  String get iconName => 'chat_bubble';

  @override
  int get accentColor => 0xFF8E24AA; // Purple

  late List<FakeMember> _members;

  static const _messages = [
    'Hey everyone! 👋',
    'Starting the hike now',
    'Beautiful view up here!',
    'Taking a water break',
    'See you at the summit!',
  ];

  @override
  List<ScenarioStep> buildSteps(GeoPosition userPosition) {
    // Generate members
    final positions = geoService.generateRandomPositions(
      userPosition,
      3,
      100, // 100m min
      400, // 400m max
    );

    _members = List.generate(
      3,
      (i) => FakeMember(
        mac: generateMac(),
        name: generateUsername(),
        position: positions[i],
        battery: generateBattery(),
        status: 0,
      ),
    );

    return [
      ScenarioStep(
        title: 'Initialize',
        description: 'Clear message queue',
        execute: () => _clearMessages(),
      ),
      ScenarioStep(
        title: 'Setup Members',
        description: 'Add group members',
        execute: () => _setupMembers(),
      ),
      ScenarioStep(
        title: 'Message 1',
        description: '${_members[0].name}: "${_messages[0]}"',
        execute: () => _sendMessage(0, _messages[0]),
      ),
      ScenarioStep(
        title: 'Message 2',
        description: '${_members[1].name}: "${_messages[1]}"',
        execute: () => _sendMessage(1, _messages[1]),
      ),
      ScenarioStep(
        title: 'Message 3',
        description: '${_members[2].name}: "${_messages[2]}"',
        execute: () => _sendMessage(2, _messages[2]),
      ),
      ScenarioStep(
        title: 'Message 4',
        description: '${_members[0].name}: "${_messages[3]}"',
        execute: () => _sendMessage(0, _messages[3]),
      ),
      ScenarioStep(
        title: 'Message 5',
        description: '${_members[1].name}: "${_messages[4]}"',
        execute: () => _sendMessage(1, _messages[4]),
      ),
      ScenarioStep(
        title: 'Complete',
        description: 'All messages received!',
        execute: () async => true,
      ),
    ];
  }

  Future<bool> _clearMessages() async {
    final result = await deviceService.commands?.clearIncomingMessages();
    await Future.delayed(const Duration(milliseconds: 200));
    return result?.success ?? false;
  }

  Future<bool> _setupMembers() async {
    for (final member in _members) {
      final result = await deviceService.commands?.addLocation(
        mac: member.mac,
        lat: member.position.latitude,
        lon: member.position.longitude,
        battery: member.battery,
        status: member.status,
      );
      if (result?.success != true) return false;

      // Also simulate join so name is known
      await deviceService.commands?.simulateJoin(member.mac, member.name);
    }
    return true;
  }

  Future<bool> _sendMessage(int memberIndex, String message) async {
    final member = _members[memberIndex];

    // Store incoming message
    final result = await deviceService.commands?.storeIncomingMessage(
      fromMac: member.mac,
      text: message,
    );

    // Play notification sound
    await _playMessageNotification();

    await Future.delayed(const Duration(milliseconds: 800));
    return result?.success ?? false;
  }

  Future<void> _playMessageNotification() async {
    // Two-tone notification
    await deviceService.commands?.playBuzzer(
      frequencyHz: 1000,
      durationMs: 50,
      dutyCycle: 50,
    );
    await Future.delayed(const Duration(milliseconds: 80));
    await deviceService.commands?.playBuzzer(
      frequencyHz: 1500,
      durationMs: 80,
      dutyCycle: 50,
    );
  }
}
