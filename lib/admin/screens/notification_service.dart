import 'package:flutter/material.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.warning),
            title: Text("Low Stock Alert"),
            subtitle: Text("Rice stock below 10"),
          ),
        ],
      ),
    );
  }
}