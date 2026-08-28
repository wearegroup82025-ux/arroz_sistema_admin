import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String? id;
  final String name;
  final String category;
  final String unit; // kilo or sako
  final double unitKg;
  final double sellingPrice;
  final double price;
  final int stock;
  final int lowStockThreshold;
  final DateTime? createdAt;

  // Getter para sa metricDetail upang maging compatible sa lumang code
  String get metricDetail => "$unit ($unitKg kg)";

  ProductModel({
    this.id,
    required this.name,
    required this.category,
    this.unit = "Sako",
    this.unitKg = 50.0,
    required this.sellingPrice,
    this.price = 0.0,
    required this.stock,
    this.lowStockThreshold = 10,
    this.createdAt,
  });

  // ... natitirang fromFirestore at toFirestore code


  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    
    // Iniiwasan ang null errors sa pamamagitan ng paglalagay ng default fallback values
    double fetchedSellingPrice = (data['sellingPrice'] ?? data['price'] ?? 0.0).toDouble();
    
    return ProductModel(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? 'Regular',
      unit: data['unit'] ?? 'Sako',
      unitKg: (data['unitKg'] ?? 50.0).toDouble(),
      sellingPrice: fetchedSellingPrice,
      price: (data['price'] ?? fetchedSellingPrice).toDouble(),
      stock: (data['stock'] ?? 0).toInt(),
      lowStockThreshold: (data['lowStockThreshold'] ?? 10).toInt(),
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
      'price': price,
      'stock': stock,
      'lowStockThreshold': lowStockThreshold,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}