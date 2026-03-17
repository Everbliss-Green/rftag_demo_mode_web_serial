import 'dart:async';

import 'package:flutter/material.dart';

import '../scenarios/base_scenario.dart';
import '../scenarios/emergency_scenario.dart';
import '../scenarios/movement_scenario.dart';
import '../services/device_service.dart';
import '../services/geo_service.dart';
import '../theme/app_theme.dart';
import '../widgets/command_log_panel.dart';
import '../widgets/connection_card.dart';
import '../widgets/scenario_card.dart';

/// Main demo page with scenario cards and log panel.
class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  final DeviceService _deviceService = DeviceService();
  final GeoService _geoService = GeoService();

  bool _isConnected = false;
  bool _isConnecting = false;
  DeviceInfo? _deviceInfo;

  final List<LogEntry> _logs = [];
  bool _isLogExpanded = true;

  late List<BaseScenario> _scenarios;
  final Map<String, ScenarioProgress?> _progress = {};
  final Map<String, ScenarioResult?> _results = {};
  String? _runningScenario;

  StreamSubscription<LogEntry>? _logSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  String? _initError;

  @override
  void initState() {
    super.initState();
    try {
      _initScenarios();
      _subscribeToLogs();
    } catch (e) {
      _initError = e.toString();
      debugPrint('Init error: $e');
    }
  }

  void _initScenarios() {
    _scenarios = [
      EmergencyScenario(deviceService: _deviceService, geoService: _geoService),
      MovementScenario(deviceService: _deviceService, geoService: _geoService),
    ];
  }

  void _subscribeToLogs() {
    _logSubscription = _deviceService.logStream.listen((log) {
      setState(() {
        _logs.add(log);
        // Keep last 500 logs
        if (_logs.length > 500) {
          _logs.removeAt(0);
        }
      });
    });

    _connectionSubscription = _deviceService.connectionStream.listen((
      connected,
    ) {
      setState(() {
        _isConnected = connected;
        _deviceInfo = _deviceService.deviceInfo;
      });
    });
  }

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
    });

    final success = await _deviceService.connect();

    setState(() {
      _isConnecting = false;
      _isConnected = success;
      _deviceInfo = _deviceService.deviceInfo;
    });
  }

  Future<void> _disconnect() async {
    await _deviceService.disconnect();
    setState(() {
      _isConnected = false;
      _deviceInfo = null;
    });
  }

  Future<void> _runScenario(BaseScenario scenario) async {
    final scenarioName = scenario.name;

    setState(() {
      _runningScenario = scenarioName;
      _progress[scenarioName] = null;
      _results[scenarioName] = null;
    });

    // Subscribe to progress
    final progressSub = scenario.progressStream.listen((prog) {
      setState(() {
        _progress[scenarioName] = prog;
      });
    });

    // Run scenario
    final result = await scenario.execute();

    await progressSub.cancel();

    setState(() {
      _runningScenario = null;
      _results[scenarioName] = result;
    });

    // Show result snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.error,
                color: result.success ? AppTheme.success : AppTheme.error,
              ),
              const SizedBox(width: 12),
              Text(
                result.success
                    ? '$scenarioName completed successfully!'
                    : result.errorMessage ?? '$scenarioName failed',
              ),
            ],
          ),
          backgroundColor: AppTheme.surfaceVariant,
        ),
      );
    }
  }

  void _cancelScenario(BaseScenario scenario) {
    scenario.cancel();
    setState(() {
      _runningScenario = null;
    });
  }

  void _showScenarioDetails(BaseScenario scenario) {
    showDialog(
      context: context,
      builder: (context) => ScenarioDetailsDialog(
        scenario: scenario,
        onRun: () => _runScenario(scenario),
      ),
    );
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _connectionSubscription?.cancel();
    _deviceService.dispose();
    for (final scenario in _scenarios) {
      scenario.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show error if initialization failed
    if (_initError != null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppTheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Initialization Error',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _initError!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive layout
            final isWide = constraints.maxWidth > 900;

            if (isWide) {
              return _buildWideLayout();
            } else {
              return _buildNarrowLayout();
            }
          },
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        // Main content (scenarios)
        Expanded(
          flex: 3,
          child: CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHero(),
                      const SizedBox(height: 24),
                      ConnectionCard(
                        deviceService: _deviceService,
                        isConnected: _isConnected,
                        isConnecting: _isConnecting,
                        deviceInfo: _deviceInfo,
                        onConnect: _connect,
                        onDisconnect: _disconnect,
                      ),
                      const SizedBox(height: 32),
                      _buildScenarioSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Log panel
        Container(
          width: 400,
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: AppTheme.surfaceVariant)),
          ),
          child: CommandLogPanel(
            logs: _logs,
            onClear: _clearLogs,
            isExpanded: _isLogExpanded,
            onToggleExpand: () {
              setState(() {
                _isLogExpanded = !_isLogExpanded;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHero(),
                      const SizedBox(height: 16),
                      ConnectionCard(
                        deviceService: _deviceService,
                        isConnected: _isConnected,
                        isConnecting: _isConnecting,
                        deviceInfo: _deviceInfo,
                        onConnect: _connect,
                        onDisconnect: _disconnect,
                      ),
                      const SizedBox(height: 24),
                      _buildScenarioSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Collapsible log panel at bottom
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: _isLogExpanded ? 250 : 56,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppTheme.surfaceVariant)),
          ),
          child: CommandLogPanel(
            logs: _logs,
            onClear: _clearLogs,
            isExpanded: _isLogExpanded,
            onToggleExpand: () {
              setState(() {
                _isLogExpanded = !_isLogExpanded;
              });
            },
          ),
        ),
      ],
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      floating: true,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'RF',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text('RFTag Demo'),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _isConnected
                ? AppTheme.success.withValues(alpha: 0.15)
                : AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isConnected ? AppTheme.success : AppTheme.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _isConnected ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 12,
                  color: _isConnected ? AppTheme.success : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Interactive Demo',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Connect your RFTag device and run interactive scenarios to demonstrate '
          'group communication, location tracking, and emergency features.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildScenarioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Scenarios',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            if (_runningScenario != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Running',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppTheme.primary),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _buildScenarioGrid(),
      ],
    );
  }

  Widget _buildScenarioGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 240, // Increased to accommodate progress bar
          ),
          itemCount: _scenarios.length,
          itemBuilder: (context, index) {
            final scenario = _scenarios[index];
            final isRunning = _runningScenario == scenario.name;
            final isOtherRunning = _runningScenario != null && !isRunning;

            return ScenarioCard(
              scenario: scenario,
              isRunning: isRunning,
              isDisabled: !_isConnected || isOtherRunning,
              progress: _progress[scenario.name],
              lastResult: _results[scenario.name],
              onRun: () => _runScenario(scenario),
              onCancel: () => _cancelScenario(scenario),
              onShowDetails: () => _showScenarioDetails(scenario),
            );
          },
        );
      },
    );
  }
}
