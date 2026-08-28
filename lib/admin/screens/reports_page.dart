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
  static const Color _primaryGreen = Color(0xFF16A34A);
  static const Color _bgCanvas = Color(0xFFF8FAFC);
  static const Color _cardBg = Colors.white;
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _amberAlert = Color(0xFFD97706);
  static const Color _dangerRed = Color(0xFFDC2626);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _infoBlue = Color(0xFF2563EB);

  // Timeframe Filter State
  String _selectedTimeFrame = 'today';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgCanvas,
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        title: const Text(
          "Ulat sa Benta at Kita",
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
              return Center(child: Text("Error sa Orders: ${ordersSnapshot.error}"));
            }
            if (ordersSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _primaryGreen));
            }

            final orderDocs = ordersSnapshot.data?.docs ?? [];
            List<OrderModel> allOrders = orderDocs.map((d) => OrderModel.fromFirestore(d)).toList();

            // KUMPUNI 1: Completed orders lang ang kukuhaan ng kita at puhunan
            List<OrderModel> validOrders = allOrders.where((o) {
              return o.status == OrderStatus.completed;
            }).toList();

            // Filter ayon sa napiling timeframe
            List<OrderModel> filteredOrders = _filterOrdersByTimeFrame(validOrders, _selectedTimeFrame);

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection("products").snapshots(),
              builder: (context, productsSnapshot) {
                if (productsSnapshot.connectionState == ConnectionState.waiting && !productsSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: _primaryGreen));
                }

                final productDocs = productsSnapshot.data?.docs ?? [];
                List<ProductModel> products = productDocs.map((d) => ProductModel.fromFirestore(d)).toList();

                // Compute real-time analytics
                final analytics = _computeAnalytics(filteredOrders, products);

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOverallSummaryCard(analytics),
                      const SizedBox(height: 16),
                      _buildBreakdownSection(analytics),
                      const SizedBox(height: 16),
                      _buildQuickMetrics(analytics, filteredOrders.length),
                      const SizedBox(height: 16),
                      _buildDailySalesBreakdown(filteredOrders),
                      const SizedBox(height: 16),
                      _buildProductStockSection(analytics),
                      const SizedBox(height: 16),
                      _buildRecentTransactions(filteredOrders),
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
    double overallRevenue = 0.0;
    double overallCost = 0.0;

    double kiloRevenue = 0.0;
    double kiloCost = 0.0;
    double totalKilosSold = 0.0;

    double sakoRevenue = 0.0;
    double sakoCost = 0.0;
    int totalSakoSold = 0;

    int lowStockCount = 0;
    final Map<String, _ProductStat> productStats = {};

    // Map existing products for fast reference
    final Map<String, ProductModel> productMap = {};
    for (var p in products) {
      if (p.id != null) productMap[p.id!] = p;
      productMap[p.name.trim().toLowerCase()] = p;

      if (p.stock <= p.lowStockThreshold) {
        lowStockCount++;
      }

      productStats[p.id ?? p.name] = _ProductStat(
        name: p.name,
        metricDetail: p.metricDetail,
        salesCount: 0,
        currentStock: p.stock,
        lowStockThreshold: p.lowStockThreshold,
        totalRevenue: 0.0,
      );
    }

    for (var order in orders) {
      for (var item in order.items) {
        // Presyo ng naibenta mula sa order item
        double itemSellingPrice = item.pricePerUnit;
        final int qty = item.quantity;
        final double lineRevenue = itemSellingPrice * qty;

        // Kunin ang Product Reference batay sa Product ID o Pangalan
        String productId = item.productId;
        String rawProductName = item.productName.trim();

        // Linisin ang pangalan sakaling may variation tag tulad ng "Rice Name (Sako)"
        String cleanProductName = rawProductName
            .replaceAll(RegExp(r'\s*\((Sako|Kilo|sako|kilo)\)'), '')
            .trim()
            .toLowerCase();

        ProductModel? refProduct = productMap[productId] ?? productMap[cleanProductName] ?? productMap[rawProductName.toLowerCase()];

        // Weight/KG per Sako setup
        double unitKg = (refProduct != null && refProduct.unitKg > 0) ? refProduct.unitKg : 50.0;

        // DYNAMIC PUHUNAN (COST PRICE):
        // Puhunan bawat sako batay sa dynamic data ng product model
        double costPerSako = refProduct?.price ?? 0.0;

        // KUMPUNI 2: Tiyaking tumpak ang Unit Checking (Per Sako vs Per Kilo)
        String itemUnit = item.unit.toLowerCase();
        String lowerItemName = rawProductName.toLowerCase();

        bool isSakoOrder = itemUnit.contains("sako") ||
            lowerItemName.endsWith("(sako)") ||
            lowerItemName.contains("per sako");

        double lineCost = 0.0;

        if (isSakoOrder) {
          // Benta at Puhunan para sa SAKO
          lineCost = costPerSako * qty;
          sakoRevenue += lineRevenue;
          sakoCost += lineCost;
          totalSakoSold += qty;
        } else {
          // Benta at Puhunan para sa KILO
          double costPerKilo = unitKg > 0 ? (costPerSako / unitKg) : 0.0;
          lineCost = costPerKilo * qty;
          kiloRevenue += lineRevenue;
          kiloCost += lineCost;
          totalKilosSold += qty;
        }

        overallRevenue += lineRevenue;
        overallCost += lineCost;

        String statKey = productId.isNotEmpty && productStats.containsKey(productId)
            ? productId
            : cleanProductName;

        if (productStats.containsKey(statKey)) {
          productStats[statKey]!.salesCount += qty;
          productStats[statKey]!.totalRevenue += lineRevenue;
        }
      }
    }

    final overallProfit = overallRevenue - overallCost;
    final kiloProfit = kiloRevenue - kiloCost;
    final sakoProfit = sakoRevenue - sakoCost;

    final topProducts = productStats.values.toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    return {
      'overallRevenue': overallRevenue,
      'overallCost': overallCost,
      'overallProfit': overallProfit,

      'kiloRevenue': kiloRevenue,
      'kiloCost': kiloCost,
      'kiloProfit': kiloProfit,
      'totalKilosSold': totalKilosSold,

      'sakoRevenue': sakoRevenue,
      'sakoCost': sakoCost,
      'sakoProfit': sakoProfit,
      'totalSakoSold': totalSakoSold,

      'lowStockCount': lowStockCount,
      'topProducts': topProducts,
    };
  }

  // DYNAMIC TIMEFRAME FILTERING LOGIC
  List<OrderModel> _filterOrdersByTimeFrame(List<OrderModel> orders, String timeFrame) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    if (timeFrame == 'today') {
      return orders.where((o) => o.orderDate.isAfter(todayStart)).toList();
    } else if (timeFrame == 'yesterday') {
      final yesterdayStart = todayStart.subtract(const Duration(days: 1));
      return orders.where((o) => o.orderDate.isAfter(yesterdayStart) && o.orderDate.isBefore(todayStart)).toList();
    } else if (timeFrame == '7days') {
      final sevenDaysAgo = todayStart.subtract(const Duration(days: 7));
      return orders.where((o) => o.orderDate.isAfter(sevenDaysAgo)).toList();
    } else if (timeFrame == '30days') {
      final thirtyDaysAgo = todayStart.subtract(const Duration(days: 30));
      return orders.where((o) => o.orderDate.isAfter(thirtyDaysAgo)).toList();
    } else if (timeFrame == 'this_month') {
      final monthStart = DateTime(now.year, now.month, 1);
      return orders.where((o) => o.orderDate.isAfter(monthStart)).toList();
    }
    return orders; // 'all' time
  }

  // UI COMPONENTS

  Widget _buildOverallSummaryCard(Map<String, dynamic> analytics) {
    final double revenue = analytics['overallRevenue'];
    final double cost = analytics['overallCost'];
    final double profit = analytics['overallProfit'];
    final bool isLoss = profit < 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "KABUUANG TALAAN NG NEGOSYO",
                style: TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isLoss ? _dangerRed : _primaryGreen).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isLoss ? "LUGI NGAYON" : "MAY TUBO",
                  style: TextStyle(
                    color: isLoss ? _dangerRed : _primaryGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            isLoss ? "Kabuuang Lugi" : "Kabuuang Malinis na Kita (Net Profit)",
            style: const TextStyle(fontSize: 12, color: _textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            _formatCurrency(profit.abs()),
            style: TextStyle(
              color: isLoss ? _dangerRed : _primaryGreen,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(height: 24, color: _borderColor),

          Row(
            children: [
              Expanded(
                child: _buildSummarySubTile(
                  label: "Kabuuang Benta",
                  value: _formatCurrency(revenue),
                  color: _textDark,
                  icon: Icons.payments_outlined,
                ),
              ),
              Container(height: 30, width: 1, color: _borderColor),
              Expanded(
                child: _buildSummarySubTile(
                  label: "Kabuuang Puhunan",
                  value: _formatCurrency(cost),
                  color: _textMuted,
                  icon: Icons.shopping_bag_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySubTile({required String label, required String value, required Color color, required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: _textMuted),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 10, color: _textMuted)),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownSection(Map<String, dynamic> analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Hiwalay na Benta at Tubo (Per Unit)",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textDark),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildUnitReportCard(
                title: "PER KILO BENTA",
                badgeLabel: "${analytics['totalKilosSold'].toStringAsFixed(0)} Kg Naibenta",
                revenue: analytics['kiloRevenue'],
                cost: analytics['kiloCost'],
                profit: analytics['kiloProfit'],
                accentColor: _infoBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildUnitReportCard(
                title: "PER SAKO BENTA",
                badgeLabel: "${analytics['totalSakoSold']} Sako Naibenta",
                revenue: analytics['sakoRevenue'],
                cost: analytics['sakoCost'],
                profit: analytics['sakoProfit'],
                accentColor: _primaryGreen,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUnitReportCard({
    required String title,
    required String badgeLabel,
    required double revenue,
    required double cost,
    required double profit,
    required Color accentColor,
  }) {
    final bool isLoss = profit < 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accentColor)),
              Icon(Icons.inventory_2_outlined, size: 14, color: accentColor),
            ],
          ),
          const SizedBox(height: 4),
          Text(badgeLabel, style: const TextStyle(fontSize: 10, color: _textMuted, fontWeight: FontWeight.w500)),
          const Divider(height: 16, color: _borderColor),

          const Text("Benta:", style: TextStyle(fontSize: 9, color: _textMuted)),
          Text(_formatCurrency(revenue), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textDark)),
          const SizedBox(height: 6),

          const Text("Puhunan:", style: TextStyle(fontSize: 9, color: _textMuted)),
          Text(_formatCurrency(cost), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textMuted)),
          const SizedBox(height: 6),

          Text(isLoss ? "Lugi:" : "Tubó:", style: TextStyle(fontSize: 9, color: isLoss ? _dangerRed : _primaryGreen, fontWeight: FontWeight.bold)),
          Text(
            "${profit >= 0 ? '+' : ''}${_formatCurrency(profit)}",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isLoss ? _dangerRed : _primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickMetrics(Map<String, dynamic> analytics, int orderCount) {
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
                const Icon(Icons.shopping_bag_outlined, color: _primaryGreen, size: 20),
                const SizedBox(height: 8),
                Text("$orderCount", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textDark)),
                const Text("Bilang ng Order", style: TextStyle(fontSize: 11, color: _textMuted)),
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
                Icon(Icons.warning_amber_rounded, color: lowStock > 0 ? _amberAlert : _primaryGreen, size: 20),
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
            child: Text("Walang rekord ng benta sa napiling petsa.", style: TextStyle(fontSize: 11, color: _textMuted)),
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
                        Text(_formatCurrency(e.value), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _primaryGreen)),
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
          const Text("Benta at Tira sa Inbentaryo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _textDark)),
          const SizedBox(height: 12),
          topProducts.isEmpty
              ? const Text("Walang produkto sa listahan.", style: TextStyle(fontSize: 11, color: _textMuted))
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
                            p.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: _textDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Naibenta: ${p.salesCount} • Benta: ${_formatCurrency(p.totalRevenue)}",
                            style: const TextStyle(fontSize: 10, color: _textMuted),
                          ),
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
                        isLow ? "Low: ${p.currentStock}" : "Stock: ${p.currentStock}",
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
          const Text("Mga Transaksyon", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _textDark)),
          const SizedBox(height: 10),
          orders.isEmpty
              ? const Text("Walang transaksyon sa napiling petsa.", style: TextStyle(fontSize: 11, color: _textMuted))
              : ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.take(5).length,
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
                  Text(_formatCurrency(order.totalAmount), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _primaryGreen)),
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
        icon: const Icon(Icons.filter_alt_rounded, size: 16, color: _primaryGreen),
        style: const TextStyle(color: _textDark, fontSize: 11, fontWeight: FontWeight.w600),
        onChanged: (v) {
          if (v != null) setState(() => _selectedTimeFrame = v);
        },
        items: const [
          DropdownMenuItem(value: 'today', child: Text("Ngayong Araw")),
          DropdownMenuItem(value: 'yesterday', child: Text("Kahapon")),
          DropdownMenuItem(value: '7days', child: Text("Huling 7 Araw")),
          DropdownMenuItem(value: '30days', child: Text("Huling 30 Araw")),
          DropdownMenuItem(value: 'this_month', child: Text("Ngayong Buwan")),
          DropdownMenuItem(value: 'all', child: Text("Lahat (All Time)")),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    return "₱${amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => "${m[1]},",
    )}";
  }
}

class _ProductStat {
  final String name;
  final String metricDetail;
  int salesCount;
  int currentStock;
  int lowStockThreshold;
  double totalRevenue;

  _ProductStat({
    required this.name,
    required this.metricDetail,
    required this.salesCount,
    required this.currentStock,
    required this.lowStockThreshold,
    required this.totalRevenue,
  });
}