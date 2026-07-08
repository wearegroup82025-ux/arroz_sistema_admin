import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  // Function para makuha ang kulay at disenyo ng Shopee Status Badge
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange; // To Ship / Inihahanda pa
      case 'shipping':
        return Colors.blue; // To Receive / On the way na ang rider
      case 'completed':
        return Colors.green; // Nakuha at Tinanggap na ng Buyer
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Purchases"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("orders")
            .orderBy('orderDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No orders found.", style: TextStyle(color: Colors.grey, fontSize: 16)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final order = doc.data() as Map<String, dynamic>;
              final String status = order['status'] ?? 'Pending';
              final List items = order['items'] ?? [];

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HEADER: Order ID at Shopee-Style Tracking Status Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "ID: ${doc.id.substring(0, 8).toUpperCase()}",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _getStatusColor(status)),
                            ),
                            child: Text(
                              status == 'Pending' 
                                  ? 'To Ship' 
                                  : (status == 'Shipping' ? 'To Receive' : 'Completed'),
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      // MIDDLE: Listahan ng mga Biniling Rice Items
                      Column(
                        children: items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "${item['name']} (x${item['quantity']})",
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  "₱${(item['price'] * item['quantity']).toStringAsFixed(2)}",
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const Divider(height: 20),

                      // BOTTOM: Payment Method, Total Price, at Dynamic Action Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Mode: ${order['paymentMethod'] ?? 'COD'}",
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontStyle: FontStyle.italic),
                          ),
                          Row(
                            children: [
                              const Text("Total: ", style: TextStyle(fontSize: 14)),
                              Text(
                                "₱${(order['totalAmount'] as num).toStringAsFixed(2)}",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 18),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // SHOPEE DYNAMIC BUTTON: Lalabas lang kung ang status ay 'Shipping' (Nasa daan na)
                      if (status.toLowerCase() == 'shipping') ...[
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          height: 45,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange, // Kulay Shopee Button
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              // I-update ang status sa Firestore para maging 'Completed'
                              await FirebaseFirestore.instance
                                  .collection("orders")
                                  .doc(doc.id)
                                  .update({
                                    'status': 'Completed',
                                    'isPaid': true, // Kung COD man ito, matic Paid na dahil nareceive na
                                  });

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Order marked as Completed! Thank you for buying!"),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                            child: const Text(
                              "Order Received",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                        ),
                      ]
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