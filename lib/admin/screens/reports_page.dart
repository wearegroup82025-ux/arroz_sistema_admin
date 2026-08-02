import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'order_page.dart';   
import '../../models/product_model.dart'; 

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  static const Color _primaryGreen = Color(0xff16A34A);
  static const Color _bgCanvas = Color(0xffF8FAFC);
  static const Color _cardBg = Colors.white;
  static const Color _textDark = Color(0xff0F172A);
  static const Color _textMuted = Color(0xff64748B);
  static const Color _amberAlert = Color(0xffD97706);
  static const Color _borderColor = Color(0xffE2E8F0);

  String _selectedTimeFrame = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgCanvas,
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        title: const Text(
          "Admin Reports",
          style: TextStyle(color: _textDark, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildTimeFrameFilter(),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection("orders").snapshots(),
          builder: (context, ordersSnapshot) {
            if (ordersSnapshot.hasError) {
              return Center(child: Text("Error: ${ordersSnapshot.error}"));
            }
            if (ordersSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _primaryGreen));
            }

            final orderDocs = ordersSnapshot.data?.docs ?? [];
            List<OrderModel> allOrders = orderDocs.map((d) => OrderModel.fromFirestore(d)).toList();

            // Kasama sa Benta ang 'Completed' O 'ToReceive' / 'ToShip' kapag valid benta
            List<OrderModel> completedOrders = allOrders.where((o) => o.status == OrderStatus.completed).toList();
            completedOrders = _filterOrdersByTimeFrame(completedOrders, _selectedTimeFrame);

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection("products").snapshots(),
              builder: (context, productsSnapshot) {
                if (productsSnapshot.connectionState == ConnectionState.waiting && !productsSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: _primaryGreen));
                }

                final productDocs = productsSnapshot.data?.docs ?? [];
                List<ProductModel> products = productDocs.map((d) => ProductModel.fromFirestore(d)).toList();

                final analytics = _computeAnalytics(completedOrders, products);

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRevenueHeroCard(analytics),
                      const SizedBox(height: 14),
                      _buildQuickMetrics(analytics),
                      const SizedBox(height: 16),
                      _buildDailySalesBreakdown(completedOrders),
                      const SizedBox(height: 16),
                      _buildProductStockSection(analytics),
                      const SizedBox(height: 16),
                      _buildRecentTransactions(completedOrders),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Map<String, dynamic> _computeAnalytics(List<OrderModel> orders, List<ProductModel> products) {
    double totalRevenue = 0;
    int totalItemsSold = 0;
    int lowStockCount = 0;
    final Map<String, _ProductStat> productStats = {};

    for (var product in products) {
      final id = product.id ?? product.name;
      if (product.stock <= product.lowStockThreshold) {
        lowStockCount++;
      }
      productStats[id] = _ProductStat(
        name: product.name,
        metricDetail: product.metricDetail,
        salesCount: 0,
        currentStock: product.stock,
        lowStockThreshold: product.lowStockThreshold,
      );
    }

    for (var order in orders) {
      totalRevenue += order.totalAmount;
      for (var item in order.items) {
        totalItemsSold += item.quantity;
        String key = item.productId.isNotEmpty ? item.productId : item.productName;
        if (productStats.containsKey(key)) {
          productStats[key]!.salesCount += item.quantity;
        }
      }
    }

    final topProducts = productStats.values.toList()
      ..sort((a, b) => b.salesCount.compareTo(a.salesCount));

    return {
      'totalRevenue': totalRevenue,
      'totalItemsSold': totalItemsSold,
      'ordersCount': orders.length,
      'lowStockCount': lowStockCount,
      'topProducts': topProducts,
    };
  }

  List<OrderModel> _filterOrdersByTimeFrame(List<OrderModel> orders, String timeFrame) {
    final now = DateTime.now();
    if (timeFrame == '7days') {
      return orders.where((o) => now.difference(o.orderDate).inDays <= 7).toList();
    } else if (timeFrame == '30days') {
      return orders.where((o) => now.difference(o.orderDate).inDays <= 30).toList();
    }
    return orders;
  }

  Widget _buildRevenueHeroCard(Map<String, dynamic> analytics) {
    final double revenue = analytics['totalRevenue'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _primaryGreen,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryGreen.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Kabuuang Benta (Completed Sales)",
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            "₱${revenue.toStringAsFixed(2)}",
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Text(
                "${analytics['ordersCount']} Naiproseso at Bayad na Orders",
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildQuickMetrics(Map<String, dynamic> analytics) {
    final int lowStock = analytics['lowStockCount'];

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shopping_basket_outlined, color: _primaryGreen, size: 20),
                const SizedBox(height: 8),
                Text("${analytics['totalItemsSold']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textDark)),
                const Text("Naibentang Yunit", style: TextStyle(fontSize: 11, color: _textMuted)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.inventory_2_outlined, color: lowStock > 0 ? _amberAlert : _primaryGreen, size: 20),
                const SizedBox(height: 8),
                Text("$lowStock", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: lowStock > 0 ? _amberAlert : _textDark)),
                const Text("Low Stock Alert", style: TextStyle(fontSize: 11, color: _textMuted)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDailySalesBreakdown(List<OrderModel> orders) {
    Map<String, double> dailyTotals = {};
    for (var order in orders) {
      String dateKey = "${order.orderDate.day}/${order.orderDate.month}";
      dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0) + order.totalAmount;
    }

    final entries = dailyTotals.entries.toList().take(5).toList();
    double maxDaily = entries.isNotEmpty 
        ? entries.map((e) => e.value).reduce((a, b) => a > b ? a : b) 
        : 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Benta Bawat Araw", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _textDark)),
          const SizedBox(height: 12),
          entries.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text("Walang rekord ng benta sa panahong ito.", style: TextStyle(fontSize: 11, color: _textMuted)),
                )
              : Column(
                  children: entries.map((e) {
                    double progress = (e.value / maxDaily).clamp(0.05, 1.0);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _textDark)),
                              Text("₱${e.value.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _primaryGreen)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: _bgCanvas,
                              valueColor: const AlwaysStoppedAnimation<Color>(_primaryGreen),
                              minHeight: 6,
                            ),
                          )
                        ],
                      ),
                    );
                  }).toList(),
                )
        ],
      ),
    );
  }

  Widget _buildProductStockSection(Map<String, dynamic> analytics) {
    final topProducts = analytics['topProducts'] as List<_ProductStat>;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Status ng Stocks at Naibenta", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _textDark)),
          const SizedBox(height: 12),
          topProducts.isEmpty
              ? const Text("Walang available na produkto.", style: TextStyle(fontSize: 11, color: _textMuted))
              : Column(
                  children: topProducts.take(5).map((p) {
                    bool isLow = p.currentStock <= p.lowStockThreshold;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.metricDetail.isNotEmpty ? "${p.name} (${p.metricDetail})" : p.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: _textDark),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text("Naibenta: ${p.salesCount} pcs", style: const TextStyle(fontSize: 10, color: _textMuted)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isLow ? _amberAlert.withOpacity(0.1) : _primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isLow ? "Low Stock: ${p.currentStock}" : "Stock: ${p.currentStock}",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isLow ? _amberAlert : _primaryGreen,
                              ),
                            ),
                          )
                        ],
                      ),
                    );
                  }).toList(),
                )
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(List<OrderModel> orders) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Huling Transaksyon", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _textDark)),
          const SizedBox(height: 10),
          orders.isEmpty
              ? const Text("Wala pang transaksyon.", style: TextStyle(fontSize: 11, color: _textMuted))
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: orders.take(4).length,
                  separatorBuilder: (_, __) => const Divider(height: 12, color: _borderColor),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order.customerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textDark), overflow: TextOverflow.ellipsis),
                              Text("${order.orderDate.day}/${order.orderDate.month}/${order.orderDate.year}", style: const TextStyle(fontSize: 9, color: _textMuted)),
                            ],
                          ),
                        ),
                        Text("₱${order.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _primaryGreen)),
                      ],
                    );
                  },
                )
        ],
      ),
    );
  }

  Widget _buildTimeFrameFilter() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _selectedTimeFrame,
        icon: const Icon(Icons.tune_rounded, size: 16, color: _primaryGreen),
        style: const TextStyle(color: _textDark, fontSize: 11, fontWeight: FontWeight.w600),
        onChanged: (v) {
          if (v != null) setState(() => _selectedTimeFrame = v);
        },
        items: const [
          DropdownMenuItem(value: 'all', child: Text("Lahat")),
          DropdownMenuItem(value: '7days', child: Text("7 Araw")),
          DropdownMenuItem(value: '30days', child: Text("30 Araw")),
        ],
      ),
    );
  }
}

class _ProductStat {
  final String name;
  final String metricDetail;
  int salesCount;
  int currentStock;
  int lowStockThreshold;

  _ProductStat({
    required this.name,
    required this.metricDetail,
    required this.salesCount,
    required this.currentStock,
    required this.lowStockThreshold,
  });
}