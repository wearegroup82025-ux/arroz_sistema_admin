import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'address_picker.dart';
class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override

  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final Set<String> _selectedItemIds = {};
  final User? currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _processCartPayMongoPayment({
    required BuildContext context,
    required List<QueryDocumentSnapshot> checkoutDocs,
    required String paymentMethod,
    required DocumentReference orderRef,
    required double totalAmount,
    required Map<String, dynamic> selectedAddress,
  }) async {
    if (currentUser == null) return;
    
    const String paymongoSecretKey = "YOUR_PAYMONGO_SECRET_KEY"; 
    const String url = "https://api.paymongo.com/v1/checkout_sessions";
    String basicAuth = 'Basic ${base64Encode(utf8.encode('$paymongoSecretKey:'))}';

    List<Map<String, dynamic>> lineItems = checkoutDocs.map((doc) {
      final item = doc.data() as Map<String, dynamic>;
      final num price = item['price'] ?? 0;
      final int quantity = item['quantity'] ?? 1;
      return {
        "currency": "PHP",
        "amount": (price * 100).toInt(),
        "name": item['name'] ?? 'Cart Item',
        "quantity": quantity
      };
    }).toList();

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.green)),
      );

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json', 
          'Authorization': basicAuth
        },
        body: jsonEncode({
          "data": {
            "attributes": {
              "send_email_receipt": true,
              "show_description": true,
              "show_line_items": true,
              "payment_method_types": [paymentMethod], 
              "line_items": lineItems,
              "success_url": "https://success.page", 
              "cancel_url": "https://cancel.page"
            }
          }
        }),
      );

      if (context.mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        String checkoutUrl = responseData['data']['attributes']['checkout_url'];

        List<Map<String, dynamic>> orderItems = checkoutDocs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final num price = data['price'] ?? 0;
          final int qty = data['quantity'] ?? 1;
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
          'customerPhone': selectedAddress['phoneNumber'],
          'shippingAddress': "${selectedAddress['streetBuildingHouseNo']}, ${selectedAddress['barangay']}, ${selectedAddress['cityMunicipality']}, ${selectedAddress['province']}, ${selectedAddress['region']}",
          'customerEmail': currentUser!.email ?? "",
          'items': orderItems,
          'totalAmount': totalAmount,
          'status': 'Pending',
          'paymentMethod': paymentMethod == 'gcash' ? 'GCash (PayMongo)' : 'Maya (PayMongo)',
          'isPaid': false,
          'prepareToShip': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        for (var doc in checkoutDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final int qty = data['quantity'] ?? 1;
          final String productId = data['productId'] ?? doc.id;
          await FirebaseFirestore.instance.collection("products").doc(productId).update({
            'stock': FieldValue.increment(-qty)
          });
        }

        for (var doc in checkoutDocs) {
          await FirebaseFirestore.instance.collection("cart").doc(doc.id).delete();
          setState(() {
            _selectedItemIds.remove(doc.id);
          });
        }

        final Uri paymentUri = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(paymentUri)) {
          await launchUrl(paymentUri, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Hindi mabuksan ang gateway link."), backgroundColor: Colors.redAccent)
            );
          }
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("PayMongo Error: ${response.reasonPhrase}"), backgroundColor: Colors.redAccent)
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("May error na naganap: $e"), backgroundColor: Colors.redAccent)
        );
      }
    }
  }

  void _showCartPaymentSheet(BuildContext context, List<QueryDocumentSnapshot> checkoutDocs, double totalAmount, Map<String, dynamic> selectedAddress) {
    String selectedPayment = "GCash";
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
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
                  Text("Kabuuan ng Checkout: ₱${totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold)),
                  const Divider(height: 25),
                  RadioListTile<String>(
                    title: const Text("GCash"),
                    value: "GCash",
                    groupValue: selectedPayment,
                    onChanged: (val) => setPaymentState(() => selectedPayment = val!),
                  ),
                  RadioListTile<String>(
                    title: const Text("Maya"),
                    value: "Maya",
                    groupValue: selectedPayment,
                    onChanged: (val) => setPaymentState(() => selectedPayment = val!),
                  ),
                  RadioListTile<String>(
                    title: const Text("Cash on Delivery (COD)"),
                    value: "COD",
                    groupValue: selectedPayment,
                    onChanged: (val) => setPaymentState(() => selectedPayment = val!),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () async {
                        Navigator.pop(context); 
                        final orderRef = FirebaseFirestore.instance.collection("orders").doc();

                        if (selectedPayment == "COD") {
                          List<Map<String, dynamic>> orderItems = checkoutDocs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return {
                              'productId': data['productId'] ?? doc.id,
                              'name': data['name'] ?? 'Item',
                              'price': data['price'] ?? 0,
                              'quantity': data['quantity'] ?? 1,
                              'subtotal': (data['price'] ?? 0) * (data['quantity'] ?? 1),
                            };
                          }).toList();

                          await orderRef.set({
                            'orderId': orderRef.id,
                            'userId': currentUser!.uid,
                            'customerName': selectedAddress['fullName'],
                            'customerPhone': selectedAddress['phoneNumber'],
                            'shippingAddress': "${selectedAddress['streetBuildingHouseNo']}, ${selectedAddress['barangay']}, ${selectedAddress['cityMunicipality']}, ${selectedAddress['province']}, ${selectedAddress['region']}",
                            'customerEmail': currentUser!.email ?? "",
                            'items': orderItems,
                            'totalAmount': totalAmount,
                            'status': 'Pending',
                            'paymentMethod': 'COD',
                            'isPaid': false,
                            'prepareToShip': false,
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                          for (var doc in checkoutDocs) {
                            final data = doc.data() as Map<String, dynamic>;
                            await FirebaseFirestore.instance.collection("products").doc(data['productId'] ?? doc.id).update({
                              'stock': FieldValue.increment(-(data['quantity'] ?? 1))
                            });
                            await FirebaseFirestore.instance.collection("cart").doc(doc.id).delete();
                          }
                          setState(() {
                            _selectedItemIds.clear();
                          });
                          
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Matagumpay na nailagay ang iyong COD order!"), backgroundColor: Colors.orange)
                            );
                          }
                        } else {
                          String paymongoMethod = selectedPayment == "GCash" ? "gcash" : "paymaya";
                          await _processCartPayMongoPayment(context: context, checkoutDocs: checkoutDocs, paymentMethod: paymongoMethod, orderRef: orderRef, totalAmount: totalAmount, selectedAddress: selectedAddress);
                        }
                      },
                      child: Text("I-place ang Order ₱${totalAmount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                    Text("₱${totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
                      onPressed: () {
                        if (selectedDocs.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pumili muna ng aytem na i-checheckout!")));
                        } else {
                          // Gumagana gamit ang external address_picker / GlobalAddressSelectionService mula sa kabilang file
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