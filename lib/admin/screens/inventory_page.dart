import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum ProductType { palay, rice }

// ==================== SENIOR DATA MODEL LAYER ====================
class ProductModel {
  final String? id;
  final String name;
  final ProductType type;
  final String category;
  final String metricDetail;
  final double price;
  final int stock;
  final int lowStockThreshold;
  final DateTime createdAt;
  final String imageUrl;

  ProductModel({
    this.id,
    required this.name,
    required this.type,
    required this.category,
    required this.metricDetail,
    required this.price,
    required this.stock,
    this.lowStockThreshold = 50,
    required this.createdAt,
    this.imageUrl = "",
  });

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ProductModel(
      id: doc.id,
      name: data['name'] ?? '',
      type: data['type'] == 'rice' ? ProductType.rice : ProductType.palay,
      category: data['category'] ?? 'General',
      metricDetail: data['metricDetail'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      stock: data['stock'] ?? 0,
      lowStockThreshold: data['lowStockThreshold'] ?? 50,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: data['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name.trim(),
      'type': type.name, 
      'category': category.trim(),
      'metricDetail': metricDetail.trim(),
      'price': price,
      'stock': stock,
      'lowStockThreshold': lowStockThreshold,
      'createdAt': Timestamp.fromDate(createdAt),
      'imageUrl': imageUrl,
    };
  }
}

// ==================== MAIN PAGE VIEW LAYER ====================
class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  static const Color _primaryGreen = Color(0xff16A34A); 
  static const Color _bgSurface = Color(0xffF8FAFC); 
  static const Color _textPrimary = Color(0xff0F172A); 
  static const Color _textSecondary = Color(0xff64748B); 
  static const Color _border = Color(0xffE2E8F0);
  static const Color _dangerColor = Color(0xffEF4444);
  static const Color _warningColor = Color(0xffF59E0B);

  ProductType _selectedFilter = ProductType.palay;
  String _searchQuery = "";

  // MGA DATA ARRAYS PARA SA MGA DROPDOWNS MO
  final List<String> _riceVarieties = ["Dinorado Rice", "Sinandomeng Rice", "Jasmine Rice", "RC216 Milled", "Well-Milled Local"];
  final List<String> _palayVarieties = ["RC222 Raw Palay", "NSIC Rc222", "Premium Palay Batch", "Dry Palay Grade A"];
  
  final List<String> _categories = ["Premium", "Regular", "Local", "Imported"];
  
  final List<String> _metricSpecs = ["14% Moisture (Dry)", "Well-Milled", "Premium Grade", "Freshly Harvested", "Double Polished"];
  final List<int> _thresholdOptions = [20, 30, 50, 100, 150];

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1000;
    final isMobile = screenWidth < 600;

    int crossAxisCount = screenWidth > 1400 ? 4 : (screenWidth > 900 ? 3 : (screenWidth > 600 ? 2 : 1));
    double childAspectRatio = isMobile ? 1.6 : (screenWidth > 1200 ? 1.4 : 1.25);

