import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import 'address_picker.dart';
import 'payment_webview.dart';
import 'orders_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final Set<String> _selectedItemIds = {};
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // --- ONLINE PAYMENT VIA JS BACKEND SERVER & WEBVIEW ---
  Future<void> _processCartPayMongoPayment({
    required BuildContext context,
    required List<QueryDocumentSnapshot> checkoutDocs,
    required String paymentMethod, // 'gcash' o 'paymaya'
    required DocumentReference orderRef,
    required double totalAmount,
    required Map<String, dynamic> selectedAddress,
  }) async {
    if (currentUser == null) return;

    // 1. IPAKITA ANG LOADING DIALOG
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          margin: EdgeInsets.all(20),
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.green),
                SizedBox(height: 15),
                Text("Inihahanda ang payment gateway...", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // FIX 1: SIGURADUHING MALINIS NA 2 DECIMAL PLACES ANG AMOUNT
      final double cleanAmount = double.parse(totalAmount.toStringAsFixed(2));

      // 2. TAWAGIN ANG NODE.JS BACKEND SERVER MO
      final response = await http.post(
        Uri.parse("https://arroz-backend.onrender.com/api/create-payment"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "orderId": orderRef.id,
          "amount": cleanAmount, // Malinis na number format
          "paymentMethod": paymentMethod, // 'gcash' o 'paymaya'
        }),
      ).timeout(const Duration(seconds: 30));

      // ISARA ANG LOADING DIALOG
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        String? checkoutUrl = responseData['checkoutUrl'];

        if (checkoutUrl == null || checkoutUrl.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Walang natanggap na Checkout Link: ${response.body}"), backgroundColor: Colors.redAccent),
            );
          }
          return;
        }

        if (!context.mounted) return;

        // 3. I-SAVE ANG ORDER RECORD SA FIRESTORE (Safe Parsing para sa Cart Items)
        List<Map<String, dynamic>> orderItems = checkoutDocs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final double price = double.tryParse(data['price'].toString()) ?? 0.0;
          final int qty = int.tryParse(data['quantity'].toString()) ?? 1;
          return {
            'productId': data['productId'] ?? doc.id,
            'name': data['name'] ?? 'Item',
            'price': price,
            'quantity': qty,
            'subtotal': price * qty,
          };
        }).toList();

        await orderRef.set({
          'orderId': orderRef.id,
          'userId': currentUser!.uid,
          'customerName': selectedAddress['fullName'],
          'phoneNumber': selectedAddress['phoneNumber'] ?? selectedAddress['mobileNumber'] ?? "N/A",
          'deliveryAddress': "${selectedAddress['streetBuildingHouseNo']}, ${selectedAddress['barangay']}, ${selectedAddress['cityMunicipality']}, ${selectedAddress['province']} (${selectedAddress['postalCode'] ?? ''})",
          'emailAddress': currentUser!.email ?? "",
          'items': orderItems,
          'totalAmount': cleanAmount,
          'orderStatus': 'Unpaid',
          'status': 'Unpaid',
          'paymentMethod': paymentMethod == 'gcash' ? 'GCash (PayMongo)' : 'Maya (PayMongo)',
          'isPaid': false,
          'prepareToShip': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 4. BUKASAN ANG PAYMENT WEBVIEW
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PaymentWebView(
              checkoutUrl: checkoutUrl,
              orderId: orderRef.id,
              paymentMethod: paymentMethod,
            ),
          ),
        );

        if (context.mounted && result == "SUCCESS") {
          // UPDATE FIRESTORE STATUS
          await orderRef.update({
            'isPaid': true,
            'orderStatus': 'Paid',
            'status': 'Paid',
            'prepareToShip': true,
            'paidAt': FieldValue.serverTimestamp(),
          });

          // BAWASAN STOCK AT LINISIN ANG CART
          for (var doc in checkoutDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final int qty = int.tryParse(data['quantity'].toString()) ?? 1;
            final String productId = data['productId'] ?? doc.id;
            await FirebaseFirestore.instance.collection("products").doc(productId).update({
              'stock': FieldValue.increment(-qty)
            });
            await FirebaseFirestore.instance.collection("cart").doc(doc.id).delete();
          }

          setState(() {
            _selectedItemIds.clear();
          });

          if (!context.mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Payment Successful! Ang iyong order ay nailagay na."),
              backgroundColor: Colors.green,
            ),
          );

          // DIRETSO AGAD SA ORDERS PAGE
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const OrdersPage()),
                (route) => route.isFirst,
          );
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Kanselado o pumalya ang payment."), backgroundColor: Colors.redAccent),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Server Error (${response.statusCode}): ${response.body}"),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } on TimeoutException {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Mabagal sumagot ang Server. Paki-subukan ulit."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("May error na naganap: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // --- PAYMENT METHOD SELECTION SHEET ---
  void _showCartPaymentSheet(
      BuildContext context,
      List<QueryDocumentSnapshot> checkoutDocs,
      double totalAmount,
      Map<String, dynamic> selectedAddress,
      ) {
    String selectedPayment = "GCash";

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setPaymentState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Pumili ng Uri ng Pagbabayad", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Text("Kabuuan ng Checkout: ₱${totalAmount.toStringAsFixed(2)}",
                      style: const TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold)),
                  const Divider(height: 25),
                  RadioListTile<String>(
                    title: const Text("GCash"),
                    value: "GCash",
                    groupValue: selectedPayment,
                    activeColor: Colors.green,
                    onChanged: (val) => setPaymentState(() => selectedPayment = val!),
                  ),
                  RadioListTile<String>(
                    title: const Text("Maya"),
                    value: "Maya",
                    groupValue: selectedPayment,
                    activeColor: Colors.green,
                    onChanged: (val) => setPaymentState(() => selectedPayment = val!),
                  ),
                  RadioListTile<String>(
                    title: const Text("Cash on Delivery (COD)"),
                    value: "COD",
                    groupValue: selectedPayment,
                    activeColor: Colors.green,
                    onChanged: (val) => setPaymentState(() => selectedPayment = val!),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        final orderRef = FirebaseFirestore.instance.collection("orders").doc();

                        if (selectedPayment == "COD") {
                          List<Map<String, dynamic>> orderItems = checkoutDocs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final double price = double.tryParse(data['price'].toString()) ?? 0.0;
                            final int qty = int.tryParse(data['quantity'].toString()) ?? 1;
                            return {
                              'productId': data['productId'] ?? doc.id,
                              'name': data['name'] ?? 'Item',
                              'price': price,
                              'quantity': qty,
                              'subtotal': price * qty,
                            };
                          }).toList();

                          await orderRef.set({
                            'orderId': orderRef.id,
                            'userId': currentUser!.uid,
                            'customerName': selectedAddress['fullName'],
                            'phoneNumber': selectedAddress['phoneNumber'] ?? selectedAddress['mobileNumber'] ?? "N/A",
                            'deliveryAddress': "${selectedAddress['streetBuildingHouseNo']}, ${selectedAddress['barangay']}, ${selectedAddress['cityMunicipality']}, ${selectedAddress['province']} (${selectedAddress['postalCode'] ?? ''})",
                            'emailAddress': currentUser!.email ?? "",
                            'items': orderItems,
                            'totalAmount': double.parse(totalAmount.toStringAsFixed(2)),
                            'orderStatus': 'Pending',
                            'status': 'Pending',
                            'paymentMethod': 'Cash on Delivery (COD)',
                            'isPaid': false,
                            'prepareToShip': false,
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                          for (var doc in checkoutDocs) {
                            final data = doc.data() as Map<String, dynamic>;
                            final int qty = int.tryParse(data['quantity'].toString()) ?? 1;
                            await FirebaseFirestore.instance.collection("products").doc(data['productId'] ?? doc.id).update({
                              'stock': FieldValue.increment(-qty)
                            });
                            await FirebaseFirestore.instance.collection("cart").doc(doc.id).delete();
                          }

                          setState(() {
                            _selectedItemIds.clear();
                          });

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Matagumpay na nailagay ang iyong COD order!"), backgroundColor: Colors.green),
                            );

                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const OrdersPage()),
                                  (route) => route.isFirst,
                            );
                          }
                        } else {
                          String paymongoMethod = selectedPayment == "GCash" ? "gcash" : "paymaya";
                          await _processCartPayMongoPayment(
                            context: context,
                            checkoutDocs: checkoutDocs,
                            paymentMethod: paymongoMethod,
                            orderRef: orderRef,
                            totalAmount: totalAmount,
                            selectedAddress: selectedAddress,
                          );
                        }
                      },
                      child: Text(
                        "I-place ang Order ₱${totalAmount.toStringAsFixed(2)}",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
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

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return const Scaffold(body: Center(child: Text("Mangyaring mag-log in muna.")));

    return Scaffold(
      appBar: AppBar(title: const Text("Aking Cart"), backgroundColor: Colors.green, foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("cart").where("userId", isEqualTo: currentUser!.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Walang laman ang iyong cart."));

          final cartDocs = snapshot.data!.docs;
          double totalAmount = 0;
          List<QueryDocumentSnapshot> selectedDocs = [];

          for (var doc in cartDocs) {
            final data = doc.data() as Map<String, dynamic>;
            if (_selectedItemIds.contains(doc.id)) {
              selectedDocs.add(doc);
              // FIX 2: SAFE NUMERIC PARSING PARA HINDI MAG-CRASH O MAGKA-WRONG DECIMAL
              final double price = double.tryParse(data['price'].toString()) ?? 0.0;
              final int qty = int.tryParse(data['quantity'].toString()) ?? 1;
              totalAmount += (price * qty);
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
                              title: Text(item['name'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("₱${item['price']} x ${item['quantity']}"),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => FirebaseFirestore.instance.collection("cart").doc(doc.id).delete(),
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
                decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 10)]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("₱${totalAmount.toStringAsFixed(2)}",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      ),
                      onPressed: () {
                        if (selectedDocs.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pumili muna ng aytem na i-checheckout!")));
                        } else {
                          GlobalAddressSelectionService.showAddressPicker(
                            context: context,
                            onAddressSelected: (selectedAddress) {
                              _showCartPaymentSheet(context, selectedDocs, totalAmount, selectedAddress);
                            },
                          );
                        }
                      },
                      child: const Text("I-checkout ang Cart", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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