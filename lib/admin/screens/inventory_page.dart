import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'inventory_input_page.dart';

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
  static const Color _infoBlue = Color(0xFF2563EB);
  static const Color _infoBlueBg = Color(0xFFEFF6FF);

  late final TextEditingController _searchController;
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>("");

  final List<String> _riceTypes = ["Hybrid", "Inbred"];
  final List<String> _riceConditions = ["Basa / Sariwa", "Tuyo"];

  final ImagePicker _picker = ImagePicker();

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

  Future<List<String>> _uploadProductImages(
    List<File> imageFiles,
    String productCode,
  ) async {
    final supabase = Supabase.instance.client;
    final List<String> urls = [];

    for (int i = 0; i < imageFiles.length; i++) {
      final file = imageFiles[i];
      final extension = file.path.split('.').last.toLowerCase();
      final safeExtension =
          ['jpg', 'jpeg', 'png', 'webp'].contains(extension)
              ? extension
              : 'jpg';
      final contentType =
          safeExtension == 'jpg' || safeExtension == 'jpeg'
              ? 'image/jpeg'
              : 'image/$safeExtension';

      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final filePath =
          'products/${productCode.toString().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}/${timestamp}_$i.$safeExtension';

      await supabase.storage.from('product-images').upload(
        filePath,
        file,
        fileOptions: FileOptions(
          cacheControl: '31536000',
          contentType: contentType,
          upsert: false,
        ),
      );

      final publicUrl =
          supabase.storage.from('product-images').getPublicUrl(filePath);
      urls.add(publicUrl);
    }

    return urls;
  }

  String _formatCurrency(double amount) {
    return "₱${amount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => "${m[1]},",
        )}";
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return "N/A";
    return "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}";
  }

  int _calculateDaysOld(DateTime? dateTime) {
    if (dateTime == null) return 0;
    return DateTime.now().difference(dateTime).inDays;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceBg,
      floatingActionButton: FloatingActionButton.extended(
        elevation: 3,
        backgroundColor: _primaryGreen,
        onPressed: () async {
          final result = await Navigator.of(context).push<Object?>(
            MaterialPageRoute(
              builder: (_) => const InventoryInputPage(),
            ),
          );

          if (!context.mounted) return;

          if (result is String && result.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result, style: const TextStyle(fontSize: 16)),
                backgroundColor: _dangerRed,
                duration: const Duration(seconds: 8),
              ),
            );
          } else if (result == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Successfully saved ang ani at images sa Inventory!",
                  style: TextStyle(fontSize: 16),
                ),
                backgroundColor: _primaryGreen,
              ),
            );
          }
        },
        icon: const Icon(Icons.add_box_rounded, color: Colors.white, size: 28),
        label: const Text(
          "+ Mag-input ng Ani & Puhunan",
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection("products").snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text("May error sa database.",
                    style: TextStyle(
                        color: _dangerRed, fontWeight: FontWeight.bold, fontSize: 17)),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: _primaryGreen));
            }

            final docs = snapshot.data?.docs ?? [];

            double totalExpectedValuation = 0.0;
            double totalFixedCost = 0.0;
            double totalExpectedProfit = 0.0;
            int totalRemainingStockKg = 0;
            int totalInitialStockKg = 0;

            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>? ?? {};
              if (data['isDeleted'] == true) continue;

              final double initialKg =
                  ((data['initialKg'] ?? data['totalKg'] ?? 0.0) as num)
                      .toDouble();
              final double remainingKg =
                  ((data['remainingKg'] ?? initialKg) as num)
                      .toDouble();
              final double totalCost = (data['totalCost'] ?? 0.0).toDouble();

              double batchExpectedGross = 0.0;
              final List breakdowns = data['breakdowns'] ?? [];
              for (var b in breakdowns) {
                final double bKg = ((b['kg'] ?? 0.0) as num).toDouble();
                final double bSrp = ((b['srp'] ?? 0.0) as num).toDouble();
                batchExpectedGross += (bKg * bSrp);
              }

              totalExpectedValuation += batchExpectedGross;
              totalFixedCost += totalCost;
              totalRemainingStockKg += remainingKg.toInt();
              totalInitialStockKg += initialKg.toInt();
            }

            totalExpectedProfit = totalExpectedValuation - totalFixedCost;

            return Column(
              children: [
                _buildHeaderAndAnalytics(
                  totalValue: totalExpectedValuation,
                  totalProfit: totalExpectedProfit,
                  totalStockKg: totalRemainingStockKg,
                  totalInitialKg: totalInitialStockKg,
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ValueListenableBuilder<String>(
                    valueListenable: _searchQueryNotifier,
                    builder: (context, queryValue, child) {
                      return TextField(
                        controller: _searchController,
                        onChanged: (val) => _searchQueryNotifier.value = val,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: "Maghanap ng uri (e.g. Hybrid, Hectare 1)...",
                          hintStyle: const TextStyle(
                              fontSize: 15, color: _textSecondary),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: _textSecondary, size: 26),
                          suffixIcon: queryValue.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear,
                                      size: 24, color: _textSecondary),
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchQueryNotifier.value = "";
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: _cardBg,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _borderLine),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: _primaryGreen, width: 1.5),
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
                      final activeDocs = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>? ?? {};
                        if (data['isDeleted'] == true) return false;
                        final name =
                            (data['name'] ?? '').toString().toLowerCase();
                        final hectare =
                            (data['hectare'] ?? '').toString().toLowerCase();
                        return name.contains(query.toLowerCase()) ||
                            hectare.contains(query.toLowerCase());
                      }).toList();

                      if (activeDocs.isEmpty) {
                        return const Center(
                          child: Text("Walang nahanap na record sa Inventory.",
                              style: TextStyle(
                                  color: _textSecondary, fontSize: 16)),
                        );
                      }

                      final Map<String, List<DocumentSnapshot>> groupedProducts =
                          {};
                      for (var doc in activeDocs) {
                        final data = doc.data() as Map<String, dynamic>? ?? {};
                        final name = data['hectare'] ?? "Uncategorized";
                        if (!groupedProducts.containsKey(name)) {
                          groupedProducts[name] = [];
                        }
                        groupedProducts[name]!.add(doc);
                      }

                      final keys = groupedProducts.keys.toList();

                      return ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: keys.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final groupName = keys[index];
                          final batchList = groupedProducts[groupName]!;
                          return _buildFolderSection(groupName, batchList);
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
    required int totalInitialKg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: _cardBg,
        border: Border(bottom: BorderSide(color: _borderLine)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Farm Inventory",
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _textPrimary)),
                    SizedBox(height: 2),
                    Text("Puhunan / Capital at Tubo / Profit sa Ani",
                        style:
                            TextStyle(fontSize: 14, color: _textSecondary)),
                  ],
                ),
              ),
              IconButton(
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                tooltip: "Archive",
                icon: const Icon(Icons.history_toggle_off_rounded,
                    color: _infoBlue, size: 30),
                onPressed: () => _showHistoryModal(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildMetricCardFixed(
                    "Benta / Revenue",
                    _formatCurrency(totalValue),
                    Icons.account_balance_wallet_outlined,
                    _infoBlue),
                const SizedBox(width: 8),
                _buildMetricCardFixed("Stock / Kilos", "$totalStockKg / $totalInitialKg kg",
                    Icons.scale_outlined, _primaryGreen),
                const SizedBox(width: 8),
                _buildMetricCardFixed(
                    "Tubo / Profit",
                    _formatCurrency(totalProfit),
                    Icons.trending_up_rounded,
                    totalProfit >= 0 ? _primaryGreen : _dangerRed),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCardFixed(
      String label, String value, IconData icon, Color accentColor) {
    return Container(
      width: 155,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _surfaceBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                      fontSize: 12,
                      color: _textSecondary,
                      fontWeight: FontWeight.bold),
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
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: accentColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderSection(
      String hectareGroup, List<DocumentSnapshot> batchList) {
    double folderRemainingKg = 0;
    double folderInitialKg = 0;

    for (var doc in batchList) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final double initial = ((data['initialKg'] ?? data['totalKg'] ?? 0.0) as num).toDouble();
      folderInitialKg += initial;
      folderRemainingKg += ((data['remainingKg'] ?? initial) as num).toDouble();
    }

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderLine),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: const Icon(Icons.folder_special_rounded,
              color: _primaryGreen, size: 32),
          title: Text(
            hectareGroup,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textPrimary),
          ),
          subtitle: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              "${batchList.length} Batch(es) | Stock: ${folderRemainingKg.toStringAsFixed(0)}/${folderInitialKg.toStringAsFixed(0)} kg",
              style: const TextStyle(fontSize: 13, color: _textSecondary),
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          children: batchList
              .map((doc) => _buildBatchCardWithSeparatedConditions(doc))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildBatchCardWithSeparatedConditions(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final String name = data['name'] ?? "Palay Batch";
    final String productCode = data['productCode'] ?? "CODE-N/A";
    final double totalCost = (data['totalCost'] ?? 0.0).toDouble();
    final String imageUrl = data['imageUrl'] ?? '';

    final List breakdownsData = data['breakdowns'] ?? [];
    final double initialKg =
        ((data['initialKg'] ?? data['totalKg'] ?? 0.0) as num).toDouble();
    final double remainingKg =
        ((data['remainingKg'] ?? initialKg) as num).toDouble();
    final double soldKg = initialKg - remainingKg;

    double totalExpectedGross = 0.0;
    for (var b in breakdownsData) {
      final double bKg = ((b['kg'] ?? 0.0) as num).toDouble();
      final double bSrp = ((b['srp'] ?? 0.0) as num).toDouble();
      totalExpectedGross += (bKg * bSrp);
    }

    final double fixedCostPerKg = initialKg > 0 ? totalCost / initialKg : 0.0;
    final double avgSrpPerKg = initialKg > 0 ? totalExpectedGross / initialKg : 0.0;
    final double totalExpectedProfit = totalExpectedGross - totalCost;

    final double currentGrossSold = soldKg * avgSrpPerKg;
    final double currentCostSold = soldKg * fixedCostPerKg;
    final double currentProfitSold = currentGrossSold - currentCostSold;

    final Timestamp? createdAtTs = data['createdAt'] as Timestamp?;
    final DateTime? createdAt = createdAtTs?.toDate();
    final int daysOld = _calculateDaysOld(createdAt);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 55,
                  height: 55,
                  color: Colors.grey.shade200,
                  child: imageUrl.isNotEmpty
                      ? (imageUrl.startsWith('http')
                          ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.agriculture, color: Colors.grey, size: 30))
                          : Image.file(File(imageUrl), fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.agriculture, color: Colors.grey, size: 30)))
                      : const Icon(Icons.agriculture, color: Colors.grey, size: 30),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary),
                    ),
                    Text(
                      "Code: $productCode | ${_formatDate(createdAt)} ($daysOld araw)",
                      style: const TextStyle(
                          fontSize: 12, color: _textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _primaryGreenSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _primaryGreen.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Natitirang Stock",
                        style: TextStyle(fontSize: 11, color: _primaryGreen, fontWeight: FontWeight.bold)),
                    Text(
                      "${remainingKg.toStringAsFixed(0)} kg left",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: _primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                icon: const Icon(Icons.edit_note_rounded,
                    size: 26, color: _infoBlue),
                onPressed: () => _showEditProductModal(context, doc),
              ),
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                icon: const Icon(Icons.archive_outlined,
                    size: 24, color: _textSecondary),
                onPressed: () =>
                    _confirmDeleteProduct(context, doc.id, name, productCode),
              )
            ],
          ),
          const SizedBox(height: 10),

          ...breakdownsData.map((b) {
            final String cond = b['condition'] ?? "N/A";
            final double bKg = ((b['kg'] ?? 0.0) as num).toDouble();
            final double bSrp = ((b['srp'] ?? 0.0) as num).toDouble();

            bool isDry = cond.toLowerCase().contains("tuyo");

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isDry
                        ? _warningOrange.withOpacity(0.3)
                        : _infoBlue.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                          isDry
                              ? Icons.wb_sunny_rounded
                              : Icons.water_drop_rounded,
                          size: 18,
                          color: isDry ? _warningOrange : _infoBlue),
                      const SizedBox(width: 6),
                      Text(
                        cond,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDry ? _warningOrange : _infoBlue,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        "SRP: ₱${bSrp.toStringAsFixed(2)}/kg",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _surfaceBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "${bKg.toStringAsFixed(0)} kg",
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 4),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _infoBlueBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _infoBlue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.analytics_rounded, size: 18, color: _infoBlue),
                    SizedBox(width: 6),
                    Text("KABUUANG COMPUTATION AT TUBO / PROFIT",
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _infoBlue)),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSummaryColumn(
                        "Stock / Total",
                        "${remainingKg.toStringAsFixed(0)} / ${initialKg.toStringAsFixed(0)} kg",
                        _infoBlue),
                    _buildSummaryColumn("Puhunan / Capital",
                        "₱${totalCost.toStringAsFixed(2)}", _warningOrange),
                    _buildSummaryColumn(
                        "Puhunan / kg",
                        "₱${fixedCostPerKg.toStringAsFixed(2)}",
                        _textPrimary),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(height: 1, color: Color(0xFFCBD5E1)),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Tinatayang Benta (Gross)",
                              style: TextStyle(
                                  fontSize: 11, color: _textSecondary, fontWeight: FontWeight.w600)),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(_formatCurrency(totalExpectedGross),
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: _textPrimary)),
                          ),
                          const SizedBox(height: 2),
                          Text("Kasalukuyang benta: ${_formatCurrency(currentGrossSold)}",
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _infoBlue)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("Tinatayang Tubo / Profit",
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryGreen)),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              totalExpectedProfit >= 0
                                  ? "+${_formatCurrency(totalExpectedProfit)}"
                                  : "-${_formatCurrency(totalExpectedProfit.abs())}",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: totalExpectedProfit >= 0
                                    ? _primaryGreen
                                    : _dangerRed,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Kasalukuyang Tubo: ${_formatCurrency(currentProfitSold)}",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: currentProfitSold >= 0
                                  ? _primaryGreen
                                  : _dangerRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryColumn(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: _textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  void _confirmDeleteProduct(
      BuildContext context, String docId, String name, String code) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("I-archive ang Batch?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: Text(
              "Ililipat ang $name ($code) sa Archive. Pwede mo itong i-restore o permanenteng burahin doon.",
              style: const TextStyle(fontSize: 15, color: _textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel",
                  style: TextStyle(color: _textSecondary, fontSize: 15)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _warningOrange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final nav = Navigator.of(dialogContext);
                await FirebaseFirestore.instance
                    .collection("products")
                    .doc(docId)
                    .update({
                  'isDeleted': true,
                  'deletedAt': FieldValue.serverTimestamp(),
                });
                nav.pop();
              },
              child: const Text("Archive",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        );
      },
    );
  }

  void _confirmPermanentDelete(
      BuildContext context, String docId, String name) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Permanenteng Burahin?",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _dangerRed)),
          content: Text(
              "Sigurado ka bang gusto mong permanenteng burahin ang $name? Hindi na ito mababawi kailanman.",
              style: const TextStyle(fontSize: 15, color: _textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel",
                  style: TextStyle(color: _textSecondary, fontSize: 15)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _dangerRed,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final nav = Navigator.of(dialogContext);
                await FirebaseFirestore.instance
                    .collection("products")
                    .doc(docId)
                    .delete();
                nav.pop();
              },
              child: const Text("Burahin Na",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        );
      },
    );
  }

  void _showArchivedDetailsModal(
      BuildContext context, Map<String, dynamic> data) {
    final String name = data['name'] ?? "Archived Batch";
    final String code = data['productCode'] ?? "N/A";
    final double totalCost = (data['totalCost'] ?? 0.0).toDouble();
    final List breakdownsData = data['breakdowns'] ?? [];

    double totalRevenue = 0.0;
    for (var b in breakdownsData) {
      final double bKg = ((b['kg'] ?? 0.0) as num).toDouble();
      final double bSrp = ((b['srp'] ?? 0.0) as num).toDouble();
      totalRevenue += (bKg * bSrp);
    }
    final double totalProfit = totalRevenue - totalCost;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary)),
              Text("Code: $code",
                  style: const TextStyle(
                      fontSize: 14,
                      color: _infoBlue,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const Text("Breakdown kada Kondisyon:",
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _textSecondary)),
                const SizedBox(height: 6),
                ...breakdownsData.map((b) {
                  final String cond = b['condition'] ?? "N/A";
                  final double bKg = ((b['kg'] ?? 0.0) as num).toDouble();
                  final double bSrp = ((b['srp'] ?? 0.0) as num).toDouble();
                  final double bCost =
                      ((b['allocatedCost'] ?? 0.0) as num).toDouble();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("• $cond",
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _textPrimary)),
                        _buildArchiveDetailRow(" Kilos / Ani", "${bKg.toStringAsFixed(0)} kg"),
                        _buildArchiveDetailRow(
                            " Target SRP", "₱${bSrp.toStringAsFixed(2)}/kg"),
                        _buildArchiveDetailRow(
                            " Puhunan Share", "₱${bCost.toStringAsFixed(2)}"),
                      ],
                    ),
                  );
                }),
                const Divider(),
                _buildArchiveDetailRow(
                    "Puhunan / Capital", "₱${totalCost.toStringAsFixed(2)}",
                    isBold: true),
                _buildArchiveDetailRow(
                    "Estimated Gross Benta", _formatCurrency(totalRevenue),
                    isBold: true),
                _buildArchiveDetailRow(
                    "Estimated Tubo / Profit", _formatCurrency(totalProfit),
                    isBold: true,
                    color: totalProfit >= 0 ? _primaryGreen : _dangerRed),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Close",
                  style: TextStyle(
                      color: _primaryGreen, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildArchiveDetailRow(String label, String value,
      {bool isBold = false, Color color = _textPrimary}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: _textSecondary,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  void _showHistoryModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (modalContext) {
        return Container(
          height: MediaQuery.of(modalContext).size.height * 0.80,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.history_toggle_off_rounded, color: _infoBlue, size: 28),
                      SizedBox(width: 8),
                      Text("Archive List",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _textPrimary)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: _textSecondary, size: 28),
                    onPressed: () => Navigator.pop(modalContext),
                  ),
                ],
              ),
              const Text(
                  "Nakatala dito ang mga in-archive na batch. Pwede mong tingnan ang details, i-restore, o permanenteng burahin.",
                  style: TextStyle(fontSize: 13, color: _textSecondary)),
              const Divider(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("products")
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                          child: Text("May error sa pag-load ng history.", style: TextStyle(fontSize: 15)));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(color: _infoBlue));
                    }

                    final allDocs = snapshot.data?.docs ?? [];
                    final historyDocs = allDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      return data['isDeleted'] == true;
                    }).toList();

                    if (historyDocs.isEmpty) {
                      return const Center(
                        child: Text("Walang laman ang Archive.",
                            style: TextStyle(
                                color: _textSecondary, fontSize: 15)),
                      );
                    }

                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: historyDocs.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final doc = historyDocs[index];
                        final data = doc.data() as Map<String, dynamic>? ?? {};
                        final name = data['name'] ?? "Item";
                        final code = data['productCode'] ?? "N/A";
                        final Timestamp? delTime =
                            data['deletedAt'] as Timestamp?;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _surfaceBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _borderLine),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: _textPrimary)),
                                    const SizedBox(height: 2),
                                    Text("Code: $code",
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: _infoBlue,
                                            fontWeight: FontWeight.w600)),
                                    Text(
                                        "In-archive noong: ${_formatDate(delTime?.toDate())}",
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: _textSecondary)),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    constraints: const BoxConstraints(),
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 4),
                                    tooltip: "Tingnan ang Details",
                                    icon: const Icon(
                                        Icons.info_outline_rounded,
                                        color: _infoBlue,
                                        size: 26),
                                    onPressed: () =>
                                        _showArchivedDetailsModal(
                                            context, data),
                                  ),
                                  IconButton(
                                    constraints: const BoxConstraints(),
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 4),
                                    tooltip: "I-restore sa Inventory",
                                    icon: const Icon(
                                        Icons.restore_from_trash_rounded,
                                        color: _primaryGreen,
                                        size: 26),
                                    onPressed: () async {
                                      await FirebaseFirestore.instance
                                          .collection("products")
                                          .doc(doc.id)
                                          .update({'isDeleted': false});
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content:
                                                  Text("Na-restore na ang $name!", style: const TextStyle(fontSize: 15)),
                                              backgroundColor: _primaryGreen),
                                        );
                                      }
                                    },
                                  ),
                                  IconButton(
                                    constraints: const BoxConstraints(),
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 4),
                                    tooltip: "Permanenteng Burahin",
                                    icon: const Icon(
                                        Icons.delete_forever_rounded,
                                        color: _dangerRed,
                                        size: 26),
                                    onPressed: () => _confirmPermanentDelete(
                                        context, doc.id, name),
                                  ),
                                ],
                              )
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEditablePhotoPicker({
    required BuildContext context,
    required List<String> existingUrls,
    required List<File> newImages,
    required StateSetter setModalState,
  }) {
    final total = existingUrls.length + newImages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Mga Larawan ng Produkto",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
            Text("$total/9",
                style: const TextStyle(fontSize: 13, color: _textSecondary, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        const Text("Tanggalin ang luma, magdagdag ng bago, o magpalit ng main photo.",
            style: TextStyle(fontSize: 12, color: _textSecondary)),
        const SizedBox(height: 8),
        SizedBox(
          height: 105,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: total < 9 ? total + 1 : total,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == total && total < 9) {
                return GestureDetector(
                  onTap: () async {
                    final picked = await _picker.pickMultiImage(
                        imageQuality: 85, maxWidth: 1600);
                    if (picked.isEmpty) return;
                    setModalState(() {
                      final remaining = 9 - (existingUrls.length + newImages.length);
                      newImages.addAll(picked.take(remaining).map((x) => File(x.path)));
                    });
                  },
                  child: Container(
                    width: 105,
                    decoration: BoxDecoration(
                        color: _surfaceBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _primaryGreen, width: 1.2)),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: _primaryGreen, size: 32),
                        SizedBox(height: 4),
                        Text("Magdagdag", style: TextStyle(fontSize: 13, color: _primaryGreen, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              }

              if (index < existingUrls.length) {
                final url = existingUrls[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(url,
                          width: 105,
                          height: 105,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                                width: 105,
                                height: 105,
                                color: _surfaceBg,
                                child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                              )),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setModalState(() => existingUrls.removeAt(index)),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                    if (index == 0)
                      Positioned(
                        left: 5,
                        bottom: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: _primaryGreen, borderRadius: BorderRadius.circular(5)),
                          child: const Text("MAIN", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                );
              }

              final fileIndex = index - existingUrls.length;
              final file = newImages[fileIndex];
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(file, width: 105, height: 105, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => setModalState(() => newImages.removeAt(fileIndex)),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEditProductModal(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final formKey = GlobalKey<FormState>();

    String selectedHectare = data['hectare'] ?? "Hectare 1";
    String selectedType = data['type'] ?? _riceTypes.first;
    if (!_riceTypes.contains(selectedType)) selectedType = _riceTypes.first;

    final List<String> existingImageUrls =
        List<String>.from(data['imageUrls'] ?? []);

    if (existingImageUrls.isEmpty) {
      final oldImageUrl = (data['imageUrl'] ?? '').toString().trim();
      if (oldImageUrl.isNotEmpty) {
        existingImageUrls.add(oldImageUrl);
      }
    }

    final List<File> selectedImages = [];
    final descriptionController = TextEditingController(
      text: (data['description'] ?? '').toString(),
    );

    final totalCostController =
        TextEditingController(text: (data['totalCost'] ?? 0.0).toString());

    final List existingBreakdowns = data['breakdowns'] ?? [];
    List<HarvestBreakdownItem> breakdownItems = existingBreakdowns.map((b) {
      return HarvestBreakdownItem(
        condition: b['condition'] ?? _riceConditions.first,
        kgController: TextEditingController(text: (b['kg'] ?? 0.0).toString()),
        srpController:
            TextEditingController(text: (b['srp'] ?? 0.0).toString()),
      );
    }).toList();

    if (breakdownItems.isEmpty) {
      breakdownItems.add(
        HarvestBreakdownItem(
          condition: _riceConditions.first,
          kgController: TextEditingController(),
          srpController: TextEditingController(),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double totalCost =
                double.tryParse(totalCostController.text) ?? 0.0;

            double sumKg = 0.0;
            double totalRevenue = 0.0;

            for (var item in breakdownItems) {
              final double kg = double.tryParse(item.kgController.text) ?? 0.0;
              final double srp = double.tryParse(item.srpController.text) ?? 0.0;
              sumKg += kg;
              totalRevenue += (kg * srp);
            }

            final double overallCostPerKg = sumKg > 0 ? totalCost / sumKg : 0.0;
            final double overallRevenuePerKg =
                sumKg > 0 ? totalRevenue / sumKg : 0.0;
            final double totalProfit = totalRevenue - totalCost;

            return Padding(
              padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 16,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
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
                              Text("I-edit ang Batch Info",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _textPrimary)),
                              Text("Baguhin ang anumang maling na-input",
                                  style: TextStyle(
                                      fontSize: 13, color: _textSecondary)),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(modalContext),
                            icon: const Icon(Icons.close_rounded,
                                color: _textSecondary, size: 28),
                          )
                        ],
                      ),
                      const Divider(height: 16),

                      _buildEditablePhotoPicker(
                        context: context,
                        existingUrls: existingImageUrls,
                        newImages: selectedImages,
                        setModalState: setModalState,
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        "Description / Detalye ng Produkto",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 4,
                        maxLength: 1000,
                        style: const TextStyle(fontSize: 14),
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: "Ilagay ang karagdagang detalye...",
                          hintStyle: const TextStyle(fontSize: 14, color: _textSecondary),
                          filled: true,
                          fillColor: _surfaceBg,
                          alignLabelWithHint: true,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 50),
                            child: Icon(Icons.description_outlined, color: _primaryGreen, size: 24),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _borderLine),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _primaryGreen, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      const Text("1. Hectare:",
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _textPrimary)),
                      const SizedBox(height: 6),
                      Row(
                        children: ["Hectare 1", "Hectare 2"].map((h) {
                          final isSel = selectedHectare == h;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setModalState(() => selectedHectare = h),
                              child: Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color:
                                      isSel ? _primaryGreenSoft : _surfaceBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: isSel ? _primaryGreen : _borderLine,
                                      width: isSel ? 1.5 : 1.0),
                                ),
                                child: Center(
                                  child: Text(
                                    h,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isSel
                                          ? _primaryGreen
                                          : _textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      const Text("2. Uri ng Binhi & Puhunan / Capital:",
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _textPrimary)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedType,
                              decoration: InputDecoration(
                                labelText: "Uri ng Binhi",
                                labelStyle: const TextStyle(fontSize: 13),
                                filled: true,
                                fillColor: _surfaceBg,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        const BorderSide(color: _borderLine)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        const BorderSide(color: _primaryGreen)),
                              ),
                              items: _riceTypes
                                  .map((e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e,
                                          style:
                                              const TextStyle(fontSize: 14))))
                                  .toList(),
                              onChanged: (val) =>
                                  setModalState(() => selectedType = val!),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: totalCostController,
                              style: const TextStyle(fontSize: 14),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? "Kailangan" : null,
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(
                                labelText: "Puhunan / Capital",
                                labelStyle: const TextStyle(fontSize: 13),
                                prefixIcon: const Icon(Icons.payments_outlined,
                                    size: 18, color: _warningOrange),
                                filled: true,
                                fillColor: _surfaceBg,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        const BorderSide(color: _borderLine)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        const BorderSide(color: _primaryGreen)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("3. Condition / Uri ng Palay:",
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _textPrimary)),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap),
                            onPressed: () {
                              setModalState(() {
                                breakdownItems.add(
                                  HarvestBreakdownItem(
                                    condition: _riceConditions[
                                        breakdownItems.length %
                                            _riceConditions.length],
                                    kgController: TextEditingController(),
                                    srpController: TextEditingController(),
                                  ),
                                );
                              });
                            },
                            icon: const Icon(Icons.add_circle_outline_rounded,
                                size: 20, color: _primaryGreen),
                            label: const Text("+ Magdagdag",
                                style: TextStyle(
                                    color: _primaryGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          )
                        ],
                      ),
                      const SizedBox(height: 6),

                      ...breakdownItems.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;

                        final double itemKg =
                            double.tryParse(item.kgController.text) ?? 0.0;
                        final double itemAllocatedCost =
                            sumKg > 0 ? (itemKg / sumKg) * totalCost : 0.0;
                        final double itemCostPerKg =
                            itemKg > 0 ? itemAllocatedCost / itemKg : 0.0;
                        final double itemSrp =
                            double.tryParse(item.srpController.text) ?? 0.0;
                        final double itemProfitPerKg = itemSrp - itemCostPerKg;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _surfaceBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _borderLine),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: DropdownButtonFormField<String>(
                                      value: item.condition,
                                      decoration: InputDecoration(
                                        labelText: "Condition",
                                        labelStyle:
                                            const TextStyle(fontSize: 12),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 6),
                                        enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            borderSide: const BorderSide(
                                                color: _borderLine)),
                                        focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            borderSide: const BorderSide(
                                                color: _primaryGreen)),
                                      ),
                                      items: _riceConditions
                                          .map((c) => DropdownMenuItem(
                                              value: c,
                                              child: Text(c,
                                                  style: const TextStyle(
                                                      fontSize: 13))))
                                          .toList(),
                                      onChanged: (val) => setModalState(
                                          () => item.condition = val!),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: item.kgController,
                                      style: const TextStyle(fontSize: 13),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      validator: (v) =>
                                          (v == null || v.isEmpty) ? "Kg" : null,
                                      onChanged: (_) => setModalState(() {}),
                                      decoration: InputDecoration(
                                        labelText: "Kilos (kg)",
                                        labelStyle:
                                            const TextStyle(fontSize: 12),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 6),
                                        enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            borderSide: const BorderSide(
                                                color: _borderLine)),
                                        focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            borderSide: const BorderSide(
                                                color: _primaryGreen)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: item.srpController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      validator: (v) =>
                                          (v == null || v.isEmpty)
                                              ? "SRP"
                                              : null,
                                      onChanged: (_) => setModalState(() {}),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _primaryGreen,
                                          fontSize: 13),
                                      decoration: InputDecoration(
                                        labelText: "SRP / kg",
                                        labelStyle:
                                            const TextStyle(fontSize: 12),
                                        filled: true,
                                        fillColor: _primaryGreenSoft
                                            .withOpacity(0.3),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 6),
                                        enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            borderSide: const BorderSide(
                                                color: _primaryGreen)),
                                        focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            borderSide: const BorderSide(
                                                color: _primaryGreen,
                                                width: 1.5)),
                                      ),
                                    ),
                                  ),
                                  if (breakdownItems.length > 1)
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.only(left: 4),
                                      icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: _dangerRed,
                                          size: 22),
                                      onPressed: () {
                                        setModalState(() {
                                          breakdownItems.removeAt(idx);
                                        });
                                      },
                                    )
                                ],
                              ),
                              if (itemKg > 0 && totalCost > 0) ...[
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        "Puhunan Share: ₱${itemAllocatedCost.toStringAsFixed(2)}",
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: _warningOrange)),
                                    Text(
                                        "Tubo / Profit/kg: ₱${itemProfitPerKg.toStringAsFixed(2)}",
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: itemProfitPerKg >= 0
                                                ? _primaryGreen
                                                : _dangerRed)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 10),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _surfaceBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _borderLine),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.calculate_outlined,
                                    size: 18, color: _primaryGreen),
                                SizedBox(width: 6),
                                Text(
                                  "Computation Details",
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _textPrimary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    "Kabuuang Kilos: ${sumKg.toStringAsFixed(0)} kg",
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _textPrimary)),
                                Text(
                                    "Avg Puhunan/kg: ₱${overallCostPerKg.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _warningOrange)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    "Estimated Gross: ₱${totalRevenue.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _infoBlue)),
                                Text(
                                    "Avg Tubo/kg: ₱${(overallRevenuePerKg - overallCostPerKg).toStringAsFixed(2)}",
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: totalProfit >= 0
                                            ? _primaryGreen
                                            : _dangerRed)),
                              ],
                            ),
                            const Divider(height: 12, color: Colors.black12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Estimated Tubo / Profit:",
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _textPrimary)),
                                Text(
                                  "₱${totalProfit.toStringAsFixed(2)}",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: totalProfit >= 0
                                        ? _primaryGreen
                                        : _dangerRed,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _infoBlue,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              final nav = Navigator.of(modalContext);
                              final String productName =
                                  "$selectedHectare - $selectedType Palay";

                              final double oldInitialKg =
                                  ((data['initialKg'] ?? data['totalKg'] ?? 0.0)
                                          as num)
                                      .toDouble();
                              final double oldRemainingKg =
                                  ((data['remainingKg'] ?? oldInitialKg)
                                          as num)
                                      .toDouble();
                              final double soldKg =
                                  oldInitialKg - oldRemainingKg;

                              final double newRemainingKg =
                                  (sumKg - soldKg) < 0 ? 0.0 : (sumKg - soldKg);

                              final List<Map<String, dynamic>> breakdowns =
                                  breakdownItems.map((item) {
                                final double bKg =
                                    double.tryParse(item.kgController.text) ??
                                        0.0;
                                final double bSrp =
                                    double.tryParse(item.srpController.text) ??
                                        0.0;
                                final double bAllocatedCost = sumKg > 0
                                    ? (bKg / sumKg) * totalCost
                                    : 0.0;

                                return {
                                  'condition': item.condition,
                                  'kg': bKg,
                                  'srp': bSrp,
                                  'allocatedCost': bAllocatedCost,
                                };
                              }).toList();

                              final Map<String, dynamic> updateData = {
                                'name': productName,
                                'hectare': selectedHectare,
                                'type': selectedType,
                                'description': descriptionController.text.trim(),
                                'totalCost': totalCost,
                                'breakdowns': breakdowns,
                                'initialKg': sumKg,
                                'remainingKg': newRemainingKg,
                                'totalKg': sumKg,
                                'updatedAt': FieldValue.serverTimestamp(),
                              };

                              List<String> finalImageUrls =
                                  List<String>.from(existingImageUrls);

                              if (selectedImages.isNotEmpty) {
                                try {
                                  final newImageUrls = await _uploadProductImages(
                                    selectedImages,
                                    (data['productCode'] ?? doc.id).toString(),
                                  );
                                  finalImageUrls.addAll(newImageUrls);
                                } catch (e, stackTrace) {
                                  debugPrint("EDIT IMAGE UPLOAD FAILED: $e");
                                  debugPrint(stackTrace.toString());

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Hindi ma-upload ang larawan: $e", style: const TextStyle(fontSize: 15)),
                                        backgroundColor: _dangerRed,
                                        duration: const Duration(seconds: 8),
                                      ),
                                    );
                                  }
                                  return;
                                }
                              }

                              if (finalImageUrls.length > 9) {
                                finalImageUrls = finalImageUrls.take(9).toList();
                              }

                              updateData['imageUrls'] = finalImageUrls;
                              updateData['imageUrl'] =
                                  finalImageUrls.isNotEmpty ? finalImageUrls.first : '';

                              await FirebaseFirestore.instance
                                  .collection("products")
                                  .doc(doc.id)
                                  .update(updateData);

                              nav.pop();
                            }
                          },
                          child: const Text("Save Changes",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
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
}