    return Scaffold(
      backgroundColor: _bgSurface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddProductModal(context),
        backgroundColor: _primaryGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          isMobile ? "Add Stock" : "Add New Stock", 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection("products").snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _primaryGreen));
            }

            final allDocs = snapshot.data?.docs ?? [];

            final filteredDocs = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final String dbType = data['type'] ?? 'palay';
              final itemType = dbType == 'rice' ? ProductType.rice : ProductType.palay;
              
              if (itemType != _selectedFilter) return false;

              final String name = (data['name'] ?? '').toLowerCase();
              final String metric = (data['metricDetail'] ?? '').toLowerCase();
              return name.contains(_searchQuery.toLowerCase()) || metric.contains(_searchQuery.toLowerCase());
            }).toList();

            int totalSacks = 0;
            int lowStockCount = 0;

            for (var doc in allDocs) {
              final data = doc.data() as Map<String, dynamic>;
              final String dbType = data['type'] ?? 'palay';
              final itemType = dbType == 'rice' ? ProductType.rice : ProductType.palay;

              if (itemType == _selectedFilter) {
                int stock = data['stock'] ?? 0;
                int threshold = data['lowStockThreshold'] ?? 50;
                totalSacks += stock;
                if (stock <= threshold) lowStockCount++;
              }
            }

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER SECTION
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Inventory Dashboard",
                        style: TextStyle(
                          color: _textPrimary, 
                          fontSize: isMobile ? 22 : 26, 
                          fontWeight: FontWeight.bold, 
                          letterSpacing: -0.5
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Monitor stockpile, process yields, and run operations smoothly.",
                        style: TextStyle(color: _textSecondary, fontSize: isMobile ? 12 : 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // KPI CARDS ROW (Responsive Grid/Row)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 500) {
                        return Column(
                          children: [
                            _buildKPICard("Total On-Hand Sacks", totalSacks.toString(), Icons.layers, _primaryGreen),
                            const SizedBox(height: 10),
                            _buildKPICard(
                              "Low Stock Warnings", 
                              lowStockCount.toString(), 
                              Icons.gpp_maybe_outlined, 
                              lowStockCount > 0 ? _dangerColor : _textSecondary
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: _buildKPICard("Total On-Hand Sacks", totalSacks.toString(), Icons.layers, _primaryGreen)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildKPICard(
                              "Low Stock Warnings", 
                              lowStockCount.toString(), 
                              Icons.gpp_maybe_outlined, 
                              lowStockCount > 0 ? _dangerColor : _textSecondary
                            )
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // CONTROLS BAR (TABS + SEARCH FIELD)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white, 
                          borderRadius: BorderRadius.circular(12), 
                          border: Border.all(color: _border)
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTabButton("🌾 Palay", ProductType.palay),
                            _buildTabButton("🍚 Rice", ProductType.rice),
                          ],
                        ),
                      ),
                      
                      SizedBox(
                        width: isDesktop ? 300 : (isMobile ? double.infinity : 250),
                        height: 42,
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: "Search stock...",
                            hintStyle: const TextStyle(color: _textSecondary, fontSize: 13),
                            prefixIcon: const Icon(Icons.search, size: 18, color: _textSecondary),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primaryGreen, width: 1.5)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // GRID VIEW FOR STOCKS
                  Expanded(
                    child: filteredDocs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 48, color: _textSecondary.withValues(alpha: 0.4)),
                                const SizedBox(height: 12),
                                Text("No stock entries matched your scope.", style: TextStyle(color: _textSecondary, fontSize: 14)),
                              ],
                            ),
                          )
                        : GridView.builder(
                            itemCount: filteredDocs.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: childAspectRatio, 
                            ),
                            itemBuilder: (context, index) {
                              final doc = filteredDocs[index];
                              final data = doc.data() as Map<String, dynamic>;
                              return _buildPremiumStockCard(data, doc.id);
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ==================== WIDGET BUILDERS ====================
  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), radius: 20, child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, ProductType type) {
    final isActive = _selectedFilter == type;
    return GestureDetector(
      onTap: () => setState(() { _selectedFilter = type; _searchQuery = ""; }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? _bgSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(color: isActive ? _primaryGreen : _textPrimary, fontWeight: isActive ? FontWeight.bold : FontWeight.w500, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildPremiumStockCard(Map<String, dynamic> data, String docId) {
    int currentStock = data['stock'] ?? 0;
    int threshold = data['lowStockThreshold'] ?? 50;
    bool isLowStock = currentStock <= threshold;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isLowStock ? _warningColor.withValues(alpha: 0.5) : _border, width: isLowStock ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name'] ?? 'No Name', 
                      style: const TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data['metricDetail'] ?? 'No Details', 
                      style: const TextStyle(color: _textSecondary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isLowStock ? _dangerColor.withValues(alpha: 0.1) : _primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isLowStock ? "Low Stock" : "Healthy",
                  style: TextStyle(color: isLowStock ? _dangerColor : _primaryGreen, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text("On Hand:", style: TextStyle(color: _textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
              Text(
                "$currentStock Sacks",
                style: TextStyle(color: isLowStock ? _warningColor : _textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                foregroundColor: _textPrimary,
                padding: EdgeInsets.zero,
              ),
              onPressed: () => _openStockManagementPanel(data, docId),
              icon: const Icon(Icons.tune, size: 14),
              label: const Text("Manage Stock", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          )
        ],
      ),
    );
  }

  void _openStockManagementPanel(Map<String, dynamic> data, String docId) {
    int adjustmentValue = 0;
    bool isStockIn = true; 
    final textController = TextEditingController(text: "0");
    int currentStock = data['stock'] ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Stock Adjustment Hub", style: TextStyle(color: _textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text(data['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: _textSecondary))
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          avatar: Icon(Icons.add, color: isStockIn ? Colors.white : _primaryGreen, size: 16),
                          label: const Center(child: Text("STOCK IN")),
                          selected: isStockIn,
                          selectedColor: _primaryGreen,
                          backgroundColor: _bgSurface,
                          labelStyle: TextStyle(color: isStockIn ? Colors.white : _textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                          onSelected: (val) => setModalState(() => isStockIn = true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          avatar: Icon(Icons.remove, color: !isStockIn ? Colors.white : _dangerColor, size: 16),
                          label: const Center(child: Text("STOCK OUT")),
                          selected: !isStockIn,
                          selectedColor: _dangerColor,
                          backgroundColor: _bgSurface,
                          labelStyle: TextStyle(color: !isStockIn ? Colors.white : _textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                          onSelected: (val) => setModalState(() => isStockIn = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (adjustmentValue > 0) {
                            setModalState(() { adjustmentValue--; textController.text = adjustmentValue.toString(); });
                          }
                        },
                        icon: const Icon(Icons.remove_circle_outline, size: 32, color: _textSecondary),
                      ),
                      Container(
                        width: 90,
                        alignment: Alignment.center,
                        child: TextField(
                          controller: textController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary),
                          onChanged: (val) { adjustmentValue = int.tryParse(val) ?? 0; },
                          decoration: const InputDecoration(border: InputBorder.none),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setModalState(() { adjustmentValue++; textController.text = adjustmentValue.toString(); });
                        },
                        icon: const Icon(Icons.add_circle_outline, size: 32, color: _primaryGreen),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: isStockIn ? _primaryGreen : _textPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () async {
                        if (adjustmentValue <= 0) return;

                        int finalNewStock = isStockIn ? (currentStock + adjustmentValue) : (currentStock - adjustmentValue);

                        if (!isStockIn && currentStock < adjustmentValue) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insufficient stocks!"), backgroundColor: _dangerColor));
                          return;
                        }

                        await FirebaseFirestore.instance
                            .collection("products")
                            .doc(docId)
                            .update({'stock': finalNewStock});
                        
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Inventory Updated successfully!"), backgroundColor: _primaryGreen, behavior: SnackBarBehavior.floating),
                          );
                        }
                      },
                      child: const Text("Apply Inventory Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  // ==================== ALL-DROPDOWN ADD PRODUCT ENGINE ====================
  void _openAddProductModal(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    
    final stockController = TextEditingController();
    final priceController = TextEditingController();

    ProductType selectedType = ProductType.palay;
    
    String selectedName = _palayVarieties.first; 
    String selectedCategory = _categories.first; 
    String selectedMetric = _metricSpecs.first; 
    int selectedThreshold = _thresholdOptions[2]; // Default: 50

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            bool isMobileModal = MediaQuery.of(context).size.width < 600;

            return Padding(
              padding: EdgeInsets.only(
                top: 20, left: 20, right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xffCBD5E1), borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 12),
                      const Text(
                        "Register New Batch / Variety",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary, letterSpacing: -0.5),
                      ),
                      const Text("Select configuration parameters below.", style: TextStyle(color: _textSecondary, fontSize: 12)),
                      const Divider(height: 24, color: _border),

                      // 1. CLASSIFICATION TOGGLE
                      const Text("Classification", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xff334155))),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text("🌾 PALAY")),
                              selected: selectedType == ProductType.palay,
                              selectedColor: _primaryGreen,
                              onSelected: (val) {
                                setModalState(() {
                                  selectedType = ProductType.palay;
                                  selectedName = _palayVarieties.first;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text("🍚 RICE")),
                              selected: selectedType == ProductType.rice,
                              selectedColor: _primaryGreen,
                              onSelected: (val) {
                                setModalState(() {
                                  selectedType = ProductType.rice;
                                  selectedName = _riceVarieties.first;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 2. PRODUCT NAME DROPDOWN
                      const Text("Product Variety Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xff334155))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: selectedName,
                        decoration: _inputDecoration(""),
                        items: (selectedType == ProductType.rice ? _riceVarieties : _palayVarieties).map((String name) {
                          return DropdownMenuItem(value: name, child: Text(name, style: const TextStyle(fontSize: 13)));
                        }).toList(),
                        onChanged: (val) => setModalState(() => selectedName = val ?? selectedName),
                      ),
                      const SizedBox(height: 14),

                      // 3. CATEGORY & QUALITY SPECS (Responsive Stack/Row)
                      if (isMobileModal) ...[
                        const Text("Category Tag", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xff334155))),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          decoration: _inputDecoration(""),
                          items: _categories.map((String cat) {
                            return DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 13)));
                          }).toList(),
                          onChanged: (val) => setModalState(() => selectedCategory = val ?? selectedCategory),
                        ),
                        const SizedBox(height: 14),
                        const Text("Quality Metric Spec", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xff334155))),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: selectedMetric,
                          decoration: _inputDecoration(""),
                          items: _metricSpecs.map((String spec) {
                            return DropdownMenuItem(value: spec, child: Text(spec, style: const TextStyle(fontSize: 13)));
                          }).toList(),
                          onChanged: (val) => setModalState(() => selectedMetric = val ?? selectedMetric),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Category Tag", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xff334155))),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    initialValue: selectedCategory,
                                    decoration: _inputDecoration(""),
                                    items: _categories.map((String cat) {
                                      return DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 13)));
                                    }).toList(),
                                    onChanged: (val) => setModalState(() => selectedCategory = val ?? selectedCategory),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Quality Metric Spec", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xff334155))),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    initialValue: selectedMetric,
                                    decoration: _inputDecoration(""),
                                    items: _metricSpecs.map((String spec) {
                                      return DropdownMenuItem(value: spec, child: Text(spec, style: const TextStyle(fontSize: 13)));
                                    }).toList(),
                                    onChanged: (val) => setModalState(() => selectedMetric = val ?? selectedMetric),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),

                      // 4. INITIAL STOCKS & PRICE
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Initial Stock (Sacks)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xff334155))),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: stockController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 13, color: _textPrimary),
                                  decoration: _inputDecoration("0"),
                                  validator: (val) => int.tryParse(val ?? '') == null ? "Required integer" : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Price / Kilo (₱)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xff334155))),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: priceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(fontSize: 13, color: _textPrimary),
                                  decoration: _inputDecoration("0.00"),
                                  validator: (val) => double.tryParse(val ?? '') == null ? "Required price" : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 5. LOW STOCK ALERT DROPDOWN
                      const Text("Low Stock Warning Level", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xff334155))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: selectedThreshold,
                        decoration: _inputDecoration(""),
                        items: _thresholdOptions.map((int value) {
                          return DropdownMenuItem(value: value, child: Text("$value Sacks Limit", style: const TextStyle(fontSize: 13)));
                        }).toList(),
                        onChanged: (val) => setModalState(() => selectedThreshold = val ?? selectedThreshold),
                      ),
                      const SizedBox(height: 24),

                      // SUBMIT BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _textPrimary, 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
                            elevation: 0
                          ),
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              final newProduct = ProductModel(
                                name: selectedName,
                                type: selectedType,
                                category: selectedCategory,
                                metricDetail: selectedMetric,
                                price: double.parse(priceController.text),
                                stock: int.parse(stockController.text),
                                lowStockThreshold: selectedThreshold,
                                createdAt: DateTime.now(),
                              );

                              try {
                                await FirebaseFirestore.instance
                                    .collection("products")
                                    .add(newProduct.toFirestore());

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("🚀 Stock Item Added Successfully!"), 
                                      backgroundColor: _primaryGreen, 
                                      behavior: SnackBarBehavior.floating
                                    ),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Database Error: $e"), backgroundColor: _dangerColor),
                                );
                              }
                            }
                          },
                          child: const Text("Deploy Variety to Pipeline", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xff94A3B8), fontSize: 12),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryGreen, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _dangerColor, width: 1)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _dangerColor, width: 1.5)),
    );
  }
}