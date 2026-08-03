import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String? id;
  final String name; 
  final String category;
  final String metricDetail;
  final double price;
  final int stock;
  final int lowStockThreshold;
  final DateTime createdAt;

  ProductModel({
    this.id,
    required this.name,
    required this.category,
    required this.metricDetail,
    required this.price,
    required this.stock,
    this.lowStockThreshold = 50,
    required this.createdAt,
  });

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ProductModel(
      id: doc.id,
      name: data['productName'] ?? data['name'] ?? '',
      category: data['category'] ?? 'General',
      metricDetail: data['metricDetail'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      stock: data['stock'] ?? 0,
      lowStockThreshold: data['lowStockThreshold'] ?? 50,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'productName': name.trim(),
      'name': name.trim(),
      'type': 'palay',
      'category': category.trim(),
      'metricDetail': metricDetail.trim(),
      'price': price,
      'stock': stock,
      'lowStockThreshold': lowStockThreshold,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}