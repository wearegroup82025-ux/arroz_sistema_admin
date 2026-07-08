import 'package:flutter/material.dart';

class CartItem extends StatelessWidget {
  final String productName;
  final int quantity;
  final double price;

  const CartItem({
    super.key,
    required this.productName,
    required this.quantity,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(productName),
      subtitle: Text("Qty: $quantity"),
      trailing: Text("₱$price"),
    );
  }
}