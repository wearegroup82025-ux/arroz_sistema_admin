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
  // Ultra-Clean Modern Responsive Palette
  static const Color _bgCanvas = Color(0xffF8FAFC);      // Off-White Background
  static const Color _cardBg = Color(0xffFFFFFF);        // White Card
  static const Color _brandGreen = Color(0xff16A34A);    // Primary Emerald Green
  static const Color _softGreenBg = Color(0xffDCFCE7);   // Soft Green Tint
  static const Color _textDark = Color(0xff0F172A);      // Dark Text
  static const Color _textMuted = Color(0xff64748B);     // Soft Gray Text
  static const Color _dangerSoft = Color(0xffFEE2E2);    // Red Tint for Warnings
  static const Color _dangerText = Color(0xffDC2626);    // Bright Warning Red
  static const Color _borderSoft = Color(0xffE2E8F0);    // Light Border

  String _searchQuery = "";

  final List<String> _palayNames = [
    "C4 Palay", "C18 Palay", "Jasmine Palay", "R10 Palay", "R42 Palay", "216 Palay"
  ];

  @override
  Widget build(BuildContext context) {
    // Responsive Screen Width Check
    final double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 1; // Default sa CP
    if (screenWidth > 1024) {
      crossAxisCount = 3; // Laptop / Large Screen
    } else if (screenWidth > 600) {
      crossAxisCount = 2; // Tablet / iPad Screen
    }

    return Scaffold(
      backgroundColor: _bgCanvas,
      // Floating Action Button (Malaki at madaling pindutin sa CP)
      floatingActionButton: FloatingActionButton.extended(
        elevation: 3,
        backgroundColor: _brandGreen,
        onPressed: () => _showAddPalaySheet(context),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
        label: const Text(
          "Magdagdag ng Palay",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection("products").snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text("May problema sa koneksyon.", style: TextStyle(color: _dangerText, fontWeight: FontWeight.bold)),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _brandGreen));
            }

            final docs = snapshot.data?.docs ?? [];
            final products = docs.map((doc) => ProductModel.fromFirestore(doc)).toList();

            // Total Computations
            int totalStockCount = 0;
            int lowStockItems = 0;
            double totalInventoryValue = 0;

            for (var p in products) {
              totalStockCount += p.stock;
              totalInventoryValue += (p.stock * p.price);
              if (p.stock <= p.lowStockThreshold) lowStockItems++;
            }

            // Direct Search Filtering (No Categories)
            final filteredList = products.where((p) {
              return p.name.toLowerCase().contains(_searchQuery.toLowerCase());
            }).toList();

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 1. HEADER TITLE
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Inbentaryo ng Palay",
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textDark),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Madaling pagsubaybay sa bodega",
                              style: TextStyle(fontSize: 12, color: _textMuted),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: _borderSoft),
                          ),
                          child: const Icon(Icons.warehouse_rounded, color: _brandGreen, size: 22),
                        )
                      ],
                    ),
                  ),
                ),

                // 2. WARNING BANNER (KAPAG KONTI NALANG ANG STOCK)
                if (lowStockItems > 0)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _dangerSoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _dangerText.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: _dangerText, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Pansin: May $lowStockItems uri ng palay na kakaunti nalang ang sako!",
                              style: const TextStyle(color: _dangerText, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 3. DASHBOARD SUMMARY CARDS (RESPONSIVE)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        _buildSimpleStatCard("Kabuuang Sako", "$totalStockCount Sako", Icons.inventory_2_outlined, _softGreenBg, _brandGreen),
                        const SizedBox(width: 10),
                        _buildSimpleStatCard("Halaga sa Bodega", "₱${(totalInventoryValue / 1000).toStringAsFixed(1)}k", Icons.payments_outlined, Colors.blue.shade50, Colors.blue.shade700),
                      ],
                    ),
                  ),
                ),

                // 4. CLEAN SEARCH BAR (WALANG MAGULONG CATEGORY BUTTONS)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: "Maghanap ng pangalan ng palay...",
                        hintStyle: const TextStyle(fontSize: 13, color: _textMuted),
                        prefixIcon: const Icon(Icons.search_rounded, color: _textMuted, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: _textMuted),
                                onPressed: () => setState(() => _searchQuery = ""),
                              )
                            : null,
                        filled: true,
                        fillColor: _cardBg,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _borderSoft)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _brandGreen, width: 1.5)),
                      ),
                    ),
                  ),
                ),

                // 5. RESPONSIVE GRID LIST OF PRODUCTS
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
                  sliver: filteredList.isEmpty
                      ? const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(30.0),
                            child: Center(
                              child: Text("Walang nahanap na uri ng palay.", style: TextStyle(color: _textMuted, fontSize: 13)),
                            ),
                          ),
                        )
                      : SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: screenWidth > 600 ? 1.6 : 1.45,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildProductCard(filteredList[index]),
                            childCount: filteredList.length,
                          ),
                        ),
                )
              ],
            );
          },
        ),
      ),
    );
  }

  // ================= EASY TO UNDERSTAND CARDS =================

  Widget _buildSimpleStatCard(String label, String value, IconData icon, Color bg, Color iconColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderSoft),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: _textMuted, fontWeight: FontWeight.w500)),
                  Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _textDark)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    bool isLow = product.stock <= product.lowStockThreshold;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLow ? _dangerText.withOpacity(0.4) : _borderSoft,
          width: isLow ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Pangalan at Status Label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _textDark),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isLow ? _dangerSoft : _softGreenBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isLow ? "Konti nalang!" : "Sapat pa",
                  style: TextStyle(
                    color: isLow ? _dangerText : _brandGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            ],
          ),

          const SizedBox(height: 8),

          // Presyo at Laman ng Stock
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Presyo bawat Kilo", style: TextStyle(fontSize: 10, color: _textMuted)),
                  Text("₱${product.price.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _textDark)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("Laman sa Bodega", style: TextStyle(fontSize: 10, color: _textMuted)),
                  Text("${product.stock} Sako", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isLow ? _dangerText : _brandGreen)),
                ],
              ),
            ],
          ),

          const Divider(height: 16, color: _borderSoft),

          // Pindutan para magbawas o magdagdag agad
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _borderSoft),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                backgroundColor: _bgCanvas,
              ),
              onPressed: () => _showQuickAdjustModal(product),
              icon: const Icon(Icons.edit_note_rounded, size: 18, color: _brandGreen),
              label: const Text("I-adjust ang Sako", style: TextStyle(color: _textDark, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          )
        ],
      ),
    );
  }

  // ================= SIMPLE & EASY MODALS =================

  // Quick Modal para palitan ang bilang ng sako (Direct type o Buttons)
  void _showQuickAdjustModal(ProductModel p) {
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

            void updateVal(int newVal) {
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
                  Text("I-adjust ang Sako para sa ${p.name}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _textDark)),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Subtract Button
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(backgroundColor: _bgCanvas),
                        onPressed: () => updateVal(currentVal - 1),
                        icon: const Icon(Icons.remove, color: _textDark),
                      ),
                      const SizedBox(width: 12),

                      // Direct Type Keyboard Field (Numbers Only)
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            suffixText: "Sako",
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderSoft)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _brandGreen, width: 2)),
                          ),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Add Button
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(backgroundColor: _softGreenBg),
                        onPressed: () => updateVal(currentVal + 1),
                        icon: const Icon(Icons.add, color: _brandGreen),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _brandGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: () async {
                        final updatedStock = int.tryParse(controller.text) ?? p.stock;
                        if (p.id != null) {
                          await FirebaseFirestore.instance.collection("products").doc(p.id).update({'stock': updatedStock});
                        }
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text("I-save ang Bagong Bilang", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  // Easy Add Palay Form (Smart Duplicate Prevention)
  void _showAddPalaySheet(BuildContext context) {
    String selectedName = _palayNames.first;
    final stockController = TextEditingController();
    final priceController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Magdagdag ng Palay sa Bodega", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textDark)),
              const SizedBox(height: 4),
              const Text("Kapag meron na sa listahan, kusa itong idadagdag sa lumang stock.", style: TextStyle(fontSize: 11, color: _textMuted)),
              const SizedBox(height: 16),

              // Dropdown
              DropdownButtonFormField<String>(
                value: selectedName,
                decoration: InputDecoration(
                  labelText: "Pumili ng Uri ng Palay",
                  filled: true,
                  fillColor: _bgCanvas,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderSoft)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _brandGreen)),
                ),
                items: _palayNames.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => selectedName = val!,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: stockController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: "Ilang Sako",
                        filled: true,
                        fillColor: _bgCanvas,
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderSoft)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _brandGreen)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: "Presyo bawat Kilo",
                        filled: true,
                        fillColor: _bgCanvas,
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderSoft)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _brandGreen)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _brandGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () async {
                    if (stockController.text.isNotEmpty && priceController.text.isNotEmpty) {
                      final inputStock = int.parse(stockController.text);
                      final inputPrice = double.parse(priceController.text);

                      // PREVENT DUPLICATES ON FIRESTORE
                      final querySnapshot = await FirebaseFirestore.instance
                          .collection("products")
                          .where("name", isEqualTo: selectedName)
                          .limit(1)
                          .get();

                      if (querySnapshot.docs.isNotEmpty) {
                        // Product already exists -> Add stock quantity
                        final existingDoc = querySnapshot.docs.first;
                        final currentStock = existingDoc.get('stock') ?? 0;

                        await FirebaseFirestore.instance.collection("products").doc(existingDoc.id).update({
                          'stock': currentStock + inputStock,
                          'price': inputPrice,
                        });
                      } else {
                        // Product doesn't exist -> Create new record
                        final newProduct = ProductModel(
                          name: selectedName,
                          category: "Regular",
                          metricDetail: "Fresh Dry",
                          price: inputPrice,
                          stock: inputStock,
                          createdAt: DateTime.now(),
                        );
                        await FirebaseFirestore.instance.collection("products").add(newProduct.toFirestore());
                      }

                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text("I-Save sa Bodega", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}