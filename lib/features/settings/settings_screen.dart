import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  static const route = '/settings';

  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(
        child: Text('设置页占位'),
      ),
    );
  }
}
