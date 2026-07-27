import 'package:cloud_firestore/cloud_firestore.dart';

enum ProductType { palay, rice }

class ProductModel {
  final String? id;
  final String name; // Ito ay kukuha sa 'productName' field ng Firestore mo
  final ProductType type;
  final String category;
  final String metricDetail;
  final double price;
  final int stock;
  final int lowStockThreshold;
  final DateTime createdAt;
  final String imageUrl;

  ProductModel({
    this.id,
    required this.name,
    required this.type,
    required this.category,
    required this.metricDetail,
    required this.price,
    required this.stock,
    this.lowStockThreshold = 50,
    required this.createdAt,
    this.imageUrl = "",
  });

  // I-convert ang Firestore Document papuntang Strongly-Typed Dart Object
  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ProductModel(
      id: doc.id,
      // DIRETSONG FIX: 'productName' ang nakalagay sa screenshot mo kaya ito ang babasahin natin
      name: data['productName'] ?? data['name'] ?? '', 
      type: data['type'] == 'rice' ? ProductType.rice : ProductType.palay,
      category: data['category'] ?? 'General',
      metricDetail: data['metricDetail'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      stock: data['stock'] ?? 0,
      lowStockThreshold: data['lowStockThreshold'] ?? 50,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: data['imageUrl'] ?? '',
    );
  }

  // I-convert ang Data bago i-save sa Firestore para tugma sa database fields mo
  Map<String, dynamic> toFirestore() {
    return {
      'productName': name.trim(), // Binago para maging 'productName' gaya ng nasa screenshot mo
      'type': type.name, 
      'category': category.trim(),
      'metricDetail': metricDetail.trim(),
      'price': price,
      'stock': stock,
      'lowStockThreshold': lowStockThreshold,
      'createdAt': Timestamp.fromDate(createdAt),
      'imageUrl': imageUrl,
    };
  }
}