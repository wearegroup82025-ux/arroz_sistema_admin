import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  static const Color _surfaceBg = Color(0xFFF8FAFC);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _primaryGreen = Color(0xFF16A34A);
  static const Color _primaryGreenSoft = Color(0xFFDCFCE7);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _borderLine = Color(0xFFE2E8F0);
  
  static const Color _warningOrange = Color(0xFFD97706);
  static const Color _dangerRed = Color(0xFFDC2626);
  static const Color _dangerRedBg = Color(0xFFFEE2E2);
  static const Color _infoBlue = Color(0xFF2563EB);
  static const Color _infoBlueBg = Color(0xFFEFF6FF);

  late final TextEditingController _searchController;
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>("");

  final List<String> _riceTypes = ["Hybrid", "Inbred"];
  final List<String> _riceConditions = ["Basa", "Tuyo", "Sariwa"];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    return "₱${amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => "${m[1]},",
    )}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceBg,
      floatingActionButton: FloatingActionButton.extended(
        elevation: 3,
        backgroundColor: _primaryGreen,
        onPressed: () => _showAddHarvestModal(context),
        icon: const Icon(Icons.add_box_rounded, color: Colors.white, size: 20),
        label: const Text(
          "Mag-input ng Ani & Puhunan",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection("products").snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text("May error sa database.", style: TextStyle(color: _dangerRed, fontWeight: FontWeight.bold)),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _primaryGreen));
            }

            final docs = snapshot.data?.docs ?? [];

            double totalValuation = 0.0;
            double totalOverallProfit = 0.0;
            int totalStockKg = 0;

            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>? ?? {};
              if (data['isDeleted'] == true) continue;

              final double currentTotalKg = ((data['totalKg'] ?? 0.0) as num).toDouble();
              final srp = (data['srpPerKg'] ?? 0.0).toDouble();
              final totalCost = (data['totalCost'] ?? 0.0).toDouble();

              final totalRevenue = currentTotalKg * srp;
              final totalProfit = totalRevenue - totalCost;

              totalValuation += totalRevenue;
              totalOverallProfit += totalProfit;
              totalStockKg += currentTotalKg.toInt();
            }

            return Column(
              children: [
                _buildHeaderAndAnalytics(
                  totalValue: totalValuation,
                  totalProfit: totalOverallProfit,
                  totalStockKg: totalStockKg,
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: ValueListenableBuilder<String>(
                    valueListenable: _searchQueryNotifier,
                    builder: (context, queryValue, child) {
                      return TextField(
                        controller: _searchController,
                        onChanged: (val) => _searchQueryNotifier.value = val,
                        decoration: InputDecoration(
                          hintText: "Maghanap ng uri (e.g. Hybrid, Tuyo)...",
                          hintStyle: const TextStyle(fontSize: 13, color: _textSecondary),
                          prefixIcon: const Icon(Icons.search_rounded, color: _textSecondary, size: 20),
                          suffixIcon: queryValue.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18, color: _textSecondary),
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchQueryNotifier.value = "";
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: _cardBg,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _borderLine),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _primaryGreen, width: 1.5),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: _searchQueryNotifier,
                    builder: (context, query, child) {
                      final filteredDocs = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>? ?? {};
                        if (data['isDeleted'] == true) return false;
                        final name = (data['name'] ?? '').toString().toLowerCase();
                        return name.contains(query.toLowerCase());
                      }).toList();

                      if (filteredDocs.isEmpty) {
                        return const Center(
                          child: Text("Walang nahanap na record sa inbentaryo.",
                              style: TextStyle(color: _textSecondary, fontSize: 13)),
                        );
                      }

                      return ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
                        itemCount: filteredDocs.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _buildFarmerInventoryCard(filteredDocs[index]);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderAndAnalytics({
    required double totalValue,
    required double totalProfit,
    required int totalStockKg,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: _cardBg,
        border: Border(bottom: BorderSide(color: _borderLine)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Smart Farm Inventory",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary)),
                  SizedBox(height: 2),
                  Text("Kuwenta ng Puhunan, Tubó at Benta sa Hectare 1 & 2",
                      style: TextStyle(fontSize: 12, color: _textSecondary)),
                ],
              ),
              Icon(Icons.agriculture_rounded, color: _primaryGreen, size: 28),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMetricCard("Kabuuang Kita", _formatCurrency(totalValue), Icons.account_balance_wallet_outlined, _infoBlue),
              const SizedBox(width: 8),
              _buildMetricCard("Kabuuang Ani", "$totalStockKg kg", Icons.scale_outlined, _primaryGreen),
              const SizedBox(width: 8),
              _buildMetricCard("Kabuuang Tubó", _formatCurrency(totalProfit), Icons.trending_up_rounded, totalProfit >= 0 ? _primaryGreen : _dangerRed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _surfaceBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: accentColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 10, color: _textSecondary, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accentColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmerInventoryCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final String name = data['name'] ?? "Palay Item";
    final double srp = (data['srpPerKg'] ?? 0.0).toDouble();

    final double h1Cost = (data['h1Cost'] ?? 0.0).toDouble();
    final double h1Kg = (data['h1Kg'] ?? 0.0).toDouble();
    final double h2Cost = (data['h2Cost'] ?? 0.0).toDouble();
    final double h2Kg = (data['h2Kg'] ?? 0.0).toDouble();

    final double h1CostPerKg = h1Kg > 0 ? h1Cost / h1Kg : 0.0;
    final double h1ProfitPerKg = srp - h1CostPerKg;
    final double h1NetProfit = (h1Kg * srp) - h1Cost;

    final double h2CostPerKg = h2Kg > 0 ? h2Cost / h2Kg : 0.0;
    final double h2ProfitPerKg = srp - h2CostPerKg;
    final double h2NetProfit = (h2Kg * srp) - h2Cost;

    // GUMAMIT NG REALTIME totalKg MULA SA FIRESTORE
    final double totalKg = ((data['totalKg'] ?? (h1Kg + h2Kg)) as num).toDouble();
    final double totalCost = h1Cost + h2Cost;
    final double overallCostPerKg = (h1Kg + h2Kg) > 0 ? totalCost / (h1Kg + h2Kg) : 0.0;
    final double overallProfitPerKg = srp - overallCostPerKg;
    final double totalRevenue = totalKg * srp;
    final double totalProfit = totalRevenue - totalCost;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _primaryGreenSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "SRP: ₱${srp.toStringAsFixed(2)}/kg",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _primaryGreen),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: _textSecondary),
                  onPressed: () => _confirmDeleteProduct(context, doc.id, name),
                )
              ],
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: _surfaceBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderLine),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: Text("DETAILS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _textSecondary))),
                        Expanded(flex: 2, child: Text("HECTARE 1", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _textSecondary))),
                        Expanded(flex: 2, child: Text("HECTARE 2", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _textSecondary))),
                      ],
                    ),
                  ),
                  _buildTableRow("Ani (Nakuha)", "${h1Kg.toStringAsFixed(0)} kg", "${h2Kg.toStringAsFixed(0)} kg"),
                  const Divider(height: 1, color: _borderLine),
                  _buildTableRow("Puhunan (Kabuuang)", "₱${h1Cost.toStringAsFixed(0)}", "₱${h2Cost.toStringAsFixed(0)}"),
                  const Divider(height: 1, color: _borderLine),
                  _buildTableRow("Puhunan per Kg", "₱${h1CostPerKg.toStringAsFixed(2)}", "₱${h2CostPerKg.toStringAsFixed(2)}"),
                  const Divider(height: 1, color: _borderLine),
                  _buildTableRow(
                    "Tubó per Kg", 
                    "₱${h1ProfitPerKg.toStringAsFixed(2)}", 
                    "₱${h2ProfitPerKg.toStringAsFixed(2)}",
                    isHighlight: true,
                    val1Color: h1ProfitPerKg >= 0 ? _primaryGreen : _dangerRed,
                    val2Color: h2ProfitPerKg >= 0 ? _primaryGreen : _dangerRed,
                  ),
                  const Divider(height: 1, color: _borderLine),
                  _buildTableRow(
                    "Kabuuang Tubó", 
                    "₱${h1NetProfit.toStringAsFixed(2)}", 
                    "₱${h2NetProfit.toStringAsFixed(2)}",
                    isHighlight: true,
                    val1Color: h1NetProfit >= 0 ? _primaryGreen : _dangerRed,
                    val2Color: h2NetProfit >= 0 ? _primaryGreen : _dangerRed,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _infoBlueBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _infoBlue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.analytics_rounded, size: 14, color: _infoBlue),
                      SizedBox(width: 6),
                      Text("KABUUANG KWENTA (Kasalukuyang Stock)",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _infoBlue)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryColumn("Nalalabing Stock", "${totalKg.toStringAsFixed(0)} kg", _textPrimary),
                      _buildSummaryColumn("Puhunan / kg", "₱${overallCostPerKg.toStringAsFixed(2)}", _warningOrange),
                      _buildSummaryColumn("Tubó / kg", "₱${overallProfitPerKg.toStringAsFixed(2)}", overallProfitPerKg >= 0 ? _primaryGreen : _dangerRed),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(height: 1, color: Color(0xFFCBD5E1)),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Kabuuang Benta (Gross)", style: TextStyle(fontSize: 10, color: _textSecondary)),
                          Text(_formatCurrency(totalRevenue),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("MALINIS NA TUBÓ (Net)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _primaryGreen)),
                          Text(
                            _formatCurrency(totalProfit),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: totalProfit >= 0 ? _primaryGreen : _dangerRed,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableRow(String label, String val1, String val2, {bool isHighlight = false, Color val1Color = _textPrimary, Color val2Color = _textPrimary}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2, 
            child: Text(
              label, 
              style: TextStyle(fontSize: 11, fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500, color: _textPrimary)
            )
          ),
          Expanded(
            flex: 2, 
            child: Text(
              val1, 
              textAlign: TextAlign.center, 
              style: TextStyle(fontSize: 11, fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600, color: val1Color)
            )
          ),
          Expanded(
            flex: 2, 
            child: Text(
              val2, 
              textAlign: TextAlign.center, 
              style: TextStyle(fontSize: 11, fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600, color: val2Color)
            )
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryColumn(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: _textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  void _confirmDeleteProduct(BuildContext context, String docId, String name) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("I-delete ang Record?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Text("Sigurado ka bang gusto mong alisin ang $name?",
              style: const TextStyle(fontSize: 12, color: _textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("I-cancel", style: TextStyle(color: _textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _dangerRed,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final nav = Navigator.of(dialogContext);
                await FirebaseFirestore.instance.collection("products").doc(docId).update({'isDeleted': true});
                nav.pop();
              },
              child: const Text("I-delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showAddHarvestModal(BuildContext context) {
    final formKey = GlobalKey<FormState>();

    String selectedType = _riceTypes.first;
    String selectedCondition = _riceConditions.first;

    final srpController = TextEditingController();
    final h1CostController = TextEditingController();
    final h1KgController = TextEditingController();
    final h2CostController = TextEditingController();
    final h2KgController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double srp = double.tryParse(srpController.text) ?? 0.0;
            final double h1Cost = double.tryParse(h1CostController.text) ?? 0.0;
            final double h1Kg = double.tryParse(h1KgController.text) ?? 0.0;
            final double h2Cost = double.tryParse(h2CostController.text) ?? 0.0;
            final double h2Kg = double.tryParse(h2KgController.text) ?? 0.0;

            final double h1CostPerKg = h1Kg > 0 ? h1Cost / h1Kg : 0.0;
            final double h1ProfitPerKg = srp - h1CostPerKg;

            final double h2CostPerKg = h2Kg > 0 ? h2Cost / h2Kg : 0.0;
            final double h2ProfitPerKg = srp - h2CostPerKg;

            final double totalKg = h1Kg + h2Kg;
            final double totalCost = h1Cost + h2Cost;
            final double overallCostPerKg = totalKg > 0 ? totalCost / totalKg : 0.0;
            final double totalRevenue = totalKg * srp;
            final double totalProfit = totalRevenue - totalCost;

            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Mag-input ng Ani & Puhunan",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
                              Text("Ilagay ang detalye ng Hectare 1 & 2",
                                  style: TextStyle(fontSize: 11, color: _textSecondary)),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(modalContext),
                            icon: const Icon(Icons.close_rounded, color: _textSecondary),
                          )
                        ],
                      ),
                      const Divider(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedType,
                              decoration: InputDecoration(
                                labelText: "Uri ng Binhi",
                                filled: true,
                                fillColor: _surfaceBg,
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderLine)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryGreen)),
                              ),
                              items: _riceTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (val) => setModalState(() => selectedType = val!),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedCondition,
                              decoration: InputDecoration(
                                labelText: "Klase/Kondisyon",
                                filled: true,
                                fillColor: _surfaceBg,
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderLine)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryGreen)),
                              ),
                              items: _riceConditions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (val) => setModalState(() => selectedCondition = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: srpController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => (v == null || v.isEmpty) ? "Kailangan ang SRP" : null,
                        onChanged: (_) => setModalState(() {}),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: _primaryGreen),
                        decoration: InputDecoration(
                          labelText: "SRP / Benta kada Kilo (₱)",
                          hintText: "Hal. 25.00",
                          filled: true,
                          fillColor: _primaryGreenSoft.withOpacity(0.3),
                          prefixIcon: const Icon(Icons.sell_outlined, color: _primaryGreen, size: 20),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryGreen)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryGreen, width: 2)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildSectionHeader("HECTARE 1"),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInputField(
                              controller: h1CostController,
                              label: "Puhunan (₱)",
                              icon: Icons.payments_outlined,
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildInputField(
                              controller: h1KgController,
                              label: "Nakuha (kg)",
                              icon: Icons.scale_outlined,
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildSectionHeader("HECTARE 2"),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInputField(
                              controller: h2CostController,
                              label: "Puhunan (₱)",
                              icon: Icons.payments_outlined,
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildInputField(
                              controller: h2KgController,
                              label: "Nakuha (kg)",
                              icon: Icons.scale_outlined,
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _surfaceBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _borderLine),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.calculate_outlined, size: 16, color: _primaryGreen),
                                SizedBox(width: 6),
                                Text(
                                  "Awtomatikong Kwenta ng System",
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: _buildMiniCalcCard(
                                    title: "Hectare 1",
                                    costPerKg: h1CostPerKg,
                                    profitPerKg: h1ProfitPerKg,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildMiniCalcCard(
                                    title: "Hectare 2",
                                    costPerKg: h2CostPerKg,
                                    profitPerKg: h2ProfitPerKg,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: totalProfit >= 0 ? _primaryGreenSoft : _dangerRedBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Kabuuang Ani: ${totalKg.toStringAsFixed(0)} kg", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _textPrimary)),
                                      Text("Puhunan/kg: ₱${overallCostPerKg.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _textPrimary)),
                                    ],
                                  ),
                                  const Divider(height: 10, color: Colors.black12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text("Inaasahang Malinis na Tubó:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textPrimary)),
                                      Text(
                                        "₱${totalProfit.toStringAsFixed(2)}",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: totalProfit >= 0 ? _primaryGreen : _dangerRed,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryGreen,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              final nav = Navigator.of(modalContext);
                              final String productName = "$selectedType Palay ($selectedCondition)";

                              final newHarvestData = {
                                'name': productName,
                                'type': selectedType,
                                'condition': selectedCondition,
                                'srpPerKg': srp,
                                'h1Cost': h1Cost,
                                'h1Kg': h1Kg,
                                'h2Cost': h2Cost,
                                'h2Kg': h2Kg,
                                'totalKg': totalKg,
                                'totalCost': totalCost,
                                'isDeleted': false,
                                'createdAt': FieldValue.serverTimestamp(),
                              };

                              await FirebaseFirestore.instance.collection("products").add(newHarvestData);
                              nav.pop();
                            }
                          },
                          child: const Text("I-save sa Inbentaryo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 14,
          decoration: BoxDecoration(color: _primaryGreen, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Function(String) onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) => (v == null || v.isEmpty) ? "Kailangan" : null,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: _textSecondary),
        filled: true,
        fillColor: _surfaceBg,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderLine)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryGreen)),
      ),
    );
  }

  Widget _buildMiniCalcCard({required String title, required double costPerKg, required double profitPerKg}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textSecondary)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Puhunan/kg:", style: TextStyle(fontSize: 10, color: _textSecondary)),
              Text("₱${costPerKg.toStringAsFixed(2)}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _warningOrange)),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Tubó/kg:", style: TextStyle(fontSize: 10, color: _textSecondary)),
              Text(
                "₱${profitPerKg.toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: 10, 
                  fontWeight: FontWeight.bold, 
                  color: profitPerKg >= 0 ? _primaryGreen : _dangerRed
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}