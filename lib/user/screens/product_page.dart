import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'cart_page.dart';
import 'checkout_page.dart';
import 'payment_webview.dart';
import 'orders_page.dart';

class ProductPage extends StatelessWidget {
  const ProductPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Products"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("products").snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return const Center(child: Text("No products available."));

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.63,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final product = doc.data() as Map<String, dynamic>;
              final String imageUrl = product['imageUrl'] ?? '';
              final int deliveryDays = product['deliveryDays'] ?? 3; 

              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProductDetailPage(product: product, productId: doc.id),
                    ),
                  );
                },
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          child: imageUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                  child: Image.network(imageUrl, fit: BoxFit.cover),
                                )
                              : const Icon(Icons.image, size: 50, color: Colors.grey),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product['name'] ?? 'No Name', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text("₱${product['price'] ?? 0}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text("Stock: ${product['stock'] ?? 0}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_shipping, size: 12, color: Colors.orange),
                                  const SizedBox(width: 4),
                                  Text("Ships in $deliveryDays days", style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> product;
  final String productId;

  const ProductDetailPage({super.key, required this.product, required this.productId});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _processPayMongoPayment({
    required BuildContext navContext,
    required String paymentMethod, // 'gcash' or 'paymaya'
    required DocumentReference orderRef,
    required double totalAmount,
  }) async {
    try {
      showDialog(
        context: navContext,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            margin: EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.green),
                SizedBox(height: 15),
                Text("Initializing secure checkout...", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );

      final response = await http.post(
        Uri.parse("https://arroz-backend.onrender.com/api/create-payment"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "orderId": orderRef.id,
          "amount": totalAmount,
          "paymentMethod": paymentMethod, // "gcash" o "paymaya"
        }),
      );

      if (navContext.mounted) Navigator.of(navContext, rootNavigator: true).pop(); // Isara ang loading dialog

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final checkoutUrl = data["checkoutUrl"];

        if (!navContext.mounted || checkoutUrl == null) return;

        final result = await Navigator.of(navContext).push(
          MaterialPageRoute(
            builder: (_) => PaymentWebView(
              checkoutUrl: checkoutUrl,
              orderId: orderRef.id,
              paymentMethod: paymentMethod,
            ),
          ),
        );

        if (navContext.mounted && result == "SUCCESS") {
          ScaffoldMessenger.of(navContext).showSnackBar(
            const SnackBar(
              content: Text("Payment Successful! Your order has been placed."),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(navContext).pushReplacement(
            MaterialPageRoute(builder: (_) => const OrdersPage()),
          );
        }
      } else {
        if (navContext.mounted) {
          ScaffoldMessenger.of(navContext).showSnackBar(
            SnackBar(
              content: Text("Payment session failed (${response.statusCode}). Please try again."),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (navContext.mounted) {
        Navigator.of(navContext, rootNavigator: true).pop(); 
        ScaffoldMessenger.of(navContext).showSnackBar(
          SnackBar(content: Text("Network/Server Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddToCartSheet(BuildContext pageContext) {
    int selectedQuantity = 1;
    int maxStock = widget.product['stock'] ?? 0;

    showModalBottomSheet(
      context: pageContext,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Select Quantity for Cart", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Price: ₱${widget.product['price'] ?? 0}", style: const TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () { if (selectedQuantity > 1) setSheetState(() => selectedQuantity--); },
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.green),
                          ),
                          Text("$selectedQuantity", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(
                            onPressed: () { if (selectedQuantity < maxStock) setSheetState(() => selectedQuantity++); },
                            icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      onPressed: maxStock == 0 ? null : () async {
                        final currentUser = FirebaseAuth.instance.currentUser;
                        if (currentUser == null) return;
                        Navigator.pop(sheetContext);

                        await FirebaseFirestore.instance
                            .collection("cart")
                            .doc("${currentUser.uid}_${widget.productId}")
                            .set({
                          "userId": currentUser.uid, 
                          "productId": widget.productId,
                          "name": widget.product["name"],
                          "price": widget.product["price"],
                          "imageUrl": widget.product["imageUrl"],
                          "quantity": selectedQuantity,
                          "addedAt": FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));

                        if (pageContext.mounted) {
                          ScaffoldMessenger.of(pageContext).showSnackBar(
                            const SnackBar(content: Text("Added to Cart Successfully!"), backgroundColor: Colors.orange),
                          );
                          Navigator.of(pageContext).push(
                            MaterialPageRoute(builder: (_) => const CartPage()), 
                          );
                        }
                      },
                      child: Text(maxStock == 0 ? "Out of Stock" : "Add to Cart", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  void _showPaymentSheet(BuildContext pageContext, int initialQty) {
    int selectedQuantity = initialQty;
    int maxStock = widget.product['stock'] ?? 0;

    showModalBottomSheet(
      context: pageContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            double totalAmount = (widget.product['price'] ?? 0).toDouble() * selectedQuantity;

            return Padding(
              padding: EdgeInsets.only(
                top: 20, left: 20, right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Buy Now Options", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Dami (Quantity):", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () { if (selectedQuantity > 1) setSheetState(() => selectedQuantity--); },
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.green),
                          ),
                          Text("$selectedQuantity", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(
                            onPressed: () { if (selectedQuantity < maxStock) setSheetState(() => selectedQuantity++); },
                            icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text("Kabuuan: ₱${totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: maxStock == 0 ? null : () {
                        if (currentUser == null) return;
                        Navigator.pop(sheetContext); // Isara ang bottom sheet

                        // 🟢 DIRETSO NA SA CHECKOUT / ORDER REVIEW PAGE
                        Navigator.of(pageContext).push(
                          MaterialPageRoute(
                            builder: (_) => CheckoutPage(
                              initialAddress: null, // Pwedeng pumili o magdagdag ng address sa loob ng Checkout Page
                              orderItems: [
                                {
                                  "productId": widget.productId,
                                  "name": widget.product["name"],
                                  "price": widget.product["price"],
                                  "quantity": selectedQuantity,
                                  "subtotal": totalAmount,
                                  "imageUrl": widget.product["imageUrl"],
                                }
                              ],
                              totalAmount: totalAmount,
                            ),
                          ),
                        );
                      },
                      child: Text(maxStock == 0 ? "Out of Stock" : "Proceed to Checkout", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  void _showAddReviewDialog() async {
    if (currentUser == null) return;

    final orderQuery = await FirebaseFirestore.instance
        .collection("orders")
        .where("userId", isEqualTo: currentUser!.uid)
        .get();

    bool hasPurchased = false;
    for (var doc in orderQuery.docs) {
      List items = doc.data()['items'] ?? [];
      if (items.any((item) => item['productId'] == widget.productId)) {
        hasPurchased = true;
        break;
      }
    }

    if (!hasPurchased) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Paumanhin, mga nakabili lamang ng produktong ito ang pwedeng mag-rate."), backgroundColor: Colors.red),
      );
      return;
    }

    double userRating = 5;
    final reviewController = TextEditingController();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Write a Real Review"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(index < userRating ? Icons.star : Icons.star_border, color: Colors.amber, size: 32),
                      onPressed: () => setDialogState(() => userRating = index + 1.0),
                    );
                  }),
                ),
                TextField(
                  controller: reviewController,
                  decoration: const InputDecoration(hintText: "Share your experience..."),
                  maxLines: 3,
                )
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () async {
                  if (reviewController.text.trim().isEmpty) return;

                  await FirebaseFirestore.instance.collection("reviews").add({
                    "productId": widget.productId,
                    "userId": currentUser!.uid,
                    "userEmail": currentUser!.email ?? "Anonymous",
                    "rating": userRating,
                    "comment": reviewController.text.trim(),
                    "likes": [],
                    "dislikes": [],
                    "createdAt": FieldValue.serverTimestamp(),
                  });

                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child: const Text("Submit", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String imageUrl = widget.product['imageUrl'] ?? '';
    final int deliveryDays = widget.product['deliveryDays'] ?? 3;

    return Scaffold(
      appBar: AppBar(title: Text(widget.product['name'] ?? 'Product Details'), backgroundColor: Colors.green, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 280, width: double.infinity, color: Colors.grey[200],
              child: imageUrl.isNotEmpty ? Image.network(imageUrl, fit: BoxFit.cover) : const Icon(Icons.image, size: 100, color: Colors.grey),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("₱${widget.product['price'] ?? 0}", style: const TextStyle(color: Colors.green, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(widget.product['name'] ?? 'No Name', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Chip(avatar: const Icon(Icons.local_shipping, size: 14, color: Colors.orange), label: Text("Ships in $deliveryDays days", style: const TextStyle(fontSize: 12)), backgroundColor: Colors.orange.withOpacity(0.1), side: BorderSide.none),
                      const SizedBox(width: 10),
                      Chip(avatar: const Icon(Icons.inventory, size: 14, color: Colors.grey), label: Text("Stock: ${widget.product['stock'] ?? 0}", style: const TextStyle(fontSize: 12)), backgroundColor: Colors.grey[200], side: BorderSide.none),
                    ],
                  ),
                  const Divider(height: 30),
                  Text(widget.product['description'] ?? 'No description available.', style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
                  const Divider(height: 30),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection("reviews").where("productId", isEqualTo: widget.productId).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Product Ratings", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text("No ratings yet", style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        );
                      }

                      final reviewDocs = snapshot.data!.docs;
                      double totalStars = 0;
                      for (var doc in reviewDocs) {
                        totalStars += (doc.data() as Map<String, dynamic>)['rating'] ?? 0;
                      }
                      double avgRating = totalStars / reviewDocs.length;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Product Ratings", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 18),
                                  Text(" ${avgRating.toStringAsFixed(1)}/5 (${reviewDocs.length} real reviews)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              )
                            ],
                          ),
                          const SizedBox(height: 15),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: reviewDocs.length,
                            itemBuilder: (context, idx) {
                              final rDoc = reviewDocs[idx];
                              final rData = rDoc.data() as Map<String, dynamic>;
                              List likes = rData['likes'] ?? [];
                              List dislikes = rData['dislikes'] ?? [];

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(rData['userEmail'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                                          Row(children: List.generate(5, (sIdx) => Icon(sIdx < (rData['rating'] ?? 0) ? Icons.star : Icons.star_border, color: Colors.amber, size: 14))),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(rData['comment'] ?? '', style: const TextStyle(fontSize: 14)),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            icon: Icon(likes.contains(currentUser?.uid) ? Icons.thumb_up : Icons.thumb_up_outlined, size: 16, color: Colors.blue),
                                            onPressed: currentUser == null ? null : () {
                                              if (likes.contains(currentUser!.uid)) {
                                                rDoc.reference.update({"likes": FieldValue.arrayRemove([currentUser!.uid])});
                                              } else {
                                                rDoc.reference.update({
                                                  "likes": FieldValue.arrayUnion([currentUser!.uid]),
                                                  "dislikes": FieldValue.arrayRemove([currentUser!.uid])
                                                });
                                              }
                                            },
                                          ),
                                          Text("${likes.length}", style: const TextStyle(fontSize: 12)),
                                          const SizedBox(width: 10),
                                          IconButton(
                                            icon: Icon(dislikes.contains(currentUser?.uid) ? Icons.thumb_down : Icons.thumb_down_outlined, size: 16, color: Colors.red),
                                            onPressed: currentUser == null ? null : () {
                                              if (dislikes.contains(currentUser!.uid)) {
                                                rDoc.reference.update({"dislikes": FieldValue.arrayRemove([currentUser!.uid])});
                                              } else {
                                                rDoc.reference.update({
                                                  "dislikes": FieldValue.arrayUnion([currentUser!.uid]),
                                                  "likes": FieldValue.arrayRemove([currentUser!.uid])
                                                });
                                              }
                                            },
                                          ),
                                          Text("${dislikes.length}", style: const TextStyle(fontSize: 12)),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.amber, width: 1.5), foregroundColor: Colors.amber[800]),
                    onPressed: _showAddReviewDialog,
                    icon: const Icon(Icons.rate_review),
                    label: const Text("Write a Product Review"),
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange, width: 2), padding: const EdgeInsets.symmetric(vertical: 15)),
                  onPressed: () => _showAddToCartSheet(context), 
                  child: const Text("Add to Cart", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 15)),
                  onPressed: () => _showPaymentSheet(context, 1), 
                  child: const Text("Buy Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}