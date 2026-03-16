import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../commands/rftag_commands.dart';
import '../services/device_service.dart';
import '../services/geo_service.dart';

/// A step in a scenario execution.
@immutable
class ScenarioStep {
  final String title;
  final String description;
  final Future<bool> Function() execute;

  const ScenarioStep({
    required this.title,
    required this.description,
    required this.execute,
  });
}

/// Progress update during scenario execution.
@immutable
class ScenarioProgress {
  final int currentStep;
  final int totalSteps;
  final String stepTitle;
  final bool? stepSuccess;

  const ScenarioProgress({
    required this.currentStep,
    required this.totalSteps,
    required this.stepTitle,
    this.stepSuccess,
  });

  double get progress => totalSteps > 0 ? currentStep / totalSteps : 0;
}

/// Result of scenario execution.
@immutable
class ScenarioResult {
  final bool success;
  final int stepsCompleted;
  final int totalSteps;
  final String? errorMessage;

  const ScenarioResult({
    required this.success,
    required this.stepsCompleted,
    required this.totalSteps,
    this.errorMessage,
  });
}

/// Fake member data for scenarios.
@immutable
class FakeMember {
  final String mac;
  final String name;
  final GeoPosition position;
  final int battery;
  final int status;

  const FakeMember({
    required this.mac,
    required this.name,
    required this.position,
    required this.battery,
    required this.status,
  });

  /// Copy with updated fields.
  FakeMember copyWith({GeoPosition? position, int? battery, int? status}) {
    return FakeMember(
      mac: mac,
      name: name,
      position: position ?? this.position,
      battery: battery ?? this.battery,
      status: status ?? this.status,
    );
  }
}

/// Base class for demo scenarios.
abstract class BaseScenario {
  final DeviceService deviceService;
  final GeoService geoService;

  /// Stream for progress updates.
  final _progressController = StreamController<ScenarioProgress>.broadcast();
  Stream<ScenarioProgress> get progressStream => _progressController.stream;

  /// Whether the scenario has been cancelled.
  bool _cancelled = false;

  /// Random generator for fake data.
  final _random = math.Random();

  BaseScenario({required this.deviceService, required this.geoService});

  /// Scenario display name.
  String get name;

  /// Short description for UI.
  String get description;

  /// Detailed explanation shown before running.
  String get details;

  /// Icon name for Material Icons.
  String get iconName;

  /// Accent color for the scenario card (hex without #).
  int get accentColor;

  /// Build the steps for this scenario.
  List<ScenarioStep> buildSteps(GeoPosition userPosition);

  /// Execute the scenario.
  Future<ScenarioResult> execute() async {
    _cancelled = false;

    // Get user position (will use default demo location if geolocation unavailable)
    final userPosition = await geoService.getCurrentPosition();

    final steps = buildSteps(userPosition);
    var completedSteps = 0;

    for (var i = 0; i < steps.length; i++) {
      if (_cancelled) {
        return ScenarioResult(
          success: false,
          stepsCompleted: completedSteps,
          totalSteps: steps.length,
          errorMessage: 'Scenario cancelled',
        );
      }

      final step = steps[i];

      // Report progress
      _progressController.add(
        ScenarioProgress(
          currentStep: i + 1,
          totalSteps: steps.length,
          stepTitle: step.title,
        ),
      );

      // Execute step
      final success = await step.execute();

      // Report step result
      _progressController.add(
        ScenarioProgress(
          currentStep: i + 1,
          totalSteps: steps.length,
          stepTitle: step.title,
          stepSuccess: success,
        ),
      );

      if (success) {
        completedSteps++;
      } else {
        return ScenarioResult(
          success: false,
          stepsCompleted: completedSteps,
          totalSteps: steps.length,
          errorMessage: 'Step "${step.title}" failed',
        );
      }

      // Small delay between steps for visual feedback
      await Future.delayed(const Duration(milliseconds: 300));
    }

    return ScenarioResult(
      success: true,
      stepsCompleted: completedSteps,
      totalSteps: steps.length,
    );
  }

  /// Cancel the running scenario.
  void cancel() {
    _cancelled = true;
  }

  /// Generate a random MAC address.
  String generateMac() {
    final bytes = List.generate(6, (_) => _random.nextInt(256));
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join('');
  }

  /// Generate a random username.
  String generateUsername() {
    const names = [
      'Alex',
      'Jordan',
      'Taylor',
      'Morgan',
      'Casey',
      'Riley',
      'Quinn',
      'Avery',
      'Drew',
      'Skyler',
      'Reese',
      'Parker',
      'Blake',
      'Hayden',
      'Dakota',
    ];
    return names[_random.nextInt(names.length)];
  }

  /// Generate a random battery level (60-100).
  int generateBattery() => 60 + _random.nextInt(41);

  /// Helper to execute a command and check success.
  Future<bool> executeCommand(Future<CommandResult> Function() command) async {
    final result = await deviceService.execute(command);
    return result.success;
  }

  void dispose() {
    _progressController.close();
  }
}
