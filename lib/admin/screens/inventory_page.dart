import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product_model.dart';

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
  static const Color _warningOrangeBg = Color(0xFFFEF3C7);
  static const Color _dangerRed = Color(0xFFDC2626);
  static const Color _dangerRedBg = Color(0xFFFEE2E2);
  static const Color _infoBlue = Color(0xFF2563EB);

  String _searchQuery = "";
  bool _isPerKiloView = false;

  final List<String> _palayTypes = [
    "C4 Palay",
    "C18 Palay",
    "Jasmine Palay",
    "R10 Palay",
    "R42 Palay",
    "216 Palay"
  ];

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
        elevation: 2,
        backgroundColor: _primaryGreen,
        onPressed: () => _showAddProductModal(context),
        icon: const Icon(Icons.add_box_rounded, color: Colors.white, size: 20),
        label: const Text(
          "Magdagdag ng Stocks",
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
            final products = docs
                .map((doc) => ProductModel.fromFirestore(doc))
                .where((p) {
                  final rawData = docs.firstWhere((d) => d.id == p.id).data() as Map<String, dynamic>?;
                  return rawData?['isDeleted'] != true;
                })
                .toList();

            double totalInventoryValue = 0.0;
            int totalStockUnits = 0;
            int criticalStockCount = 0;

            for (var p in products) {
              final double unitKg = p.unitKg > 0 ? p.unitKg : 50.0;
              final double sakoSellingPrice = p.sellingPrice * unitKg;
              totalInventoryValue += (p.stock * sakoSellingPrice);
              totalStockUnits += p.stock;
              if (p.stock <= p.lowStockThreshold) {
                criticalStockCount++;
              }
            }

            final filteredProducts = products.where((p) {
              return p.name.toLowerCase().contains(_searchQuery.toLowerCase());
            }).toList();

            return Column(
              children: [
                _buildHeaderAndAnalytics(
                  totalValue: totalInventoryValue,
                  totalStock: totalStockUnits,
                  criticalCount: criticalStockCount,
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: "Maghanap ng uri ng palay...",
                            hintStyle: const TextStyle(fontSize: 13, color: _textSecondary),
                            prefixIcon: const Icon(Icons.search_rounded, color: _textSecondary, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18, color: _textSecondary),
                                    onPressed: () => setState(() => _searchQuery = ""),
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
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      Material(
                        color: _isPerKiloView ? _infoBlue : _primaryGreen,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _isPerKiloView = !_isPerKiloView;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  _isPerKiloView ? "PER KILO" : "PER SAKO",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: filteredProducts.isEmpty
                      ? const Center(
                          child: Text("Walang nahanap na item sa inbentaryo.",
                              style: TextStyle(color: _textSecondary, fontSize: 13)),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
                          itemCount: filteredProducts.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _buildSmartInventoryCard(filteredProducts[index]);
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

  // ================= UI COMPONENTS =================

  Widget _buildHeaderAndAnalytics({
    required double totalValue,
    required int totalStock,
    required int criticalCount,
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
                  Text("Smart Inventory System",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary)),
                  SizedBox(height: 2),
                  Text("Real-time valuation & stock tracking",
                      style: TextStyle(fontSize: 12, color: _textSecondary)),
                ],
              ),
              Icon(Icons.inventory_rounded, color: _primaryGreen, size: 28),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMetricCard("Kabuuan Halaga", _formatCurrency(totalValue), Icons.account_balance_wallet_outlined, _infoBlue),
              const SizedBox(width: 8),
              _buildMetricCard("Kabuuang Stock", "$totalStock Sako", Icons.inventory_2_outlined, _primaryGreen),
              const SizedBox(width: 8),
              _buildMetricCard("Kulang sa Stock", "$criticalCount Uri", Icons.error_outline_rounded, criticalCount > 0 ? _dangerRed : _textSecondary),
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
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: accentColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartInventoryCard(ProductModel product) {
    Color statusBg;
    Color statusText;
    String statusLabel;

    if (product.stock == 0) {
      statusBg = _dangerRedBg;
      statusText = _dangerRed;
      statusLabel = "Ubôs na";
    } else if (product.stock <= product.lowStockThreshold) {
      statusBg = _warningOrangeBg;
      statusText = _warningOrange;
      statusLabel = "Kulang na";
    } else {
      statusBg = _primaryGreenSoft;
      statusText = _primaryGreen;
      statusLabel = "Sapat pa";
    }

    final double unitKg = product.unitKg > 0 ? product.unitKg : 50.0;
    
    final double sakoPrice = product.price;
    final double sakoSellingPrice = product.sellingPrice * unitKg;
    final double sakoProfit = sakoSellingPrice - sakoPrice;

    final double kiloPrice = sakoPrice / unitKg;
    final double kiloSellingPrice = product.sellingPrice;
    final double kiloProfit = kiloSellingPrice - kiloPrice;

    final double displayCost = _isPerKiloView ? kiloPrice : sakoPrice;
    final double displaySelling = _isPerKiloView ? kiloSellingPrice : sakoSellingPrice;
    final double displayProfit = _isPerKiloView ? kiloProfit : sakoProfit;
    final String unitLabel = _isPerKiloView ? "/kg" : "/sako (${unitKg.toStringAsFixed(0)}kg)";

    final double totalItemValuation = product.stock * sakoSellingPrice;
    final double totalKilosInStock = product.stock * unitKg;

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
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary),
                      ),
                      Text(
                        "1 Sako = ${unitKg.toStringAsFixed(0)} kg",
                        style: const TextStyle(fontSize: 10, color: _textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusText),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: _textSecondary),
                  onPressed: () => _confirmDeleteProduct(context, product),
                )
              ],
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surfaceBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderLine.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isPerKiloView ? "PRESYO PER KILO" : "PRESYO PER SAKO",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _isPerKiloView ? _infoBlue : _primaryGreen,
                        ),
                      ),
                      Icon(Icons.swap_horizontal_circle_outlined, 
                           size: 16, 
                           color: _isPerKiloView ? _infoBlue : _primaryGreen),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildPriceColumn("Puhunan $unitLabel", "₱${displayCost.toStringAsFixed(2)}", _textPrimary),
                      Container(height: 20, width: 1, color: _borderLine),
                      _buildPriceColumn("Benta $unitLabel", "₱${displaySelling.toStringAsFixed(2)}", _primaryGreen),
                      Container(height: 20, width: 1, color: _borderLine),
                      _buildPriceColumn("Tubó $unitLabel", "${displayProfit >= 0 ? '+' : ''}₱${displayProfit.toStringAsFixed(2)}", displayProfit >= 0 ? _primaryGreen : _dangerRed),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Laman sa Bodega", style: TextStyle(fontSize: 11, color: _textSecondary)),
                    Text("${product.stock} Sako",
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
                    Text("(${totalKilosInStock.toStringAsFixed(0)} Total Kg)",
                        style: const TextStyle(fontSize: 10, color: _textSecondary, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Kabuuang Halaga ng Stock", style: TextStyle(fontSize: 11, color: _textSecondary)),
                    Text(_formatCurrency(totalItemValuation),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _infoBlue)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _borderLine),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  backgroundColor: _cardBg,
                ),
                onPressed: () => _showStockAdjustModal(product),
                icon: const Icon(Icons.edit_note_rounded, size: 16, color: _primaryGreen),
                label: const Text("I-adjust ang Bilang ng Sako",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textPrimary)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPriceColumn(String label, String price, Color priceColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: _textSecondary)),
        const SizedBox(height: 2),
        Text(price, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: priceColor)),
      ],
    );
  }

  void _confirmDeleteProduct(BuildContext context, ProductModel product) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("I-delete ang Item?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Text("Sigurado ka bang gusto mong alisin ang ${product.name} sa inbentaryo?",
              style: const TextStyle(fontSize: 12, color: _textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("I-cancel", style: TextStyle(color: _textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _dangerRed,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (product.id != null) {
                  await FirebaseFirestore.instance.collection("products").doc(product.id).update({'isDeleted': true});
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("I-delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showStockAdjustModal(ProductModel p) {
    final controller = TextEditingController(text: p.stock.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            int currentVal = int.tryParse(controller.text) ?? 0;

            void updateValue(int newVal) {
              if (newVal >= 0) {
                setModalState(() {
                  controller.text = newVal.toString();
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("I-adjust ang Stock (Sako) - ${p.name}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _textPrimary)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(backgroundColor: _surfaceBg),
                        onPressed: () => updateValue(currentVal - 1),
                        icon: const Icon(Icons.remove, color: _textPrimary),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            suffixText: "Sako",
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: _borderLine)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: _primaryGreen, width: 2)),
                          ),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(backgroundColor: _primaryGreenSoft),
                        onPressed: () => updateValue(currentVal + 1),
                        icon: const Icon(Icons.add, color: _primaryGreen),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final updatedStock = int.tryParse(controller.text) ?? p.stock;
                        if (p.id != null) {
                          await FirebaseFirestore.instance.collection("products").doc(p.id).update({'stock': updatedStock});
                        }
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text("I-save ang Bagong Stock", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ================= DYNAMIC AUTOMATIC CONVERSION MODAL =================

  void _showAddProductModal(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    String selectedName = _palayTypes.first;
    
    bool isInputPerKilo = false; // false = Sako, true = Kilo

    final stockController = TextEditingController();
    final costController = TextEditingController();
    final sellingController = TextEditingController();
    final unitKgController = TextEditingController(text: "50");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double unitKg = double.tryParse(unitKgController.text) ?? 50.0;
            final double rawCost = double.tryParse(costController.text) ?? 0.0;
            final double rawSelling = double.tryParse(sellingController.text) ?? 0.0;

            // REAL-TIME AUTOMATIC CONVERSION CALCULATIONS
            double calculatedCostSako = 0.0;
            double calculatedCostKilo = 0.0;
            double calculatedSellingSako = 0.0;
            double calculatedSellingKilo = 0.0;

            if (isInputPerKilo) {
              calculatedCostKilo = rawCost;
              calculatedCostSako = rawCost * unitKg;

              calculatedSellingKilo = rawSelling;
              calculatedSellingSako = rawSelling * unitKg;
            } else {
              calculatedCostSako = rawCost;
              calculatedCostKilo = unitKg > 0 ? rawCost / unitKg : 0.0;

              calculatedSellingSako = rawSelling;
              calculatedSellingKilo = unitKg > 0 ? rawSelling / unitKg : 0.0;
            }

            final double calculatedProfitSako = calculatedSellingSako - calculatedCostSako;
            final double calculatedProfitKilo = calculatedSellingKilo - calculatedCostKilo;

            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                          const Text("Magdagdag ng Stocks",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
                          
                          // DYNAMIC UNIT INPUT SELECTOR
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: _surfaceBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _borderLine),
                            ),
                            child: Row(
                              children: [
                                _buildModeChip("PER SAKO", !isInputPerKilo, () {
                                  setModalState(() => isInputPerKilo = false);
                                }),
                                _buildModeChip("PER KILO", isInputPerKilo, () {
                                  setModalState(() => isInputPerKilo = true);
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: selectedName,
                        decoration: InputDecoration(
                          labelText: "Uri ng Palay",
                          filled: true,
                          fillColor: _surfaceBg,
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderLine)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryGreen)),
                        ),
                        items: _palayTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) => selectedName = val!,
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: stockController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              validator: (v) => (v == null || v.isEmpty) ? "Kailangan" : null,
                              decoration: InputDecoration(
                                labelText: "Dami ng Sako",
                                filled: true,
                                fillColor: _surfaceBg,
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderLine)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryGreen)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: unitKgController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) => (v == null || v.isEmpty) ? "Kailangan" : null,
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(
                                labelText: "Kg / Sako (e.g. 50)",
                                filled: true,
                                fillColor: _surfaceBg,
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderLine)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryGreen)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // INPUT COST & SELLING FIELDS
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: costController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) => (v == null || v.isEmpty) ? "Kailangan" : null,
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(
                                labelText: isInputPerKilo ? "Puhunan / Kilo (₱)" : "Puhunan / Sako (₱)",
                                filled: true,
                                fillColor: _surfaceBg,
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderLine)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryGreen)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: sellingController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) => (v == null || v.isEmpty) ? "Kailangan" : null,
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(
                                labelText: isInputPerKilo ? "Benta / Kilo (₱)" : "Benta / Sako (₱)",
                                filled: true,
                                fillColor: _surfaceBg,
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderLine)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryGreen)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // AUTOMATIC PREVIEW CONVERSION CARD
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
                            Text(
                              "Awtomatikong Kwenta (${isInputPerKilo ? 'Converted to Sako' : 'Converted to Kilo'}):",
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _textSecondary),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Puhunan: ₱${calculatedCostSako.toStringAsFixed(2)} /sako  (₱${calculatedCostKilo.toStringAsFixed(2)}/kg)",
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _textPrimary),
                                ),
                              ],
                            ),
                            Text(
                              "Benta: ₱${calculatedSellingSako.toStringAsFixed(2)} /sako  (₱${calculatedSellingKilo.toStringAsFixed(2)}/kg)",
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _primaryGreen),
                            ),
                            const Divider(height: 12),
                            Text(
                              "Kikitain (Tubó): +₱${calculatedProfitSako.toStringAsFixed(2)} /sako  (+₱${calculatedProfitKilo.toStringAsFixed(2)}/kg)",
                              style: TextStyle(
                                fontSize: 11, 
                                fontWeight: FontWeight.bold, 
                                color: calculatedProfitSako >= 0 ? _primaryGreen : _dangerRed
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // SAVE BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryGreen,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              final inputStock = int.parse(stockController.text);

                              // Save standardized format to DB
                              final finalSakoPrice = calculatedCostSako;
                              final finalKiloSellingPrice = calculatedSellingKilo;

                              final querySnapshot = await FirebaseFirestore.instance
                                  .collection("products")
                                  .where("name", isEqualTo: selectedName)
                                  .get();

                              DocumentSnapshot? activeDoc;
                              for (var doc in querySnapshot.docs) {
                                final data = doc.data() as Map<String, dynamic>?;
                                if (data?['isDeleted'] != true) {
                                  activeDoc = doc;
                                  break;
                                }
                              }

                              if (activeDoc != null) {
                                final currentStock = activeDoc.get('stock') ?? 0;
                                await FirebaseFirestore.instance.collection("products").doc(activeDoc.id).update({
                                  'stock': currentStock + inputStock,
                                  'price': finalSakoPrice,
                                  'sellingPrice': finalKiloSellingPrice,
                                  'unit': "Sako",
                                  'unitKg': unitKg,
                                  'isDeleted': false,
                                });
                              } else {
                                final newProduct = ProductModel(
                                  name: selectedName,
                                  category: "Regular",
                                  unit: "Sako",
                                  unitKg: unitKg,
                                  price: finalSakoPrice,
                                  sellingPrice: finalKiloSellingPrice,
                                  stock: inputStock,
                                  lowStockThreshold: 10,
                                  createdAt: DateTime.now(),
                                );
                                await FirebaseFirestore.instance.collection("products").add(newProduct.toFirestore());
                              }

                              if (context.mounted) Navigator.pop(context);
                            }
                          },
                          child: const Text("I-save sa Bodega", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildModeChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? _primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : _textSecondary,
          ),
        ),
      ),
    );
  }
}