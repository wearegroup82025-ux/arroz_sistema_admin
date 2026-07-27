import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'address_picker.dart';
import 'payment_webview.dart';
import 'orders_page.dart';

class CheckoutPage extends StatefulWidget {
  final Map<String, dynamic>? initialAddress;
  final List<Map<String, dynamic>> orderItems;
  final double totalAmount;

  const CheckoutPage({
    super.key,
    this.initialAddress,
    required this.orderItems,
    required this.totalAmount,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  Map<String, dynamic>? selectedAddress;
  String paymentMethod = "Cash on Delivery (COD)";
  bool isPlacingOrder = false;

  @override
  void initState() {
    super.initState();
    selectedAddress = widget.initialAddress;
  }

  // --- ONLINE PAYMENT METHOD (PAYMONGO CHECKOUT PROCESS) ---
  Future<void> _processOnlinePayment(DocumentReference orderRef, String methodKey) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          margin: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.green),
              SizedBox(height: 15),
              Text("Inihahanda ang secure payment gateway...", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );

    try {
      final response = await http.post(
        Uri.parse("https://arroz-backend.onrender.com/api/create-payment"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "orderId": orderRef.id,
          "amount": widget.totalAmount,
          "paymentMethod": methodKey,
        }),
      );

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final checkoutUrl = data["checkoutUrl"];

        if (!mounted || checkoutUrl == null) return;

        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PaymentWebView(
              checkoutUrl: checkoutUrl,
              orderId: orderRef.id,
              paymentMethod: methodKey,
            ),
          ),
        );

        if (mounted && result == "SUCCESS") {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Payment Successful! Natanggap na ang iyong bayad at order."),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const OrdersPage()),
                (route) => route.isFirst,
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Kanselado o pumalya ang online payment."),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Pumalya ang online payment session (${response.statusCode})."),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error sa Payment Gateway: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- MAIN ORDER CREATION LOGIC ---
  void _placeOrder() async {
    if (selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pumili muna ng Delivery Address."), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => isPlacingOrder = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final bool isOnlinePayment = paymentMethod == "GCash / E-Wallet";

      // MAPANATAG NA MAKUHA ANG MOBILE NUMBER SA KAHIT ANONG FIELD KEY
      final String contactNum = selectedAddress!['phoneNumber'] ?? selectedAddress!['mobileNumber'] ?? "N/A";

      // 1. Lumikha ng Order Record sa Firestore
      final orderRef = await FirebaseFirestore.instance.collection("orders").add({
        "userId": user?.uid,
        "customerName": selectedAddress!['fullName'],
        "emailAddress": selectedAddress!['emailAddress'],
        "phoneNumber": contactNum,
        "deliveryAddress": "${selectedAddress!['streetBuildingHouseNo']}, ${selectedAddress!['barangay']}, ${selectedAddress!['cityMunicipality']}, ${selectedAddress!['province']} (${selectedAddress!['postalCode'] ?? ''})",
        "items": widget.orderItems,
        "totalAmount": widget.totalAmount,
        "paymentMethod": paymentMethod,
        "isPaid": false,
        "prepareToShip": false,
        "orderStatus": isOnlinePayment ? "Unpaid" : "Pending",
        "createdAt": FieldValue.serverTimestamp(),
      });

      // 2. Paghihiwalay ng proseso depende sa napiling mode of payment
      if (isOnlinePayment) {
        if (mounted) setState(() => isPlacingOrder = false);
        await _processOnlinePayment(orderRef, "gcash");
      } else {
        // 🟢 PROSESO PARA SA CASH ON DELIVERY (COD):
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Order Placed Successfully! Natanggap na ang iyong COD Order."),
              backgroundColor: Colors.green,
            ),
          );

          // DIRETSO AGAD SA ORDERS PAGE
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const OrdersPage()),
                (route) => route.isFirst,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error sa pag-place ng order: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isPlacingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Checkout / Order Review", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. DELIVERY ADDRESS SECTION
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.green),
                            SizedBox(width: 8),
                            Text("Delivery Address", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            GlobalAddressSelectionService.showAddressPicker(
                              context: context,
                              onAddressSelected: (newAddress) {
                                setState(() => selectedAddress = newAddress);
                              },
                            );
                          },
                          child: Text(
                              selectedAddress == null ? "+ Pumili / Magdagdag" : "Palitan",
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)
                          ),
                        )
                      ],
                    ),
                    const Divider(),
                    if (selectedAddress == null)
                      const Text("Walang napiling address. Paki-pindot ang '+ Pumili / Magdagdag' sa itaas.", style: TextStyle(color: Colors.red))
                    else ...[
                      Text("Pangalan: ${selectedAddress!['fullName']}", style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text("Email: ${selectedAddress!['emailAddress'] ?? 'N/A'}"),
                      // INAYOS NA MAKUHA ANG PAGPIPILIAN NA FIELD KEY NG CONTACT NUMBER
                      Text(
                          "Contact No: ${selectedAddress!['phoneNumber'] ?? selectedAddress!['mobileNumber'] ?? 'N/A'}",
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${selectedAddress!['streetBuildingHouseNo']}, ${selectedAddress!['barangay']}, ${selectedAddress!['cityMunicipality']}, ${selectedAddress!['province']} (${selectedAddress!['postalCode'] ?? ''})",
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. PAYMENT METHOD SECTION
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.payment, color: Colors.green),
                        SizedBox(width: 8),
                        Text("Mode of Payment", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const Divider(),
                    RadioListTile<String>(
                      title: const Text("Cash on Delivery (COD)"),
                      value: "Cash on Delivery (COD)",
                      groupValue: paymentMethod,
                      activeColor: Colors.green,
                      onChanged: (val) => setState(() => paymentMethod = val!),
                    ),
                    RadioListTile<String>(
                      title: const Text("GCash / E-Wallet"),
                      value: "GCash / E-Wallet",
                      groupValue: paymentMethod,
                      activeColor: Colors.green,
                      onChanged: (val) => setState(() => paymentMethod = val!),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. ORDER SUMMARY SECTION
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Order Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Divider(),
                    ...widget.orderItems.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("${item['quantity']}x ${item['name']}"),
                          Text("₱${item['price'] * item['quantity']}"),
                        ],
                      ),
                    )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Kabuuan (Total Amount):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text("₱${widget.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // BOTTOM BAR FOR PLACE ORDER BUTTON
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: isPlacingOrder ? null : _placeOrder,
            child: isPlacingOrder
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
              paymentMethod == "GCash / E-Wallet" ? "MAGBAYAD GAMIT ANG GCASH" : "PLACE ORDER NOW",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}