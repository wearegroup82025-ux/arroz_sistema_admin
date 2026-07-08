import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class ProductPage extends StatelessWidget {
  const ProductPage({super.key});

  // ==================== PAYMONGO CHECKOUT LOGIC ====================
  Future<void> _processPayMongoPayment({
    required BuildContext context,
    required Map<String, dynamic> product,
    required String productId,
    required int quantity,
    required String paymentMethod, // "gcash" o "paymaya"
    required DocumentReference orderRef,
    required double totalAmount,
  }) async {
    // 1. Gawing Centavos ang halaga (PayMongo PHP Amount x 100)
    int amountInCentavos = (totalAmount * 100).toInt();

    // PALITAN ITO NG IYONG LIVE/TEST SECRET KEY MULA SA PAYMONGO DASHBOARD
    const String paymongoSecretKey = "YOUR_STRIPE_KEY"; 
    const String url = "https://api.paymongo.com/v1/checkout_sessions";

    // I-encode ang Secret Key gamit ang Base64 para sa Basic Authentication
    String basicAuth = 'Basic ${base64Encode(utf8.encode('$paymongoSecretKey:'))}';

    try {
      // Magpakita ng Loading Indicator habang ginagawa ang session
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
              "line_items": [
                {
                  "currency": "PHP",
                  "amount": amountInCentavos,
                  "name": product['name'] ?? 'Rice Product',
                  "quantity": quantity
                }
              ],
              // Maaari mong palitan ng iyong app success web link o custom route
              "success_url": "https://success.page", 
              "cancel_url": "https://cancel.page"
            }
          }
        }),
      );

      if (context.mounted) Navigator.pop(context); // Alisin ang Loading Dialog

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        String checkoutUrl = responseData['data']['attributes']['checkout_url'];

        // I-save ang order sa Firestore na may status na "Awaiting Payment"
        await orderRef.set({
          'orderId': orderRef.id,
          'totalAmount': totalAmount,
          'status': 'Pending', // Magiging 'To Ship' via webhook/verify kapag bayad na
          'paymentMethod': paymentMethod == 'gcash' ? 'GCash' : 'Maya',
          'isPaid': false, // False hangga't hindi pa tapos ang checkout page redirect
          'orderDate': FieldValue.serverTimestamp(),
          'items': [
            {
              'productId': productId,
              'name': product['name'],
              'price': product['price'],
              'quantity': quantity,
            }
          ],
        });

        // I-launch ang hosted gateway page ng PayMongo sa browser/app
        if (await canLaunchUrl(Uri.parse(checkoutUrl))) {
          await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("PayMongo Error: ${response.statusCode}"), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Payment failed to initialize: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ==================== PAYMENT MODAL SHEET ====================
  void _showPaymentSheet(BuildContext context, Map<String, dynamic> product, String productId, int quantity) {
    String selectedPayment = "GCash"; // Default payment choice
    double totalAmount = (product['price'] ?? 0).toDouble() * quantity;

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
                  Text("Total to Pay: ₱${totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold)),
                  const Divider(height: 25),

                  // GCash Option
                  RadioListTile<String>(
                    title: const Text("GCash"),
                    secondary: const Icon(Icons.account_balance_wallet, color: Colors.blue),
                    value: "GCash",
                    groupValue: selectedPayment,
                    onChanged: (val) => setPaymentState(() => selectedPayment = val!),
                  ),
                  // Maya Option
                  RadioListTile<String>(
                    title: const Text("Maya"),
                    secondary: const Icon(Icons.wallet, color: Colors.purple),
                    value: "Maya",
                    groupValue: selectedPayment,
                    onChanged: (val) => setPaymentState(() => selectedPayment = val!),
                  ),
                  // Cash on Delivery Option
                  RadioListTile<String>(
                    title: const Text("Cash on Delivery (COD)"),
                    secondary: const Icon(Icons.local_shipping, color: Colors.orange),
                    value: "COD",
                    groupValue: selectedPayment,
                    onChanged: (val) => setPaymentState(() => selectedPayment = val!),
                  ),
                  const SizedBox(height: 20),

                  // BUTTON PARA SA KUMPIRMASYON NG PAGBABAYAD AT ORDER
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () async {
                        Navigator.pop(context); // Isara ang Payment Sheet
                        final orderRef = FirebaseFirestore.instance.collection("orders").doc();

                        if (selectedPayment == "COD") {
                          // ---------- 1. IF CASH ON DELIVERY (Dating flow pero may Shopee Status) ----------
                          await orderRef.set({
                            'orderId': orderRef.id,
                            'totalAmount': totalAmount,
                            'status': 'Pending', 
                            'paymentMethod': 'COD',
                            'isPaid': false, 
                            'orderDate': FieldValue.serverTimestamp(),
                            'items': [
                              {
                                'productId': productId,
                                'name': product['name'],
                                'price': product['price'],
                                'quantity': quantity,
                              }
                            ],
                          });

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Order placed successfully via COD!"), backgroundColor: Colors.green),
                            );
                          }
                        } else {
                          // ---------- 2. IF GCASH / MAYA (Dadaan sa PayMongo Gateway Link) ----------
                          String paymongoMethodName = selectedPayment == "GCash" ? "gcash" : "paymaya";
                          
                          if (context.mounted) {
                            await _processPayMongoPayment(
                              context: context,
                              product: product,
                              productId: productId,
                              quantity: quantity,
                              paymentMethod: paymongoMethodName,
                              orderRef: orderRef,
                              totalAmount: totalAmount,
                            );
                          }
                        }
                      },
                      child: Text("Confirm & Pay ₱${totalAmount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  // ==================== ADD TO CART SHEET ====================
  void _showAddToCartSheet(BuildContext context, Map<String, dynamic> product, String productId) {
    int selectedQuantity = 1;
    int maxStock = product['stock'] ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.green,
                        child: Icon(Icons.rice_bowl, size: 35, color: Colors.white),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product['name'] ?? 'No Name', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            Text("₱${product['price'] ?? 0}", style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
                            Text("Available Stock: $maxStock", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Select Quantity", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              if (selectedQuantity > 1) setModalState(() => selectedQuantity--);
                            },
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.green, size: 28),
                          ),
                          Text("$selectedQuantity", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(
                            onPressed: () {
                              if (selectedQuantity < maxStock) {
                                setModalState(() => selectedQuantity++);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Maximum stock reached!")));
                              }
                            },
                            icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 28),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  maxStock == 0
                      ? const SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: null, child: Text("Out of Stock")))
                      : Row(
                          children: [
                            // 1. ADD TO CART BUTTON
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.green, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), foregroundColor: Colors.green),
                                  onPressed: () async {
                                    Navigator.pop(context); // Magsara agad ang sheet
                                    await FirebaseFirestore.instance.collection("cart").doc(productId).set({
                                      'productId': productId,
                                      'name': product['name'],
                                      'price': product['price'],
                                      'quantity': selectedQuantity,
                                      'timestamp': FieldValue.serverTimestamp(),
                                    }, SetOptions(merge: true));

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Added ${product['name']} to Cart!"), backgroundColor: Colors.green));
                                    }
                                  },
                                  icon: const Icon(Icons.add_shopping_cart),
                                  label: const Text("Add to Cart", style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            
                            // 2. BUY NOW BUTTON
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), foregroundColor: Colors.white),
                                  onPressed: () {
                                    Navigator.pop(context); // Isara muna ang product sheet
                                    _showPaymentSheet(context, product, productId, selectedQuantity); // Buksan ang payment method selector
                                  },
                                  child: const Text("Order Now", style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==================== PRODUCT SCREEN DESIGN ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Products"), backgroundColor: Colors.green, foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("products").snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No Products Available"));

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final product = doc.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  onTap: () => _showAddToCartSheet(context, product, doc.id),
                  leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.rice_bowl, color: Colors.white)),
                  title: Text(product['name'] ?? 'No Name', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Stock: ${product['stock'] ?? 0}"),
                  trailing: Text("₱${product['price'] ?? 0}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}