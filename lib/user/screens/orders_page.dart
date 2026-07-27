import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Color themeColor = Colors.green.shade700;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ==================== RATING & REVIEW DIALOG ====================
  void _showRatingDialog(BuildContext context, String productId, String productName) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    double userRating = 5.0;
    final reviewController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Rate & Review Product", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(productName, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Star Rating Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < userRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            userRating = index + 1.0;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  // Comment Text Field
                  TextField(
                    controller: reviewController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: "Ibahagi ang iyong karanasan sa produktong ito...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.green),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Kanselahin", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () async {
                    if (reviewController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Maglagay muna ng komento/review.")),
                      );
                      return;
                    }

                    // I-save sa Firestore 'reviews' collection para lumabas sa Product Page
                    await FirebaseFirestore.instance.collection("reviews").add({
                      "productId": productId,
                      "userId": currentUser.uid,
                      "userEmail": currentUser.email ?? "Anonymous Buyer",
                      "rating": userRating,
                      "comment": reviewController.text.trim(),
                      "likes": [],
                      "dislikes": [],
                      "createdAt": FieldValue.serverTimestamp(),
                    });

                    if (dialogContext.mounted) Navigator.pop(dialogContext);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Salamat! Ang iyong review ay naipost na sa Product Page."),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: const Text("Submit Review", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to view your orders.")),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("orders")
          .where("userId", isEqualTo: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _loading();
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Scaffold(
            appBar: _buildAppBar(),
            body: _noOrders("You haven't placed any orders yet."),
          );
        }

        // Code-level sorting para sa pinakabagong order (Desc)
        final allOrders = snapshot.data!.docs;
        allOrders.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final Timestamp aTime = aData['createdAt'] ?? Timestamp.now();
          final Timestamp bTime = bData['createdAt'] ?? Timestamp.now();
          return bTime.compareTo(aTime);
        });

        return Scaffold(
          appBar: _buildAppBar(),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildAllOrdersTab(allOrders),
              _buildToPayTab(allOrders),
              _buildToShipTab(allOrders),
              _buildToReceiveTab(allOrders),
              _buildCompletedTab(allOrders),
              _buildCancelledTab(allOrders),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text("My Purchases"),
      backgroundColor: themeColor,
      foregroundColor: Colors.white,
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: const [
          Tab(text: "All"),
          Tab(text: "To Pay"),
          Tab(text: "To Ship"),
          Tab(text: "To Receive"),
          Tab(text: "Completed"),
          Tab(text: "Cancelled"),
        ],
      ),
    );
  }

  // ==================== TAB FILTERS ====================

  Widget _buildAllOrdersTab(List<QueryDocumentSnapshot> orders) {
    return _buildListView(orders);
  }

  Widget _buildToPayTab(List<QueryDocumentSnapshot> orders) {
    final toPayOrders = orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final String status = data['orderStatus'] ?? data['status'] ?? 'Pending';
      final bool isPaid = data['isPaid'] ?? false;
      final bool prepareToShip = data['prepareToShip'] ?? false;

      if (status == "Pending" || status == "Unpaid") {
        if (!isPaid && !prepareToShip) return true;
      }
      return false;
    }).toList();

    if (toPayOrders.isEmpty) return _noOrders("No orders waiting for payment.");
    return _buildListView(toPayOrders, canCancel: true);
  }

  Widget _buildToShipTab(List<QueryDocumentSnapshot> orders) {
    final toShipOrders = orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final String status = data['orderStatus'] ?? data['status'] ?? 'Pending';
      final bool isPaid = data['isPaid'] ?? false;
      final bool prepareToShip = data['prepareToShip'] ?? false;

      return (status == "Pending" || status == "Paid") && (isPaid || prepareToShip);
    }).toList();

    if (toShipOrders.isEmpty) return _noOrders("No orders to ship.");
    return _buildListView(toShipOrders);
  }

  Widget _buildToReceiveTab(List<QueryDocumentSnapshot> orders) {
    final toReceiveOrders = orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final String status = data['orderStatus'] ?? data['status'] ?? 'Pending';

      if (status == "Delivered" && data['deliveredAt'] != null) {
        final Timestamp deliveredTimestamp = data['deliveredAt'];
        final DateTime deliveredDate = deliveredTimestamp.toDate();
        if (DateTime.now().difference(deliveredDate).inDays >= 3) {
          _autoCompleteOrder(doc.id);
          return false;
        }
      }
      return status == "Shipping" || status == "Delivered";
    }).toList();

    if (toReceiveOrders.isEmpty) return _noOrders("No orders to receive.");
    return _buildListView(toReceiveOrders);
  }

  Widget _buildCompletedTab(List<QueryDocumentSnapshot> orders) {
    final completedOrders = orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final String status = data['orderStatus'] ?? data['status'] ?? 'Pending';
      return status == "Completed";
    }).toList();

    if (completedOrders.isEmpty) return _noOrders("No completed orders.");
    return _buildListView(completedOrders, isCompletedTab: true);
  }

  Widget _buildCancelledTab(List<QueryDocumentSnapshot> orders) {
    final cancelledOrders = orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final String status = data['orderStatus'] ?? data['status'] ?? 'Pending';
      return status == "Cancelled";
    }).toList();

    if (cancelledOrders.isEmpty) return _noOrders("No cancelled orders.");
    return _buildListView(cancelledOrders, buyAgain: true);
  }

  // ==================== DB MUTATIONS ====================

  void _autoCompleteOrder(String orderId) async {
    await FirebaseFirestore.instance.collection("orders").doc(orderId).update({
      'orderStatus': 'Completed',
      'status': 'Completed',
      'completedAt': FieldValue.serverTimestamp(),
      'autoCompleted': true
    });
  }

  void _manuallyReceiveOrder(BuildContext context, String orderId) async {
    await FirebaseFirestore.instance.collection("orders").doc(orderId).update({
      'orderStatus': 'Completed',
      'status': 'Completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Order Marked as Completed!"), backgroundColor: Colors.green),
    );
  }

  void _cancelOrder(BuildContext context, String orderId, List<dynamic> items) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final orderRef = FirebaseFirestore.instance.collection("orders").doc(orderId);

        transaction.update(orderRef, {
          'orderStatus': 'Cancelled',
          'status': 'Cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });

        for (var item in items) {
          final String productId = item['productId'] ?? '';
          final int quantityToReturn = item['quantity'] ?? 0;

          if (productId.isNotEmpty && quantityToReturn > 0) {
            final productRef = FirebaseFirestore.instance.collection("products").doc(productId);
            final productSnapshot = await transaction.get(productRef);

            if (productSnapshot.exists) {
              final currentStock = productSnapshot.data()?['stock'] ?? 0;
              transaction.update(productRef, {
                'stock': currentStock + quantityToReturn,
              });
            }
          }
        }
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Order successfully cancelled."), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Transaction failed: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // ==================== LIST VIEW UI ====================

  Widget _buildListView(
    List<QueryDocumentSnapshot> orders, {
    bool canCancel = false,
    bool buyAgain = false,
    bool isCompletedTab = false,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final orderData = orders[index].data() as Map<String, dynamic>;
        final String orderId = orders[index].id;

        final num totalAmount = orderData['totalAmount'] ?? 0;
        final String paymentMethod = orderData['paymentMethod'] ?? 'COD';
        final String status = orderData['orderStatus'] ?? orderData['status'] ?? 'Pending';
        final bool isPaid = orderData['isPaid'] ?? false;
        final bool prepareToShip = orderData['prepareToShip'] ?? false;

        final List<dynamic> itemsList = orderData['items'] ?? [];

        return LayoutBuilder(
          builder: (context, constraints) {
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            "Order ID: $orderId",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusBadge(status, isPaid, paymentMethod, prepareToShip),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 5),

                    // LIST OF PRODUCTS IN ORDER
                    ...itemsList.map((item) {
                      final String pId = item['productId'] ?? '';
                      final String pName = item['name'] ?? 'Unknown Item';
                      final int pQty = item['quantity'] ?? 1;
                      final double pPrice = (item['price'] ?? 0).toDouble();

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                "$pName (x$pQty)",
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Text("₱${(pPrice * pQty).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            
                            // 🌟 RATE BUTTON PER PRODUCT IN COMPLETED TAB (Shopee Style)
                            if (isCompletedTab && pId.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.amber),
                                  foregroundColor: Colors.amber[900],
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                                icon: const Icon(Icons.star, size: 14, color: Colors.amber),
                                label: const Text("Rate", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () => _showRatingDialog(context, pId, pName),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 8),
                    Text("Payment Method: $paymentMethod", style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 15),

                    // BOTTOM BAR ACTION
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        Text(
                          "Total: ₱${totalAmount.toStringAsFixed(2)}",
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: themeColor),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (canCancel && (status == 'Pending' || status == 'Unpaid')) ...[
                              OutlinedButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text("Cancel Order"),
                                      content: const Text("Are you sure you want to cancel this order?"),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context), child: const Text("No")),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _cancelOrder(context, orderId, itemsList);
                                          },
                                          child: const Text("Yes, Cancel", style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), foregroundColor: Colors.red),
                                child: const Text("Cancel Order"),
                              ),
                            ],
                            if (buyAgain)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: themeColor),
                                onPressed: () async {
                                  final cart = FirebaseFirestore.instance.collection("cart");
                                  for (var item in itemsList) {
                                    await cart.add({
                                      "userId": FirebaseAuth.instance.currentUser!.uid,
                                      "productId": item["productId"],
                                      "name": item["name"],
                                      "price": item["price"],
                                      "quantity": item["quantity"],
                                      "imageUrl": item["imageUrl"] ?? item["image"],
                                    });
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Added back to cart!")),
                                  );
                                },
                                child: const Text("Buy Again", style: TextStyle(color: Colors.white)),
                              ),
                            if ((status == 'Shipping' || status == 'Delivered'))
                              ElevatedButton(
                                onPressed: () => _manuallyReceiveOrder(context, orderId),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
                                child: const Text("Order Received", style: TextStyle(color: Colors.white)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusBadge(String status, bool isPaid, String paymentMethod, bool prepareToShip) {
    Color badgeColor = Colors.grey;
    String text = status;

    if (status == "Cancelled") {
      badgeColor = Colors.grey;
      text = "Cancelled";
    } else if (!isPaid && !prepareToShip && (status == "Pending" || status == "Unpaid")) {
      badgeColor = Colors.red.shade700;
      text = "To Pay";
    } else if ((isPaid || prepareToShip) && (status == "Pending" || status == "Paid")) {
      badgeColor = Colors.orange.shade700;
      text = "To Ship";
    } else if (status == "Shipping" || status == "Delivered") {
      badgeColor = Colors.blue.shade700;
      text = "To Receive";
    } else if (status == "Completed") {
      badgeColor = Colors.green.shade700;
      text = "Completed";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(5)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _loading() => Center(child: CircularProgressIndicator(color: themeColor));
  Widget _noOrders(String msg) => Center(child: Text(msg, style: const TextStyle(color: Colors.grey)));
}