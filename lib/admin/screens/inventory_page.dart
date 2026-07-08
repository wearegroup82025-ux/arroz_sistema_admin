import 'package:flutter/material.dart';

// 1. UPDATED DATA MODEL WITH FILTERS
enum InventoryType { palay, rice }

class RiceProduct {
  final String name;
  final String imagePath; 
  final InventoryType type;
  final String metricDetail; // E.g., "14% Moisture" para sa Palay, "Well-Milled" para sa Bigas
  int availableSacks;        // Binago mula pieces patungong 'sacks' base sa ERD
  int quantityToApply;

  RiceProduct({
    required this.name,
    required this.imagePath,
    required this.type,
    required this.metricDetail,
    required this.availableSacks,
    this.quantityToApply = 1,
  });
}

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  // Brand UI Premium Colors
  static const Color _primaryGreen = Color(0xff16A34A); 
  static const Color _textPrimary = Color(0xff0F172A); 
  static const Color _textSecondary = Color(0xff475569); 
  static const Color _border = Color(0xffE2E8F0);
  static const Color _cardBg = Color(0xffF8FAFC); // Mas malinis na slate white para sa modern dashboard look

  // Kasalukuyang aktibong filter ng tab (Default ay Palay)
  InventoryType _selectedFilter = InventoryType.palay;

  // Mock Data na naka-segregate ayon sa itinakda nating Database Business Logic
  final List<RiceProduct> _products = [
    // PALAY INVENTORY ENTRIES
    RiceProduct(name: "RC222 Raw Grain", imagePath: "assets/palay_sample.png", type: InventoryType.palay, metricDetail: "14.2% Moisture", availableSacks: 120),
    RiceProduct(name: "Jasmine Palay", imagePath: "assets/palay_sample.png", type: InventoryType.palay, metricDetail: "13.8% Moisture", availableSacks: 85),
    RiceProduct(name: "Sinandomeng Unmilled", imagePath: "assets/palay_sample.png", type: InventoryType.palay, metricDetail: "14.0% Moisture", availableSacks: 210),
    RiceProduct(name: "Dinorado Seedstock", imagePath: "assets/palay_sample.png", type: InventoryType.palay, metricDetail: "13.5% Moisture", availableSacks: 45),
    
    // RICE INVENTORY ENTRIES
    RiceProduct(name: "Golden Grains Premium", imagePath: "assets/rice_gold.png", type: InventoryType.rice, metricDetail: "Well-Milled Rice", availableSacks: 30),
    RiceProduct(name: "Farmer's Choice Rice", imagePath: "assets/rice_farmers.png", type: InventoryType.rice, metricDetail: "Premium Grade", availableSacks: 65),
    RiceProduct(name: "Doña Maria Jasmine", imagePath: "assets/rice_dona.png", type: InventoryType.rice, metricDetail: "Long Grain Milled", availableSacks: 40),
  ];

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1000;
    
    // Dynamic Grid layout responsive sizing
    int crossAxisCount = screenWidth > 1200 ? 5 : (screenWidth > 800 ? 3 : 2);

    // Filter local list execution query
    final filteredProducts = _products.where((p) => p.type == _selectedFilter).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.all(isDesktop ? 32 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER BAR AREA WITH TRANSACTION LOG LINK
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Inventory Center",
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Manage stock balances, track processing states and crop production logs.",
                        style: TextStyle(color: _textSecondary.withOpacity(0.9), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.assignment_outlined, color: _textSecondary, size: 20),
                  label: const Text(
                    "Logs History",
                    style: TextStyle(color: _textSecondary, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                )
              ],
            ),
            const SizedBox(height: 24),
            
            // NEW SEGMENTED TOGGLE FILTER CHIPS (Palay vs Rice Switch)
            Row(
              children: [
                _buildFilterChip("🌾 Palay Stockpile", InventoryType.palay),
                const SizedBox(width: 12),
                _buildFilterChip("🍚 Milled Rice / Bigas", InventoryType.rice),
              ],
            ),
            const SizedBox(height: 24),
            
            // RESPONSIVE RICE GRID VIEW
            Expanded(
              child: filteredProducts.isEmpty
                  ? Center(
                      child: Text(
                        "No items available in this category.",
                        style: TextStyle(color: _textSecondary.withOpacity(0.5), fontSize: 14),
                      ),
                    )
                  : GridView.builder(
                      itemCount: filteredProducts.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        childAspectRatio: 0.72, // In-adjust para sa dagdag na subtitle row elements
                      ),
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        return _buildComplementaryRiceCard(product);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Segmented Filter Controller Element builder
  Widget _buildFilterChip(String label, InventoryType type) {
    final isSelected = _selectedFilter == type;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : _textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
      selected: isSelected,
      selectedColor: _primaryGreen,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? _primaryGreen : _border),
      ),
      onSelected: (secure) {
        if (secure) {
          setState(() => _selectedFilter = type);
        }
      },
    );
  }

  Widget _buildComplementaryRiceCard(RiceProduct product) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: _border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _textPrimary.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Header variety block name strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              color: _primaryGreen,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Text(
              product.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
          ),
          
          // 2. Grain Asset Graphic Container Frame
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Image.asset(
                product.imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    product.type == InventoryType.palay ? Icons.grass : Icons.rice_bowl_outlined, 
                    size: 56, 
                    color: _textSecondary.withOpacity(0.3),
                  );
                },
              ),
            ),
          ),

          // 3. Dynamic Crop Specs (Moisture or Mill quality parameters)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _border),
            ),
            child: Text(
              product.metricDetail,
              style: const TextStyle(color: _primaryGreen, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),

          // 4. Stock Sacks Scale indicator
          Text(
            "Stock: ${product.availableSacks} bags / sacks",
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),

          // 5. Quantity Stepper Node Elements
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCounterButton(Icons.remove, () {
                if (product.quantityToApply > 1) {
                  setState(() => product.quantityToApply--);
                }
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  "${product.quantityToApply}",
                  style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
              _buildCounterButton(Icons.add, () {
                setState(() => product.quantityToApply++);
              }),
            ],
          ),
          const SizedBox(height: 14),

          // 6. Action Execution Hub Panel Button
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SizedBox(
              width: 110,
              height: 34,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _textPrimary, // Pinagpalit sa slate black para maging high-contrast and professional look
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("${product.name}: Successfully applied changes for ${product.quantityToApply} sacks."),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text(
                  "Confirm",
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: _textPrimary),
      ),
    );
  }
}