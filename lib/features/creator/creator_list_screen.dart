import 'package:flutter/material.dart';

class CreatorListScreen extends StatelessWidget {
  static const route = '/creators';

  const CreatorListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Creators')),
      body: const Center(
        child: Text('创作者列表占位'),
      ),
    );
  }
}
