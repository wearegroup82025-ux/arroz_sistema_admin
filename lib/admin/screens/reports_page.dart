import 'package:flutter/material.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sales Reports")),
      body: Column(
        children: const [
          Card(
            child: ListTile(
              title: Text("Today's Sales"),
              subtitle: Text("₱12,500"),
            ),
          ),
        ],
      ),
    );
  }
}