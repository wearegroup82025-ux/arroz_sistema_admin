import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'address_picker.dart';
import 'checkout_page.dart'; // Naka-import ang CheckoutPage dito

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final Set<String> _selectedItemIds = {};
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Function kapag ipinasa ang items at address papunta sa CheckoutPage
  void _proceedToCheckout(
      List<QueryDocumentSnapshot> selectedDocs,
      double totalAmount,
      Map<String, dynamic> selectedAddress) {
    // 1. I-map ang napiling cart items sa format na kailangan ng CheckoutPage
    List<Map<String, dynamic>> orderItems = selectedDocs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'productId': data['productId'] ?? doc.id,
        'name': data['name'] ?? 'Item',
        'price': data['price'] ?? 0,
        'quantity': data['quantity'] ?? 1,
        'cartDocId': doc.id, // Idinagdag para madaling matukoy kung aling cart doc ang lilinisin
      };
    }).toList();

    // 2. I-navigate ang user papunta sa CheckoutPage
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutPage(
          initialAddress: selectedAddress,
          orderItems: orderItems,
          totalAmount: totalAmount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Mangyaring mag-log in muna.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Aking Cart"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("cart")
            .where("userId", isEqualTo: currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Walang laman ang iyong cart."));
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
                  itemCount: cartDocs.length,
                  itemBuilder: (context, index) {
                    final doc = cartDocs[index];
                    final item = doc.data() as Map<String, dynamic>;
                    final bool isChecked = _selectedItemIds.contains(doc.id);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: Row(
                        children: [
                          Checkbox(
                            activeColor: Colors.green,
                            value: isChecked,
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
                            child: ListTile(
                              title: Text(item['name'] ?? 'Item',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("₱${item['price']} x ${item['quantity']}"),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => FirebaseFirestore.instance
                                    .collection("cart")
                                    .doc(doc.id)
                                    .delete(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.grey.shade300, blurRadius: 10)
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "₱${totalAmount.toStringAsFixed(2)}",
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      ),
                      onPressed: () {
                        if (selectedDocs.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Pumili muna ng aytem na i-checheckout!"),
                            ),
                          );
                        } else {
                          // Bago pumunta sa CheckoutPage, kunin muna ang Delivery Address
                          GlobalAddressSelectionService.showAddressPicker(
                            context: context,
                            onAddressSelected: (selectedAddress) {
                              _proceedToCheckout(selectedDocs, totalAmount, selectedAddress);
                            },
                          );
                        }
                      },
                      child: const Text(
                        "I-checkout ang Cart",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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