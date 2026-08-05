import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ==================== DATA STRUCTURE LAYER ====================
enum OrderStatus {
  toPay,
  toShip,
  toDeliver,
  completed,
  cancelled,
}

class OrderItem {
  final String productId;
  final String productName;
  final int quantity;
  final double pricePerUnit;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.pricePerUnit,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? map['id'] ?? '',
      productName: map['name'] ?? map['productName'] ?? map['title'] ?? 'Unknown Item',
      quantity: int.tryParse(map['quantity']?.toString() ?? '1') ?? 1,
      pricePerUnit: double.tryParse(map['price']?.toString() ?? map['pricePerUnit']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'pricePerUnit': pricePerUnit,
    };
  }
}

class OrderModel {
  final String id;
  final String userId;
  final String customerName;
  final String deliveryAddress;
  final List<OrderItem> items;
  final OrderStatus status;
  final double totalAmount;
  final DateTime orderDate;

  OrderModel({
    required this.id,
    required this.userId,
    required this.customerName,
    required this.deliveryAddress,
    required this.items,
    required this.status,
    required this.totalAmount,
    required this.orderDate,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return OrderModel(
        id: doc.id,
        userId: '',
        customerName: 'Anonymous Buyer',
        deliveryAddress: 'No Address Provided',
        items: [],
        status: OrderStatus.toPay,
        totalAmount: 0.0,
        orderDate: DateTime.now(),
      );
    }

    List<OrderItem> parsedItems = [];

    // Flexible Parsing ng Items
    if (data['items'] is Map) {
      Map<String, dynamic> itemsMap = data['items'] as Map<String, dynamic>;
      itemsMap.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          parsedItems.add(OrderItem.fromMap({
            'productId': key,
            ...value
          }));
        }
      });
    } else if (data['items'] is List) {
      var list = data['items'] as List;
      parsedItems = list.map((i) => OrderItem.fromMap(i as Map<String, dynamic>)).toList();
    }

    // Advanced Status Matcher
    OrderStatus parsedStatus = OrderStatus.toPay;
    String rawStatus = (data['orderStatus'] ?? data['status'] ?? 'Pending').toString().toLowerCase().trim();

    if (rawStatus == 'pending' || rawStatus == 'topay' || rawStatus == 'to pay' || rawStatus == 'unpaid') {
      parsedStatus = OrderStatus.toPay;
    } else if (rawStatus == 'toship' || rawStatus == 'to ship' || rawStatus == 'paid' || rawStatus == 'processing') {
      parsedStatus = OrderStatus.toShip;
    } else if (
    rawStatus == 'todeliver' ||
        rawStatus == 'to deliver' ||
        rawStatus == 'shipping' ||
        rawStatus == 'shipped') {
      parsedStatus = OrderStatus.toDeliver;
    } else if (
    rawStatus == 'completed' ||
        rawStatus == 'delivered' ||
        rawStatus == 'done') {
      parsedStatus = OrderStatus.completed;
    } else if (rawStatus == 'cancelled' || rawStatus == 'canceled') {
      parsedStatus = OrderStatus.cancelled;
    }

    // Auto Computation ng Total Amount kung 0 o null sa Firestore
    double calculatedTotal = double.tryParse(data['totalAmount']?.toString() ?? data['totalPrice']?.toString() ?? data['total']?.toString() ?? '0') ?? 0.0;
    if (calculatedTotal == 0.0 && parsedItems.isNotEmpty) {
      for (var item in parsedItems) {
        calculatedTotal += (item.pricePerUnit * item.quantity);
      }
    }

    Timestamp? rawTimestamp = data['createdAt'] ?? data['orderDate'] ?? data['date'];

    return OrderModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      customerName: data['customerName'] ?? data['userName'] ?? data['name'] ?? 'Anonymous Buyer',
      deliveryAddress: data['deliveryAddress'] ?? data['address'] ?? 'No Address Provided',
      items: parsedItems,
      status: parsedStatus,
      totalAmount: calculatedTotal,
      orderDate: rawTimestamp?.toDate() ?? DateTime.now(),
    );
  }
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  static const Color _primaryBlue = Color(0xff2563EB);
  static const Color _bgSurface = Color(0xffF8FAFC);
  static const Color _textPrimary = Color(0xff0F172A);
  static const Color _textSecondary = Color(0xff64748B);
  static const Color _border = Color(0xffE2E8F0);

  OrderStatus? _selectedStatusFilter;

  String _getStatusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.toPay:
        return "TO PAY";

      case OrderStatus.toShip:
        return "TO SHIP";

      case OrderStatus.toDeliver:
        return "TO DELIVER";

      case OrderStatus.completed:
        return "COMPLETED";

      case OrderStatus.cancelled:
        return "CANCELLED";
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgSurface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Order Fulfillment Center",
                style: TextStyle(color: _textPrimary, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5),
              ),
              const Text(
                "Track invoices, update delivery pipelines, and manage transaction distributions.",
                style: TextStyle(color: _textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // FILTER CONTROL PIPELINE
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip("ALL LOGS", null),
                    ...OrderStatus.values.map((status) {
                      return _buildFilterChip(_getStatusLabel(status), status);
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // REAL-TIME ORDERS STREAM MONITOR
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection("orders").snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: _primaryBlue));
                    }

                    final docs = snapshot.data?.docs ?? [];
                    List<OrderModel> orders = docs.map((d) => OrderModel.fromFirestore(d)).toList();

                    orders.sort((a, b) => b.orderDate.compareTo(a.orderDate));

                    if (_selectedStatusFilter != null) {
                      orders = orders.where((o) => o.status == _selectedStatusFilter).toList();
                    }

                    if (orders.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_shipping_outlined, size: 48, color: _textSecondary.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            const Text("No orders found under this lifecycle stage.", style: TextStyle(color: _textSecondary)),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: orders.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        return _buildAdvancedOrderCard(orders[index]);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, OrderStatus? status) {
    final isSelected = _selectedStatusFilter == status;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : _textPrimary)),
        selected: isSelected,
        selectedColor: _primaryBlue,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.transparent : _border)),
        onSelected: (val) => setState(() => _selectedStatusFilter = status),
      ),
    );
  }

  Widget _buildAdvancedOrderCard(OrderModel order) {
    Color statusColor;
    switch (order.status) {
      case OrderStatus.toPay: statusColor = const Color(0xffF59E0B); break;
      case OrderStatus.toShip: statusColor = Colors.purple; break;
      case OrderStatus.toDeliver: statusColor = const Color(0xff06B6D4); break;
      case OrderStatus.completed: statusColor = const Color(0xff16A34A); break;
      case OrderStatus.cancelled: statusColor = const Color(0xffEF4444); break;
    }

    final displayId = order.id.length >= 8 ? order.id.substring(0, 8) : order.id;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("ID: #${displayId.toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold, color: _textPrimary, fontFamily: 'monospace')),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(_getStatusLabel(order.status), style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text("Client: ${order.customerName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _textPrimary)),
          Text("Route: ${order.deliveryAddress}", style: const TextStyle(fontSize: 12, color: _textSecondary)),
          const Divider(height: 24, color: _border),
          const Text("MANIFEST / ITEMS:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textSecondary, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          ...order.items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.fiber_manual_record, size: 8, color: _primaryBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        "${item.productName} (x${item.quantity})",
                        style: const TextStyle(fontSize: 14, color: _textPrimary, fontWeight: FontWeight.w500)
                    ),
                  ),
                  Text("₱${(item.pricePerUnit * item.quantity).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }),
          const Divider(height: 24, color: _border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Total Payout", style: TextStyle(color: _textSecondary, fontSize: 11)),
                  Text("₱ ${order.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _primaryBlue)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _textPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  elevation: 0,
                ),
                onPressed: () => _openPipelineManager(context, order),
                icon: const Icon(Icons.edit_road, size: 14, color: Colors.white),
                label: const Text("Update Pipeline", style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _openPipelineManager(BuildContext parentContext, OrderModel order) {
    OrderStatus temporaryStatus = order.status;

    showModalBottomSheet(
      isScrollControlled: true,
      context: parentContext,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Modify Dispatch Stage", style: TextStyle(color: _textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                    Text("Order #${order.id.toUpperCase()}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
                    const Divider(height: 24),
                    const Text("Pipeline Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<OrderStatus>(
                      value: temporaryStatus,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: _bgSurface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                      ),
                      items: OrderStatus.values.map((status) {
                        return DropdownMenuItem(value: status, child: Text(_getStatusLabel(status)));
                      }).toList(),
                      onChanged: (val) => setModalState(() => temporaryStatus = val ?? temporaryStatus),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: () async {
                          String statusString = "Pending";
                          switch (temporaryStatus) {
                            case OrderStatus.toPay:
                              statusString = "To Pay";
                              break;

                            case OrderStatus.toShip:
                              statusString = "To Ship";
                              break;

                            case OrderStatus.toDeliver:
                              statusString = "To Deliver";
                              break;

                            case OrderStatus.completed:
                              statusString = "Completed";
                              break;

                            case OrderStatus.cancelled:
                              statusString = "Cancelled";
                              break;
                          }

                          // 1. Update Order Document
                          await FirebaseFirestore.instance
                              .collection("orders")
                              .doc(order.id)
                              .update({
                            'status': statusString,
                            'orderStatus': statusString,
                            'isPaid': temporaryStatus == OrderStatus.completed,
                          });

                          String notificationMessage = "";

                          switch (temporaryStatus) {
                            case OrderStatus.toPay:
                              notificationMessage = "📝 Ang iyong order ay naghihintay ng bayad.";
                              break;

                            case OrderStatus.toShip:
                              notificationMessage = "📦 To ship na ang iyong order.";
                              break;

                            case OrderStatus.toDeliver:
                              notificationMessage =
                              "🚚 Ang iyong order ay out for delivery na.";
                              break;

                            case OrderStatus.completed:
                              notificationMessage = "✅ Delivered na ang iyong order. Maraming salamat sa iyong pagbili!";
                              break;

                            case OrderStatus.cancelled:
                              notificationMessage = "❌ Nakansela ang iyong order.";
                              break;
                          }

                          // 2. Save Notification Log
                          await FirebaseFirestore.instance
                              .collection("users")
                              .doc(order.userId)
                              .collection("notifications")
                              .add({
                            "title": "Order Update",
                            "body": notificationMessage,
                            "type": "ORDER_UPDATE",
                            "status": statusString,
                            "orderId": order.id,
                            "isRead": false,
                            "createdAt": FieldValue.serverTimestamp(),
                          });

                          // 3. Save User Direct Message Log
                          await FirebaseFirestore.instance
                              .collection("users")
                              .doc(order.userId)
                              .collection("messages")
                              .add({
                            "title": "Order Update",
                            "status": statusString,
                            "message": notificationMessage,
                            "orderId": order.id,
                            "isRead": false,
                            "createdAt": FieldValue.serverTimestamp(),
                          });

                          // 4. IDINAGDAG: AUTO-MESSAGE SA CHAT SYSTEM (chats -> userId -> messages)
                          if (order.userId.isNotEmpty) {
                            await FirebaseFirestore.instance
                                .collection("chats")
                                .doc(order.userId)
                                .collection("messages")
                                .add({
                              "senderId": "admin",
                              "receiverId": order.userId,
                              "text": notificationMessage,
                              "orderId": order.id,
                              "status": statusString,
                              "isAutoMessage": true,
                              "timestamp": FieldValue.serverTimestamp(),
                            });
                          }

                          if (!context.mounted) return;
                          Navigator.pop(context);

                          if (!parentContext.mounted) return;
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            const SnackBar(
                                content: Text("🚀 Order status updated & auto message sent!"),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating
                            ),
                          );
                        },
                        child: const Text("Commit Pipeline Transition", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}