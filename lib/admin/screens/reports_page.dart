import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'order_page.dart'; // Ensure correct path for OrderModel

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  static const Color _primaryBlue = Color(0xff2563EB);
  static const Color _successGreen = Color(0xff16A34A);
  static const Color _bgSurface = Color(0xffF8FAFC);
  static const Color _textPrimary = Color(0xff0F172A);
  static const Color _textSecondary = Color(0xff64748B);
  static const Color _border = Color(0xffE2E8F0);

  // Time-frame filter state: '7days', '30days', 'all'
  String _selectedTimeFrame = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgSurface,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("orders")
              .where('status', isEqualTo: 'completed')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _primaryBlue));
            }

            final docs = snapshot.data?.docs ?? [];
            List<OrderModel> completedOrders = docs.map((d) => OrderModel.fromFirestore(d)).toList();

            // Local filtering base sa napiling Time-frame
            completedOrders = _filterOrdersByTimeFrame(completedOrders, _selectedTimeFrame);

            // Compute Analytical Metrics
            final double totalRevenue = completedOrders.fold(0.0, (sum, item) => sum + item.totalAmount);
            
            int totalSacksSold = 0;
            final Map<String, int> productPerformance = {};

            for (var order in completedOrders) {
              for (var item in order.items) {
                totalSacksSold += item.quantity;
                productPerformance[item.productName] = (productPerformance[item.productName] ?? 0) + item.quantity;
              }
            }

            final sortedProducts = productPerformance.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            return LayoutBuilder(
              builder: (context, constraints) {
                final bool isMobile = constraints.maxWidth < 768;

                return SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HEADER LOGISTICS LAYER
                      _buildHeader(isMobile),
                      const SizedBox(height: 20),

                      // EXECUTIVE KPI SUMMARY METRICS
                      _buildMetricCardsGrid(
                        isMobile: isMobile,
                        totalRevenue: totalRevenue,
                        totalSacksSold: totalSacksSold,
                        ordersCount: completedOrders.length,
                      ),
                      const SizedBox(height: 24),

                      // TWO-SEGMENT CONTENT SECTION
                      if (isMobile) ...[
                        _SectionWrapper(
                          title: "Product Volume Leaderboard",
                          subtitle: "Ranking by total sacks dispatched",
                          child: sortedProducts.isEmpty
                              ? _buildEmptyState()
                              : Column(
                                  children: List.generate(
                                    sortedProducts.length,
                                    (index) => Padding(
                                      padding: const EdgeInsets.only(bottom: 12.0),
                                      child: _ProductRankRow(
                                        rank: index + 1,
                                        name: sortedProducts[index].key,
                                        sacks: sortedProducts[index].value,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 20),
                        _SectionWrapper(
                          title: "Audit Trail Ledger",
                          subtitle: "Latest compiled closed transactions",
                          child: completedOrders.isEmpty
                              ? _buildEmptyState()
                              : Column(
                                  children: List.generate(
                                    completedOrders.length,
                                    (index) => _LedgerItem(order: completedOrders[index]),
                                  ),
                                ),
                        ),
                      ] else ...[
                        SizedBox(
                          height: 500, // Fixed dynamic height for desktop views
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // LEFT PANEL: Product Distribution Performance
                              Expanded(
                                flex: 2,
                                child: _SectionWrapper(
                                  title: "Product Volume Leaderboard",
                                  subtitle: "Ranking by total sacks dispatched",
                                  child: sortedProducts.isEmpty
                                      ? _buildEmptyState()
                                      : ListView.separated(
                                          itemCount: sortedProducts.length,
                                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                                          itemBuilder: (context, index) {
                                            final entry = sortedProducts[index];
                                            return _ProductRankRow(
                                              rank: index + 1,
                                              name: entry.key,
                                              sacks: entry.value,
                                            );
                                          },
                                        ),
                                ),
                              ),
                              const SizedBox(width: 24),

                              // RIGHT PANEL: Recent Revenue Micro-logs
                              Expanded(
                                flex: 3,
                                child: _SectionWrapper(
                                  title: "Audit Trail Ledger",
                                  subtitle: "Latest compiled closed transactions",
                                  child: completedOrders.isEmpty
                                      ? _buildEmptyState()
                                      : ListView.separated(
                                          itemCount: completedOrders.length,
                                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                                          itemBuilder: (context, index) {
                                            return _LedgerItem(order: completedOrders[index]);
                                          },
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  // ==================== DATA PROCESSING ====================
  List<OrderModel> _filterOrdersByTimeFrame(List<OrderModel> orders, String timeFrame) {
    final now = DateTime.now();
    if (timeFrame == '7days') {
      return orders.where((o) => now.difference(o.orderDate).inDays <= 7).toList();
    } else if (timeFrame == '30days') {
      return orders.where((o) => now.difference(o.orderDate).inDays <= 30).toList();
    }
    return orders;
  }

  // ==================== RESPONSIVE HEADER ====================
  Widget _buildHeader(bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Financial & Sales Intelligence",
            style: TextStyle(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          const Text(
            "Real-time performance distribution and volume metrics.",
            style: TextStyle(color: _textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: _buildTimeFrameDropdown(),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Financial & Sales Intelligence",
              style: TextStyle(color: _textPrimary, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
            Text(
              "Real-time performance distribution and volume metrics.",
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
          ],
        ),
        _buildTimeFrameDropdown(),
      ],
    );
  }

  // ==================== METRICS GRID ====================
  Widget _buildMetricCardsGrid({
    required bool isMobile,
    required double totalRevenue,
    required int totalSacksSold,
    required int ordersCount,
  }) {
    final cards = [
      _MetricCard(title: "Gross Revenue", value: "₱ ${totalRevenue.toStringAsFixed(2)}", icon: Icons.payments_outlined, color: _successGreen),
      _MetricCard(title: "Sacks Distributed", value: "$totalSacksSold Sacks", icon: Icons.inventory_2_outlined, color: _primaryBlue),
      _MetricCard(title: "Invoices Settled", value: "$ordersCount Orders", icon: Icons.receipt_long_outlined, color: Colors.purple),
    ];

    if (isMobile) {
      return Column(
        children: cards.map((card) => Padding(padding: const EdgeInsets.only(bottom: 12.0), child: card)).toList(),
      );
    }

    return Row(
      children: cards.map((card) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6.0), child: card))).toList(),
    );
  }

  Widget _buildTimeFrameDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTimeFrame,
          icon: const Icon(Icons.calendar_today_outlined, size: 14, color: _textSecondary),
          style: const TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
          onChanged: (String? newValue) {
            if (newValue != null) setState(() => _selectedTimeFrame = newValue);
          },
          items: const [
            DropdownMenuItem(value: 'all', child: Text("All-Time Historical  ")),
            DropdownMenuItem(value: '7days', child: Text("Last 7 Days  ")),
            DropdownMenuItem(value: '30days', child: Text("Last 30 Days  ")),
          ],
        ),
      ),
    );
  }

  static Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24.0),
        child: Text(
          "No transaction metrics recorded for this interval.",
          style: TextStyle(color: _textSecondary, fontSize: 13),
        ),
      ),
    );
  }
}

