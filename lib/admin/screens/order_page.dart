import 'package:flutter/material.dart';

class OrderPage extends StatelessWidget {
  const OrderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Orders")),
      body: ListView(
        children: const [
          ListTile(
            title: Text("Order #1001"),
            subtitle: Text("Pending"),
          ),
        ],
      ),
    );
  }
}