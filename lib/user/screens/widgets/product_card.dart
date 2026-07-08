import 'package:flutter/material.dart';

class ProductCard extends StatelessWidget {
  final String name;
  final double price;
  final String image;

  const ProductCard({
    super.key,
    required this.name,
    required this.price,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Expanded(
            child: Image.network(
              image,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Text(name),
          Text("₱$price"),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}