import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'address_picker.dart';
import 'checkout_page.dart';
import 'package:provider/provider.dart';

import '../../providers/language_provider.dart';
import '../../services/app_localizations.dart';
import 'profile_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final Set<String> _selectedItemIds = {};
  final User? currentUser = FirebaseAuth.instance.currentUser;

  void _proceedToCheckout(
      List<QueryDocumentSnapshot> selectedDocs,
      double totalAmount,
      ) {
    List<Map<String, dynamic>> orderItems = selectedDocs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'productId': data['productId'] ?? doc.id,
        'name': data['name'] ?? 'Item',
        'price': data['price'] ?? 0,
        'quantity': data['quantity'] ?? 1,
        'cartDocId': doc.id,
      };
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutPage(
          orderItems: orderItems,
          totalAmount: totalAmount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>().language;
    final local = AppLocalizations(language);

    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: ArrozTheme.bgGrey,
        body: Center(child: Text("Mangyaring mag-log in muna.")),
      );
    }

    return Scaffold(
      backgroundColor: ArrozTheme.bgGrey,
      appBar: AppBar(
        title: Text(local.myCart, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: ArrozTheme.emerald,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("cart")
            .where("userId", isEqualTo: currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 70, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(local.emptyCart, style: const TextStyle(color: ArrozTheme.textSub, fontSize: 15)),
                ],
              ),
            );
          }

          final cartDocs = snapshot.data!.docs;
          double totalAmount = 0;
          List<QueryDocumentSnapshot> selectedDocs = [];

          for (var doc in cartDocs) {
            final data = doc.data() as Map<String, dynamic>;
            if (_selectedItemIds.contains(doc.id)) {
              selectedDocs.add(doc);
              totalAmount += ((data['price'] ?? 0) * (data['quantity'] ?? 1));
            }
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: cartDocs.length,
                  itemBuilder: (context, index) {
                    final doc = cartDocs[index];
                    final item = doc.data() as Map<String, dynamic>;
                    final bool isChecked = _selectedItemIds.contains(doc.id);

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            activeColor: ArrozTheme.emerald,
                            value: isChecked,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedItemIds.add(doc.id);
                                } else {
                                  _selectedItemIds.remove(doc.id);
                                }
                              });
                            },
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'] ?? 'Item',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ArrozTheme.textDark),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "₱${item['price']}  ×  ${item['quantity']}",
                                    style: const TextStyle(color: ArrozTheme.textSub, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            "₱${((item['price'] ?? 0) * (item['quantity'] ?? 1)).toStringAsFixed(2)}",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: ArrozTheme.emerald, fontSize: 14),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: ArrozTheme.dangerRed, size: 20),
                            onPressed: () => FirebaseFirestore.instance.collection("cart").doc(doc.id).delete(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Bottom Checkout Panel
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(local.total, style: const TextStyle(fontSize: 12, color: ArrozTheme.textSub)),
                        Text(
                          "₱${totalAmount.toStringAsFixed(2)}",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ArrozTheme.emerald),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ArrozTheme.emerald,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        if (selectedDocs.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(local.selectItemFirst),
                            ),
                          );
                        } else {
                          _proceedToCheckout(
                            selectedDocs,
                            totalAmount,
                          );
                        }
                      },
                      child: Text(
                        local.checkoutCart,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    )
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }
}