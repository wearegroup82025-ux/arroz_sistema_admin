import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  // ==================== PAYMONGO MULTI-ITEM CHECKOUT LOGIC ====================
  Future<void> _processCartPayMongoPayment({
    required BuildContext context,
    required List<QueryDocumentSnapshot> cartDocs,
    required String paymentMethod, // "gcash" o "paymaya"
    required DocumentReference orderRef,
    required double totalAmount,
  }) async {
    int amountInCentavos = (totalAmount * 100).toInt();

    // GAMITIN ANG IYONG PAYMONGO SECRET KEY
    const String paymongoSecretKey = "YOUR_STRIPE_KEY"; 
    const String url = "https://api.paymongo.com/v1/checkout_sessions";

    String basicAuth = 'Basic ${base64Encode(utf8.encode('$paymongoSecretKey:'))}';

    // I-map ang lahat ng items mula sa cart collection para sa PayMongo line_items invoice
    List<Map<String, dynamic>> lineItems = cartDocs.map((doc) {
      final item = doc.data() as Map<String, dynamic>;
      return {
        "currency": "PHP",
        "amount": ((item['price'] ?? 0) * 100).toInt(), // Bawat piraso converted to centavos
        "name": item['name'] ?? 'Cart Item',
        "quantity": item['quantity'] ?? 1
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
          'Authorization': basicAuth,
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

      if (context.mounted) Navigator.pop(context); // Alisin ang loading spinner

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        String checkoutUrl = responseData['data']['attributes']['checkout_url'];

        // I-compile ang mga items para i-save sa database natin
        List<Map<String, dynamic>> orderItems = cartDocs.map((doc) {
          return doc.data() as Map<String, dynamic>;
        }).toList();

        // 1. I-save muna sa Firestore orders list (Pending habang nasa browser pa)
        await orderRef.set({
          'orderId': orderRef.id,
          'items': orderItems,
          'totalAmount': totalAmount,
          'status': 'Pending',
          'paymentMethod': paymentMethod == 'gcash' ? 'GCash' : 'Maya',
          'isPaid': false,
          'orderDate': FieldValue.serverTimestamp(),
        });

        // 2. Burahin na ang mga tinanggal na item sa cart ngayon dahil nasa transaction flow na
        for (var doc in cartDocs) {
          await FirebaseFirestore.instance.collection("cart").doc(doc.id).delete();
        }

        // 3. Buksan ang payment gateway link
        if (await canLaunchUrl(Uri.parse(checkoutUrl))) {
          await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("PayMongo Error: ${response.body}"), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to process checkout: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ==================== CART PAYMENT METHOD SELECTOR SHEET ====================
  void _showCartPaymentSheet(BuildContext context, List<QueryDocumentSnapshot> cartDocs, double totalAmount) {
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
                  const Text("Select Payment Method", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Text("Total Checkout: ₱${totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold)),
                  const Divider(height: 25),
                  RadioListTile<String>(
                    title: const Text("GCash"),
                    secondary: const Icon(Icons.account_balance_wallet, color: Colors.blue),
                    value: "GCash",
                    groupValue: selectedPayment,
                    onChanged: (val) => setPaymentState(() => selectedPayment = val!),
                  ),
                  RadioListTile<String>(
                    title: const Text("Maya"),
                    secondary: const Icon(Icons.wallet, color: Colors.purple),
                    value: "Maya",
                    groupValue: selectedPayment,
                    onChanged: (val) => setPaymentState(() => selectedPayment = val!),
                  ),
                  RadioListTile<String>(
                    title: const Text("Cash on Delivery (COD)"),
                    secondary: const Icon(Icons.local_shipping, color: Colors.orange),
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
                        Navigator.pop(context); // Isara ang sheet
                        final orderRef = FirebaseFirestore.instance.collection("orders").doc();

                        if (selectedPayment == "COD") {
                          // ---------- FLOW A: CASH ON DELIVERY ----------
                          List<Map<String, dynamic>> orderItems = cartDocs.map((doc) {
                            return doc.data() as Map<String, dynamic>;
                          }).toList();

                          await orderRef.set({
                            'orderId': orderRef.id,
                            'items': orderItems,
                            'totalAmount': totalAmount,
                            'status': 'Pending', // PENDING LIFECYCLE FOR COD
                            'paymentMethod': 'COD',
                            'isPaid': false,
                            'orderDate': FieldValue.serverTimestamp(),
                          });

                          // Linisin ang cart
                          for (var doc in cartDocs) {
                            await FirebaseFirestore.instance.collection("cart").doc(doc.id).delete();
                          }

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("All items ordered successfully via COD!"), backgroundColor: Colors.green),
                            );
                          }
                        } else {
                          // ---------- FLOW B: E-WALLET (PAYMONGO) ----------
                          String paymongoMethod = selectedPayment == "GCash" ? "gcash" : "paymaya";
                          if (context.mounted) {
                            await _processCartPayMongoPayment(
                              context: context,
                              cartDocs: cartDocs,
                              paymentMethod: paymongoMethod,
                              orderRef: orderRef,
                              totalAmount: totalAmount,
                            );
                          }
                        }
                      },
                      child: Text("Pay & Place Order ₱${totalAmount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  // ==================== CART PAGE MAIN UI ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Cart"), backgroundColor: Colors.green, foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("cart").snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Your cart is empty."));

          final cartDocs = snapshot.data!.docs;
          double totalAmount = 0;

          for (var doc in cartDocs) {
            final data = doc.data() as Map<String, dynamic>;
            totalAmount += ((data['price'] ?? 0) * (data['quantity'] ?? 1));
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: cartDocs.length,
                  itemBuilder: (context, index) {
                    final doc = cartDocs[index];
                    final item = doc.data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: const Icon(Icons.shopping_bag, color: Colors.green),
                        title: Text(item['name'] ?? 'Item'),
                        subtitle: Text("₱${item['price']} x ${item['quantity']}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("₱${(item['price'] * item['quantity'])}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red), 
                              onPressed: () => FirebaseFirestore.instance.collection("cart").doc(doc.id).delete()
                            ),
                          ],
                        ),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Total Amount:", style: TextStyle(fontSize: 14)),
                        Text("₱${totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
                      onPressed: () => _showCartPaymentSheet(context, cartDocs, totalAmount),
                      child: const Text("Checkout Cart", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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