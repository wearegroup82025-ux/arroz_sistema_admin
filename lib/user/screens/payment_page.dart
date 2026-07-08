import 'package:flutter/material.dart';

class PaymentPage extends StatelessWidget {
  const PaymentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment"),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {},
          child: const Text("Pay with GCash"),
        ),
      ),
    );
  }
}