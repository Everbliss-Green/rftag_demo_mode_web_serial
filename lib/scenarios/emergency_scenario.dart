import '../commands/rftag_commands.dart';
import '../services/geo_service.dart';
import 'base_scenario.dart';

/// Emergency scenario: Simulates a group member triggering an emergency alert.
///
/// Steps:
/// 1. Add 10 group members at different positions (2km radius)
/// 2. Trigger emergency on one member
class EmergencyScenario extends BaseScenario {
  EmergencyScenario({required super.deviceService, required super.geoService});

  @override
  String get name => 'Emergency Alert';

  @override
  String get description => 'Simulate SOS alert propagation';

  @override
  String get details =>
      'This scenario demonstrates the emergency alert system. '
      '10 group members will be placed in a 2km radius around your location, '
      'then one member will trigger an SOS emergency.';

  @override
  String get iconName => 'warning_amber';

  @override
  int get accentColor => 0xFFE53935; // Red

  late List<FakeMember> _members;
  late int _emergencyMemberIndex;

  @override
  List<ScenarioStep> buildSteps(GeoPosition userPosition) {
    // Generate 10 members around user position at 2km radius
    final positions = geoService.generateCirclePositions(
      userPosition,
      10,
      2000, // 2km radius
      startBearing: 0, // Start North
    );

    _members = List.generate(
      10,
      (i) => FakeMember(
        mac: generateMac(),
        name: generateUsername(),
        position: positions[i],
        battery: generateBattery(),
        status: 0, // Normal status
      ),
    );

    // Pick member for emergency (member 5)
    _emergencyMemberIndex = 4;

    // Build steps: add all 10 members, then trigger emergency on one
    final steps = <ScenarioStep>[];

    for (var i = 0; i < 10; i++) {
      steps.add(
        ScenarioStep(
          title: 'Add Member ${i + 1}',
          description: 'Add ${_members[i].name} to the group',
          execute: () => _addMember(_members[i]),
        ),
      );
    }

    steps.add(
      ScenarioStep(
        title: 'Trigger Emergency',
        description: '${_members[_emergencyMemberIndex].name} activates SOS!',
        execute: () => _triggerEmergency(_emergencyMemberIndex),
      ),
    );

    steps.add(
      ScenarioStep(
        title: 'Complete',
        description: 'Emergency scenario finished',
        execute: () async => true,
      ),
    );

    return steps;
  }

  Future<bool> _addMember(FakeMember member) async {
    final result = await deviceService.commands?.addLocation(
      mac: member.mac,
      lat: member.position.latitude,
      lon: member.position.longitude,
      battery: member.battery,
      status: member.status,
    );
    return result?.success ?? false;
  }

  Future<bool> _triggerEmergency(int memberIndex) async {
    final member = _members[memberIndex];

    // Inject alert via LoRa RX path - this properly triggers device alarm
    // Format: rftag proto inject_alert <mac> <status> [lat] [lon] [battery]
    final alertResult = await deviceService.commands?.injectAlert(
      mac: member.mac,
      status: StatusFlags.emergency,
      lat: member.position.latitude,
      lon: member.position.longitude,
      battery: member.battery,
    );
    if (alertResult?.success != true) return false;

    // Also store to history for BLE notification to phone app
    final histResult = await deviceService.commands?.storeLocationHistory(
      mac: member.mac,
      lat: member.position.latitude,
      lon: member.position.longitude,
      battery: member.battery,
      status: StatusFlags.emergency,
      skipThrottle: true,
    );

    return histResult?.success ?? false;
  }
}
