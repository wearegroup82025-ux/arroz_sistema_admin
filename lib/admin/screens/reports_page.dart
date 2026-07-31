import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'order_page.dart'; // Siguraduhing tama ang import path ng OrderModel mo

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  // Arroz Sistema - Fresh Green Theme Palette
  static const Color _greenPrimary = Color(0xff16A34A); // Emerald Green
  static const Color _greenLight = Color(0xffDCFCE7); // Soft Green Accent
  static const Color _bgSage = Color(0xffF4F7F5); // Light Sage Background
  static const Color _cardWhite = Colors.white;
  static const Color _textDark = Color(0xff1E293B);
  static const Color _textSubtle = Color(0xff64748B);
  static const Color _barBg = Color(0xffE2E8F0);

  String _selectedTimeFrame = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgSage,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection("orders").limit(200).snapshots(),
          builder: (context, ordersSnapshot) {
            if (ordersSnapshot.hasError) {
              return Center(child: Text("Error: ${ordersSnapshot.error}"));
            }
            if (ordersSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _greenPrimary));
            }

            final docs = ordersSnapshot.data?.docs ?? [];
            List<OrderModel> allOrders = docs.map((d) => OrderModel.fromFirestore(d)).toList();

            // Status Filter
            List<OrderModel> completedOrders = allOrders.where((o) => o.status == OrderStatus.completed).toList();
            completedOrders = _filterOrdersByTimeFrame(completedOrders, _selectedTimeFrame);

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection("products").snapshots(),
              builder: (context, productsSnapshot) {
                final analytics = _computeAnalytics(completedOrders, productsSnapshot.data?.docs ?? []);

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isDesktop = constraints.maxWidth >= 900;

                    return SingleChildScrollView(
                      padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTopBarHeader(),
                          const SizedBox(height: 20),

                          // MAIN GRID LAYOUT
                          if (isDesktop) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: _buildLeftMainColumn(analytics, completedOrders)),
                                const SizedBox(width: 20),
                                Expanded(flex: 1, child: _buildRightTransactionsColumn(completedOrders)),
                              ],
                            )
                          ] else ...[
                            _buildLeftMainColumn(analytics, completedOrders),
                            const SizedBox(height: 20),
                            _buildRightTransactionsColumn(completedOrders),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ==================== COMPUTATION ENGINE ====================
  Map<String, dynamic> _computeAnalytics(List<OrderModel> orders, List<QueryDocumentSnapshot> productDocs) {
    double totalRevenue = 0;
    int totalItemsSold = 0;
    final Map<String, _ProductStat> productStats = {};

    for (var doc in productDocs) {
      final data = doc.data() as Map<String, dynamic>?;
      final id = doc.id;
      final name = data?['name'] ?? data?['productName'] ?? 'Unknown Variety';
      productStats[id] = _ProductStat(id: id, name: name, salesCount: 0);
    }

    for (var order in orders) {
      totalRevenue += order.totalAmount;
      for (var item in order.items) {
        totalItemsSold += item.quantity;
        String key = item.productId.isNotEmpty ? item.productId : item.productName;

        if (productStats.containsKey(key)) {
          productStats[key]!.salesCount += item.quantity;
        } else {
          productStats[key] = _ProductStat(id: key, name: item.productName, salesCount: item.quantity);
        }
      }
    }

    final sortedStats = productStats.values.toList()..sort((a, b) => b.salesCount.compareTo(a.salesCount));
    int maxSales = sortedStats.isNotEmpty && sortedStats.first.salesCount > 0 ? sortedStats.first.salesCount : 1;

    final topProducts = sortedStats.where((p) => p.salesCount > 0).toList();

    return {
      'totalRevenue': totalRevenue,
      'totalItemsSold': totalItemsSold,
      'ordersCount': orders.length,
      'topProducts': topProducts,
      'maxSales': maxSales,
      'orders': orders,
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

  // ==================== UI BUILDERS (GREEN ARROZ THEME) ====================

  Widget _buildTopBarHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _greenPrimary, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.grass_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("ARROZ MONITOR", style: TextStyle(color: _textDark, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                Text("Rice Sales & Inventory System", style: TextStyle(color: _textSubtle, fontSize: 11)),
              ],
            ),
          ],
        ),
        Row(
          children: [
            _buildHeaderIconButton(Icons.search),
            _buildHeaderIconButton(Icons.notifications_none),
            const SizedBox(width: 8),
            _buildTimeFrameDropdown(),
          ],
        )
      ],
    );
  }

  Widget _buildLeftMainColumn(Map<String, dynamic> analytics, List<OrderModel> orders) {
    return Column(
      children: [
        // 1. SALES MONITOR (BAR CHART)
        _buildBarChartWidget(orders),
        const SizedBox(height: 20),

        // 2. THREE MINI MONITOR CARDS
        Row(
          children: [
            Expanded(child: _buildMiniProgressMonitor("DISPATCHED SACKS", "${analytics['totalItemsSold']} Units", 0.85)),
            const SizedBox(width: 12),
            Expanded(child: _buildMiniProgressMonitor("COMPLETED ORDERS", "${analytics['ordersCount']} Invoices", 0.70)),
            const SizedBox(width: 12),
            Expanded(child: _buildMiniProgressMonitor("TOTAL GROSS", "₱${(analytics['totalRevenue'] as double).toStringAsFixed(0)}", 0.90)),
          ],
        ),
        const SizedBox(height: 20),

        // 3. TWO CIRCULAR DONUT CHART CARDS
        Row(
          children: [
            Expanded(child: _buildDonutChartCard("VARIETY MOVEMENT", "${(analytics['topProducts'] as List).length} Active", 0.80, "RICE STOCKS")),
            const SizedBox(width: 16),
            Expanded(child: _buildDonutChartCard("TOTAL REVENUE", "₱${(analytics['totalRevenue'] as double).toStringAsFixed(0)}", 0.92, "NET EARNINGS")),
          ],
        ),
        const SizedBox(height: 20),

        // 4. TOP SELLING RICE VARIETIES
        _buildRiceVarietyList(analytics),
      ],
    );
  }

  // BAR CHART WIDGET
  Widget _buildBarChartWidget(List<OrderModel> orders) {
    final double maxRev = orders.isNotEmpty ? orders.map((e) => e.totalAmount).reduce((a, b) => a > b ? a : b) : 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("DAILY SALES MONITOR", style: TextStyle(color: _greenPrimary, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
              Icon(Icons.tune_rounded, color: _greenPrimary, size: 18),
            ],
          ),
          const Text("Recent order revenue performance", style: TextStyle(color: _textSubtle, fontSize: 11)),
          const SizedBox(height: 24),
          SizedBox(
            height: 140,
            child: orders.isEmpty
                ? const Center(child: Text("No transaction logs available", style: TextStyle(color: _textSubtle, fontSize: 12)))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(orders.take(8).length, (index) {
                      final order = orders[index];
                      final double heightFactor = maxRev > 0 ? (order.totalAmount / maxRev) : 0.1;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 22,
                            height: 100 * heightFactor < 10 ? 10 : 100 * heightFactor,
                            decoration: BoxDecoration(
                              color: _greenPrimary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text("${order.orderDate.day}/${order.orderDate.month}", style: const TextStyle(fontSize: 10, color: _textSubtle, fontWeight: FontWeight.bold)),
                        ],
                      );
                    }),
                  ),
          ),
        ],
      ),
    );
  }

  // MINI PROGRESS MONITOR CARDS
  Widget _buildMiniProgressMonitor(String title, String value, double progress) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: _greenPrimary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: _textDark, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: _greenLight,
            valueColor: const AlwaysStoppedAnimation<Color>(_greenPrimary),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  // DONUT / RING CHART CARD
  Widget _buildDonutChartCard(String title, String centerText, double percent, String subLabel) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardBoxDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: _greenPrimary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)),
              const Icon(Icons.pie_chart_outline_rounded, color: _greenPrimary, size: 16),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            width: 110,
            child: Stack(
              children: [
                Center(
                  child: SizedBox(
                    height: 100,
                    width: 100,
                    child: CircularProgressIndicator(
                      value: percent,
                      strokeWidth: 12,
                      backgroundColor: _greenLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(_greenPrimary),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(centerText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _textDark)),
                      Text(subLabel, style: const TextStyle(fontSize: 8, color: _textSubtle, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // RIGHT COLUMN: SETTLED TRANSACTIONS
  Widget _buildRightTransactionsColumn(List<OrderModel> orders) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("RECENT TRANSACTIONS", style: TextStyle(color: _greenPrimary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)),
              Icon(Icons.receipt_long_rounded, color: _greenPrimary, size: 16),
            ],
          ),
          const Text("Real-time settled invoices", style: TextStyle(color: _textSubtle, fontSize: 10)),
          const SizedBox(height: 16),
          orders.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text("No transactions recorded.", style: TextStyle(color: _textSubtle, fontSize: 12))),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: orders.take(7).length,
                  separatorBuilder: (_, __) => const Divider(color: _bgSage, height: 16),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return Row(
                      children: [
                        const CircleAvatar(
                          radius: 14,
                          backgroundColor: _greenLight,
                          child: Icon(Icons.shopping_bag_outlined, size: 14, color: _greenPrimary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _textDark)),
                              Text("₱${order.totalAmount.toStringAsFixed(2)}", style: const TextStyle(color: _greenPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const Icon(Icons.check_circle_rounded, color: _greenPrimary, size: 16),
                      ],
                    );
                  },
                )
        ],
      ),
    );
  }

  // TOP SELLING RICE VARIETIES
  Widget _buildRiceVarietyList(Map<String, dynamic> analytics) {
    final topList = analytics['topProducts'] as List<_ProductStat>;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("TOP SELLING RICE VARIETIES", style: TextStyle(color: _greenPrimary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)),
              Icon(Icons.inventory_2_rounded, color: _greenPrimary, size: 16),
            ],
          ),
          const SizedBox(height: 16),
          topList.isEmpty
              ? const Text("No sales recorded yet.", style: TextStyle(color: _textSubtle, fontSize: 12))
              : Column(
                  children: topList.take(5).map((p) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.grain_rounded, color: _greenPrimary, size: 16),
                              const SizedBox(width: 8),
                              Text(p.name, style: const TextStyle(color: _textDark, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(color: _greenLight, borderRadius: BorderRadius.circular(12)),
                            child: Text("${p.salesCount} Dispatched", style: const TextStyle(color: _greenPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
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

  // HELPER STYLES
  BoxDecoration _cardBoxDecoration() {
    return BoxDecoration(
      color: _cardWhite,
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [
        BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 4)),
      ],
    );
  }

  Widget _buildHeaderIconButton(IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Icon(icon, color: _textSubtle, size: 20),
    );
  }

  Widget _buildTimeFrameDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTimeFrame,
          style: const TextStyle(color: _textDark, fontSize: 11, fontWeight: FontWeight.bold),
          onChanged: (v) => setState(() => _selectedTimeFrame = v!),
          items: const [
            DropdownMenuItem(value: 'all', child: Text("All-Time")),
            DropdownMenuItem(value: '7days', child: Text("Last 7 Days")),
            DropdownMenuItem(value: '30days', child: Text("Last 30 Days")),
          ],
        ),
      ),
    );
  }
}

class _ProductStat {
  final String id;
  final String name;
  int salesCount;

  _ProductStat({required this.id, required this.name, required this.salesCount});
}