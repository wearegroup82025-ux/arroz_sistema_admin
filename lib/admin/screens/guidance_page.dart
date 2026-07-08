import 'package:flutter/material.dart';

class GuidancePage extends StatelessWidget {
  const GuidancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Farming Guidance")),
      body: ListView(
        children: const [
          ListTile(
            title: Text("Rice Farming Tips"),
            subtitle: Text("Proper irrigation techniques"),
          ),
          ListTile(
            title: Text("Pest Management"),
            subtitle: Text("Prevent common crop diseases"),
          ),
        ],
      ),
    );
  }
}