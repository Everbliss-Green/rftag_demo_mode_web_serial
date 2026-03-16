import 'dart:async';

import 'package:flutter/material.dart';

// Conditional imports for platform-specific serial
import 'serial_service.dart';

void main() {
  runApp(const RfTagDemoApp());
}

class RfTagDemoApp extends StatelessWidget {
  const RfTagDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RFTag Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final SerialService _serialService = SerialService();
  bool _isConnected = false;
  bool _isRunning = false;
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _serialService.logStream.listen((log) {
      setState(() {
        _logs.add(log);
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _connect() async {
    final success = await _serialService.connect();
    setState(() {
      _isConnected = success;
    });
    if (success) {
      _addLog('✅ Connected to serial port');
    } else {
      _addLog('❌ Failed to connect');
    }
  }

  Future<void> _disconnect() async {
    await _serialService.disconnect();
    setState(() {
      _isConnected = false;
    });
    _addLog('🔌 Disconnected');
  }

  Future<void> _runDemo() async {
    if (!_isConnected) {
      _addLog('⚠️ Not connected! Please connect first.');
      return;
    }

    setState(() {
      _isRunning = true;
    });

    _addLog('🚀 Starting demo sequence...');

    try {
      // TODO: Add your serial commands here
      // Example placeholder commands - replace with actual commands later
      await _serialService.runDemoCommands();
      _addLog('✅ Demo sequence completed!');
    } catch (e) {
      _addLog('❌ Error during demo: $e');
    }

    setState(() {
      _isRunning = false;
    });
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    setState(() {
      _logs.add('[$timestamp] $message');
    });
    _scrollToBottom();
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  @override
  void dispose() {
    _serialService.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RFTag Serial Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _isConnected ? Icons.usb : Icons.usb_off,
                    color: _isConnected ? Colors.green : Colors.grey,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _isConnected ? 'Connected' : 'Disconnected',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _isConnected ? _disconnect : _connect,
                    icon: Icon(_isConnected ? Icons.link_off : Icons.link),
                    label: Text(_isConnected ? 'Disconnect' : 'Connect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isConnected ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Demo button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton(
                onPressed: _isRunning ? null : _runDemo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: _isRunning
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                          SizedBox(width: 16),
                          Text('Running Demo...'),
                        ],
                      )
                    : const Text('🎮 DEMO BUTTON'),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Log output
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'Serial Log',
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(color: Colors.white70),
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        return Text(
                          _logs[index],
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.greenAccent,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
