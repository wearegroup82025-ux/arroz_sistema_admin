import 'package:cloud_firestore/cloud_firestore.dart';


class ProductModel {
  final String? id;
  final String name;
  final String category;
  final String unit;
  final double unitKg;
  final double sellingPrice;
  final double srpPerKg;
  final double price; // Puhunan
  final int stock;
  final int lowStockThreshold;
  
  // Farm & Hectare Fields
  final double h1Cost;
  final double h1Kg;
  final double h2Cost;
  final double h2Kg;
  final double totalKg;
  final double totalCost;
  final bool isDeleted;
  final DateTime? createdAt;

  String get metricDetail => "$unit ($unitKg kg)";

  ProductModel({
    this.id,
    required this.name,
    this.category = 'Regular',
    this.unit = "Sako",
    this.unitKg = 50.0,
    this.sellingPrice = 0.0,
    this.srpPerKg = 0.0,
    this.price = 0.0,
    this.stock = 0,
    this.lowStockThreshold = 10,
    this.h1Cost = 0.0,
    this.h1Kg = 0.0,
    this.h2Cost = 0.0,
    this.h2Kg = 0.0,
    this.totalKg = 0.0,
    this.totalCost = 0.0,
    this.isDeleted = false,
    this.createdAt,
  });

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    
    double fetchedSellingPrice = (data['sellingPrice'] ?? data['price'] ?? data['srpPerKg'] ?? 0.0).toDouble();
    
    return ProductModel(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? 'Regular',
      unit: data['unit'] ?? 'Sako',
      unitKg: (data['unitKg'] ?? 50.0).toDouble(),
      sellingPrice: fetchedSellingPrice,
      srpPerKg: (data['srpPerKg'] ?? fetchedSellingPrice).toDouble(),
      price: (data['price'] ?? 0.0).toDouble(),
      stock: (data['stock'] ?? 0).toInt(),
      lowStockThreshold: (data['lowStockThreshold'] ?? 10).toInt(),
      h1Cost: (data['h1Cost'] ?? 0.0).toDouble(),
      h1Kg: (data['h1Kg'] ?? 0.0).toDouble(),
      h2Cost: (data['h2Cost'] ?? 0.0).toDouble(),
      h2Kg: (data['h2Kg'] ?? 0.0).toDouble(),
      totalKg: (data['totalKg'] ?? 0.0).toDouble(),
      totalCost: (data['totalCost'] ?? 0.0).toDouble(),
      isDeleted: data['isDeleted'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'unit': unit,
      'unitKg': unitKg,
      'sellingPrice': sellingPrice,
      'srpPerKg': srpPerKg,
      'price': price,
      'stock': stock,
      'lowStockThreshold': lowStockThreshold,
      'h1Cost': h1Cost,
      'h1Kg': h1Kg,
      'h2Cost': h2Cost,
      'h2Kg': h2Kg,
      'totalKg': totalKg,
      'totalCost': totalCost,
      'isDeleted': isDeleted,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}