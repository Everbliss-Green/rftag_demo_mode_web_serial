import 'package:flutter/material.dart';

import 'pages/demo_home_page.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const RfTagDemoApp());
}

/// RFTag Interactive Demo Application.
///
/// A web-based demo for showcasing RFTag device capabilities
/// including emergency alerts, group tracking, and messaging.
class RfTagDemoApp extends StatelessWidget {
  const RfTagDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RFTag Demo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const DemoHomePage(),
    );
  }
}
