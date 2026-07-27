import 'package:flutter/material.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("System Notifications"),
        backgroundColor: const Color(0xFF0F5132),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: const [
          Card(
            child: ListTile(
              leading: Icon(Icons.warning, color: Colors.orange),
              title: Text("Low Stock Alert"),
              subtitle: Text("Rice stock below 10 sacks. Mag-restock kaagad."),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.cloud_done, color: Colors.blue),
              title: Text("Weather Update"),
              subtitle: Text("Naka-sync na ang pinakabagong forecast data."),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.shopping_bag, color: Colors.green),
              title: Text("New Order #1042"),
              subtitle: Text("Pumasok ang bagong order mula sa customer."),
            ),
          ),
        ],
      ),
    );
  }
}