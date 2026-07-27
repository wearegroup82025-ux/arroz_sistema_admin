import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ==================== DATA STRUCTURE LAYER ====================
enum OrderStatus { toPay, toShip, toReceive, completed, cancelled }

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
      productId: map['productId'] ?? '',
      // Binabasa ang 'name' mula sa Customer App o 'productName' mula sa Admin
      productName: map['name'] ?? map['productName'] ?? 'Unknown Item',
      quantity: map['quantity'] ?? 1,
      // Binabasa ang 'price' mula sa Customer App o 'pricePerUnit' mula sa Admin
      pricePerUnit: ((map['price'] ?? map['pricePerUnit']) ?? 0).toDouble(),
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

    // Check kung Map o List ang laman ng items
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

    // ROBUST STATUS PARSER (Compatible sa Customer App status names)
    OrderStatus parsedStatus = OrderStatus.toPay;
    String rawStatus = (data['orderStatus'] ?? data['status'] ?? 'Pending').toString().toLowerCase();

    if (rawStatus == 'pending' || rawStatus == 'topay' || rawStatus == 'unpaid') {
      parsedStatus = OrderStatus.toPay;
    } else if (rawStatus == 'toship' || rawStatus == 'paid' || rawStatus == 'processing') {
      parsedStatus = OrderStatus.toShip;
    } else if (rawStatus == 'toreceive' || rawStatus == 'shipping' || rawStatus == 'shipped' || rawStatus == 'delivered') {
      parsedStatus = OrderStatus.toReceive;
    } else if (rawStatus == 'completed') {
      parsedStatus = OrderStatus.completed;
    } else if (rawStatus == 'cancelled') {
      parsedStatus = OrderStatus.cancelled;
    }

    // Safe Timestamp Fallback ('createdAt' o 'orderDate')
    Timestamp? rawTimestamp = data['createdAt'] ?? data['orderDate'];

    return OrderModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      customerName: data['customerName'] ?? data['userName'] ?? 'Anonymous Buyer',
      deliveryAddress: data['deliveryAddress'] ?? data['address'] ?? 'No Address Provided',
      items: parsedItems,
      status: parsedStatus,
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      orderDate: rawTimestamp?.toDate() ?? DateTime.now(),
    );
  }
}

// ==================== MAIN ORDERS DASHBOARD INTERFACE ====================
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
      case OrderStatus.toPay: return "TO PAY";
      case OrderStatus.toShip: return "TO SHIP";
      case OrderStatus.toReceive: return "TO RECEIVE";
      case OrderStatus.completed: return "COMPLETED";
      case OrderStatus.cancelled: return "CANCELLED";
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
              // HEADER CONTEXT
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
                  stream: FirebaseFirestore.instance
                      .collection("orders")
                      .snapshots(), // Tinanggal ang .orderBy para maipakita lahat nang walang index issue
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: _primaryBlue));
                    }

                    final docs = snapshot.data?.docs ?? [];
                    List<OrderModel> orders = docs.map((d) => OrderModel.fromFirestore(d)).toList();

                    // Dart-level Sorting para sa pinakabagong order muna
                    orders.sort((a, b) => b.orderDate.compareTo(a.orderDate));

                    // Apply active status filters dynamically locally
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

  // ==================== CORE COMPONENT LAYER ====================
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
      case OrderStatus.toReceive: statusColor = const Color(0xff06B6D4); break;  
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
          // TOP SEGMENT: ORDER ID & STATUS BADGE
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

          // CUSTOMER METADATA
          Text("Client: ${order.customerName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _textPrimary)),
          Text("Route: ${order.deliveryAddress}", style: const TextStyle(fontSize: 12, color: _textSecondary)),
          const Divider(height: 24, color: _border),

          // INTERNAL DYNAMIC ORDERLIST GENERATOR
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

          // FOOTER CONTROL LAYER
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

  // ==================== CONTROL SHEET ENGINE (STATUS MANAGER) ====================
  void _openPipelineManager(BuildContext parentContext, OrderModel order) {
    OrderStatus temporaryStatus = order.status;

    showModalBottomSheet(
      context: parentContext,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
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
                    initialValue: temporaryStatus,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: _bgSurface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                    ),
                    items: OrderStatus.values.map((status) {
                      return DropdownMenuItem(
                        value: status, 
                        child: Text(_getStatusLabel(status))
                      );
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
                        // Sinasave rin ang status name na readable sa parehong Customer at Admin
                        String statusString = "Pending";
                        if (temporaryStatus == OrderStatus.toShip) statusString = "Pending"; // o "Paid"
                        if (temporaryStatus == OrderStatus.toReceive) statusString = "Shipping";
                        if (temporaryStatus == OrderStatus.completed) statusString = "Completed";
                        if (temporaryStatus == OrderStatus.cancelled) statusString = "Cancelled";

                        await FirebaseFirestore.instance
                            .collection("orders")
                            .doc(order.id)
                            .update({
                              'status': statusString,
                              'orderStatus': statusString,
                              if (temporaryStatus == OrderStatus.toShip) 'prepareToShip': true,
                            });

                        if (!context.mounted) return;
                        Navigator.pop(context);
                        
                        if (!parentContext.mounted) return;
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(
                            content: Text("🚀 Order workflow state modified!"), 
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
            );
          },
        );
      },
    );
  }
}