// ==================== EXTRACTED PERFORMANCE COMPONENTS ====================

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            radius: 20,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Color(0xff64748B), fontSize: 12, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: Color(0xff0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _SectionWrapper extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionWrapper({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(color: Color(0xff0F172A), fontSize: 15, fontWeight: FontWeight.bold)),
          Text(subtitle, style: const TextStyle(color: Color(0xff64748B), fontSize: 12)),
          const Divider(height: 24, color: Color(0xffE2E8F0)),
          Flexible(fit: FlexFit.loose, child: child),
        ],
      ),
    );
  }
}

class _ProductRankRow extends StatelessWidget {
  final int rank;
  final String name;
  final int sacks;

  const _ProductRankRow({
    required this.rank,
    required this.name,
    required this.sacks,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xffF8FAFC), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rank == 1 ? const Color(0xffFEF3C7) : const Color(0xffE2E8F0),
              shape: BoxShape.circle,
            ),
            child: Text(
              "$rank",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: rank == 1 ? const Color(0xffD97706) : const Color(0xff0F172A),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xff0F172A)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text("$sacks Sacks", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xff2563EB))),
        ],
      ),
    );
  }
}

class _LedgerItem extends StatelessWidget {
  final OrderModel order;

  const _LedgerItem({required this.order});

  @override
  Widget build(BuildContext context) {
    final displayId = order.id.length >= 6 ? order.id.substring(0, 6) : order.id;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xffF8FAFC)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("ID: #${displayId.toUpperCase()}", style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  order.customerName,
                  style: const TextStyle(color: Color(0xff64748B), fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            "+₱${order.totalAmount.toStringAsFixed(2)}",
            style: const TextStyle(color: Color(0xff16A34A), fontWeight: FontWeight.bold, fontSize: 14),
          )
        ],
      ),
    );
  }
}