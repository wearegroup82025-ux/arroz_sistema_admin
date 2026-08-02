import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/product_model.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  // Soft Modern Color Palette (Aesthetic & Relaxing)
  static const Color _bgCanvas = Color(0xffF1F5F9);      // Soft Slate Gray
  static const Color _cardBg = Color(0xffFFFFFF);        // Pure White
  static const Color _brandGreen = Color(0xff16A34A);    // Emerald
  static const Color _softGreenBg = Color(0xffDCFCE7);   // Pastel Green Accent
  static const Color _textDark = Color(0xff0F172A);      // Deep Slate
  static const Color _textMuted = Color(0xff64748B);     // Cool Gray
  static const Color _dangerSoft = Color(0xffFEE2E2);    // Pastel Red
  static const Color _dangerText = Color(0xffDC2626);    // Rich Red
  static const Color _borderSoft = Color(0xffE2E8F0);    // Light Border

  String _searchQuery = "";
  String _selectedCategory = "All";

  final List<String> _categories = ["All", "Premium", "Regular", "Local", "Imported"];
  final List<String> _palayNames = [
    "C4 Palay", "C18 Palay", "Jasmine Palay", "R10 Palay", "R42 Palay", "216 Palay"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgCanvas,
      floatingActionButton: FloatingActionButton.extended(
        elevation: 2,
        backgroundColor: _brandGreen,
        onPressed: () => _showAddPalaySheet(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Magdagdag ng Palay", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection("products").snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text("May problema sa koneksyon."));
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _brandGreen));
            }

            final docs = snapshot.data?.docs ?? [];
            final products = docs.map((doc) => ProductModel.fromFirestore(doc)).toList();

            // Dynamic Calculations
            int totalStock = 0;
            int lowStockItems = 0;
            double totalValue = 0;

            for (var p in products) {
              totalStock += p.stock;
              totalValue += (p.stock * p.price);
              if (p.stock <= p.lowStockThreshold) lowStockItems++;
            }

            // Smart Filter
            final filteredList = products.where((p) {
              final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase());
              final matchesCat = _selectedCategory == "All" || p.category == _selectedCategory;
              return matchesSearch && matchesCat;
            }).toList();

            return CustomScrollView(
              slivers: [
                // Clean Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Smart Inventory", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textDark)),
                            SizedBox(height: 2),
                            Text("Subaybayan at pamahalaan ang iyong stocks", style: TextStyle(fontSize: 12, color: _textMuted)),
                          ],
                        ),
                        CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Icon(Icons.inventory, color: _brandGreen),
                        )
                      ],
                    ),
                  ),
                ),

                // Smart Alert Box (Lalabas lang pag may kailangang i-restock)
                if (lowStockItems > 0)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _dangerSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: _dangerText, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Pansin: May $lowStockItems uri ng palay na mababa na ang stock!",
                              style: const TextStyle(color: _dangerText, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Clean Summary Cards
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        _buildSummaryCard("Kabuuan", "$totalStock Sako", Icons.widgets_outlined, _softGreenBg, _brandGreen),
                        const SizedBox(width: 12),
                        _buildSummaryCard("Halaga", "₱${(totalValue/1000).toStringAsFixed(1)}k", Icons.payments_outlined, Colors.blue.shade50, Colors.blue.shade700),
                      ],
                    ),
                  ),
                ),

                // Controls Bar (Search + Chips)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Soft Search Field
                        TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: "Maghanap ng palay...",
                            hintStyle: const TextStyle(fontSize: 13, color: _textMuted),
                            prefixIcon: const Icon(Icons.search, color: _textMuted, size: 20),
                            filled: true,
                            fillColor: _cardBg,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderSoft)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brandGreen)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Soft Filter Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _categories.map((cat) {
                              final isSelected = _selectedCategory == cat;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(cat),
                                  selected: isSelected,
                                  selectedColor: _brandGreen,
                                  backgroundColor: _cardBg,
                                  side: BorderSide(color: isSelected ? _brandGreen : _borderSoft),
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.white : _textMuted,
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  onSelected: (_) => setState(() => _selectedCategory = cat),
                                ),
                              );
                            }).toList(),
                          ),
                        )
                      ],
                    ),
                  ),
                ),

                // Responsive Cards Grid
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: filteredList.isEmpty
                      ? const SliverToBoxAdapter(child: Center(child: Text("Walang nahanap na stock.", style: TextStyle(color: _textMuted))))
                      : SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : (MediaQuery.of(context).size.width > 500 ? 2 : 1),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.6,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildMinimalCard(filteredList[index]),
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

  // ================= UI HELPER WIDGETS =================

  Widget _buildSummaryCard(String title, String val, IconData icon, Color bg, Color iconColor) {
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
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: _textMuted)),
                Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textDark)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalCard(ProductModel product) {
    bool isLow = product.stock <= product.lowStockThreshold;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isLow ? Colors.orange.shade200 : _borderSoft, width: isLow ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _textDark)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isLow ? _dangerSoft : _softGreenBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isLow ? "Low Stock" : "Sapat",
                  style: TextStyle(color: isLow ? _dangerText : _brandGreen, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
          Text("${product.category} • ${product.metricDetail}", style: const TextStyle(color: _textMuted, fontSize: 11)),
          const Divider(height: 10, color: _borderSoft),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Presyo/kg", style: TextStyle(fontSize: 10, color: _textMuted)),
                  Text("₱${product.price}", style: const TextStyle(fontWeight: FontWeight.bold, color: _textDark)),
                ],
              ),
              InkWell(
                onTap: () => _showQuickAdjustModal(product),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _bgCanvas,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text("${product.stock} Sako", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _textDark)),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_outlined, size: 14, color: _brandGreen),
                    ],
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  // Quick Stock Adjustment Bottom Sheet
  void _showQuickAdjustModal(ProductModel p) {
    int current = p.stock;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("I-adjust ang Stock para sa ${p.name}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        onPressed: () {
                          if (current > 0) setModalState(() => current--);
                        },
                        icon: const Icon(Icons.remove),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text("$current Sako", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => setModalState(() => current++),
                        icon: const Icon(Icons.add),
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
                        if (p.id != null) {
                          await FirebaseFirestore.instance.collection("products").doc(p.id).update({'stock': current});
                        }
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text("I-save ang Stock", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  // Quick Add Sheet
  void _showAddPalaySheet(BuildContext context) {
    String name = _palayNames.first;
    String cat = "Premium";
    final stockController = TextEditingController();
    final priceController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Dagdag Bagong Palay Batch", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: name,
                decoration: const InputDecoration(labelText: "Uri ng Palay", border: OutlineInputBorder()),
                items: _palayNames.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => name = val!,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Ilang Sako", border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Presyo/Kilo", border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _brandGreen),
                  onPressed: () async {
                    if (stockController.text.isNotEmpty && priceController.text.isNotEmpty) {
                      final newProduct = ProductModel(
                        name: name,
                        category: cat,
                        metricDetail: "Fresh Dry",
                        price: double.parse(priceController.text),
                        stock: int.parse(stockController.text),
                        createdAt: DateTime.now(),
                      );
                      await FirebaseFirestore.instance.collection("products").add(newProduct.toFirestore());
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text("I-Save sa Inventory", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}