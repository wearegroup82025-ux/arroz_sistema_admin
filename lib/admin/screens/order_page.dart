import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ==================== CONSTANTS & THEME ====================
class AppTheme {
  static const Color primaryBlue = Color(0xff2563EB);
  static const Color bgSurface = Color(0xffF8FAFC);
  static const Color textPrimary = Color(0xff0F172A);
  static const Color textSecondary = Color(0xff64748B);
  static const Color border = Color(0xffE2E8F0);
}

enum OrderStatus {
  toPay,
  toShip,
  toDeliver,
  completed,
  cancelled,
}

// ==================== DATA MODELS ====================
class OrderItem {
  final String productId;
  final String productName;
  final int quantity;
  final double pricePerUnit;
  final String unit;

  const OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.pricePerUnit,
    this.unit = 'kg',
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? map['id'] ?? '',
      productName: map['name'] ?? map['productName'] ?? map['title'] ?? 'Product Item',
      quantity: int.tryParse(map['quantity']?.toString() ?? '1') ?? 1,
      pricePerUnit: double.tryParse(map['price']?.toString() ?? map['pricePerUnit']?.toString() ?? '0') ?? 0.0,
      unit: map['unit']?.toString() ?? 'kg',
    );
  }
}

class OrderModel {
  final String id;
  final String userId;
  final String customerName;
  final String deliveryAddress;
  final String contactNumber;
  final String paymentMethod;
  final String paymentRef;
  final List<OrderItem> items;
  final OrderStatus status;
  final double totalAmount;
  final DateTime orderDate;

  const OrderModel({
    required this.id,
    required this.userId,
    required this.customerName,
    required this.deliveryAddress,
    required this.contactNumber,
    required this.paymentMethod,
    required this.paymentRef,
    required this.items,
    required this.status,
    required this.totalAmount,
    required this.orderDate,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    List<OrderItem> parsedItems = [];
    if (data['items'] is Map) {
      final itemsMap = data['items'] as Map<String, dynamic>;
      itemsMap.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          parsedItems.add(OrderItem.fromMap({'productId': key, ...value}));
        }
      });
    } else if (data['items'] is List) {
      final list = data['items'] as List;
      parsedItems = list.map((i) => OrderItem.fromMap(i as Map<String, dynamic>)).toList();
    }

    OrderStatus parsedStatus = OrderStatus.toPay;
    final rawStatus = (data['orderStatus'] ?? data['status'] ?? 'Pending').toString().toLowerCase().trim();

    if (rawStatus == 'pending' || rawStatus == 'topay' || rawStatus == 'to pay' || rawStatus == 'unpaid') {
      parsedStatus = OrderStatus.toPay;
    } else if (rawStatus == 'toship' || rawStatus == 'to ship' || rawStatus == 'paid' || rawStatus == 'processing') {
      parsedStatus = OrderStatus.toShip;
    } else if (rawStatus == 'todeliver' || rawStatus == 'to deliver' || rawStatus == 'shipping' || rawStatus == 'shipped') {
      parsedStatus = OrderStatus.toDeliver;
    } else if (rawStatus == 'completed' || rawStatus == 'delivered' || rawStatus == 'done') {
      parsedStatus = OrderStatus.completed;
    } else if (rawStatus == 'cancelled' || rawStatus == 'canceled') {
      parsedStatus = OrderStatus.cancelled;
    }

    double calculatedTotal = double.tryParse(data['totalAmount']?.toString() ?? data['totalPrice']?.toString() ?? data['total']?.toString() ?? '0') ?? 0.0;
    if (calculatedTotal == 0.0 && parsedItems.isNotEmpty) {
      for (var item in parsedItems) {
        calculatedTotal += (item.pricePerUnit * item.quantity);
      }
    }

    final Timestamp? rawTimestamp = data['createdAt'] ?? data['orderDate'] ?? data['date'];

    return OrderModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      customerName: data['customerName'] ?? data['userName'] ?? data['name'] ?? 'Buyer',
      deliveryAddress: data['deliveryAddress'] ?? data['address'] ?? 'No Address',
      contactNumber: data['contactNumber'] ?? data['phone'] ?? data['mobile'] ?? 'No Contact',
      paymentMethod: data['paymentMethod'] ?? data['paymentType'] ?? 'COD',
      paymentRef: data['paymentRef'] ?? data['referenceNumber'] ?? 'N/A',
      items: parsedItems,
      status: parsedStatus,
      totalAmount: calculatedTotal,
      orderDate: rawTimestamp?.toDate() ?? DateTime.now(),
    );
  }
}

// ==================== MAIN UI ====================
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  OrderStatus? _selectedStatusFilter;
  String _searchQuery = "";
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getStatusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.toPay: return "To Pay";
      case OrderStatus.toShip: return "To Ship";
      case OrderStatus.toDeliver: return "Out for Delivery";
      case OrderStatus.completed: return "Completed";
      case OrderStatus.cancelled: return "Cancelled";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgSurface,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("orders")
              .orderBy("createdAt", descending: true)
              .limit(100)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue));
            }

            final docs = snapshot.data?.docs ?? [];
            final List<OrderModel> allOrders = docs.map((d) => OrderModel.fromFirestore(d)).toList();

            // METRICS COMPUTATION
            int toPayCount = 0;
            int toShipCount = 0;
            int toDeliverCount = 0;
            int completedCount = 0;
            int cancelledCount = 0;
            double totalRevenue = 0;

            for (var order in allOrders) {
              switch (order.status) {
                case OrderStatus.toPay: toPayCount++; break;
                case OrderStatus.toShip: toShipCount++; break;
                case OrderStatus.toDeliver: toDeliverCount++; break;
                case OrderStatus.completed: 
                  completedCount++; 
                  totalRevenue += order.totalAmount;
                  break;
                case OrderStatus.cancelled: cancelledCount++; break;
              }
            }

            // FILTERING
            List<OrderModel> filteredOrders = allOrders;

            if (_selectedStatusFilter != null) {
              filteredOrders = filteredOrders.where((o) => o.status == _selectedStatusFilter).toList();
            }

            if (_searchQuery.isNotEmpty) {
              filteredOrders = filteredOrders.where((o) {
                final hasMatchingItem = o.items.any((item) => item.productName.toLowerCase().contains(_searchQuery));
                return o.id.toLowerCase().contains(_searchQuery) ||
                    o.customerName.toLowerCase().contains(_searchQuery) ||
                    hasMatchingItem;
              }).toList();
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SEARCH BAR
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
                      decoration: InputDecoration(
                        hintText: "Search name, order ID, or product...",
                        hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textSecondary),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = "");
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // METRICS BAR (SMOOTH SCROLL HORIZONTAL)
                  SizedBox(
                    height: 58,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _MetricCard(
                          title: "To Pay",
                          count: toPayCount,
                          color: const Color(0xffD97706),
                          isSelected: _selectedStatusFilter == OrderStatus.toPay,
                          onTap: () => setState(() => _selectedStatusFilter = _selectedStatusFilter == OrderStatus.toPay ? null : OrderStatus.toPay),
                        ),
                        _MetricCard(
                          title: "To Ship",
                          count: toShipCount,
                          color: Colors.purple,
                          isSelected: _selectedStatusFilter == OrderStatus.toShip,
                          onTap: () => setState(() => _selectedStatusFilter = _selectedStatusFilter == OrderStatus.toShip ? null : OrderStatus.toShip),
                        ),
                        _MetricCard(
                          title: "To Deliver",
                          count: toDeliverCount,
                          color: const Color(0xff0891B2),
                          isSelected: _selectedStatusFilter == OrderStatus.toDeliver,
                          onTap: () => setState(() => _selectedStatusFilter = _selectedStatusFilter == OrderStatus.toDeliver ? null : OrderStatus.toDeliver),
                        ),
                        _MetricCard(
                          title: "Completed",
                          count: completedCount,
                          color: const Color(0xff16A34A),
                          isSelected: _selectedStatusFilter == OrderStatus.completed,
                          onTap: () => setState(() => _selectedStatusFilter = _selectedStatusFilter == OrderStatus.completed ? null : OrderStatus.completed),
                        ),
                        _MetricCard(
                          title: "Cancelled",
                          count: cancelledCount,
                          color: const Color(0xffDC2626),
                          isSelected: _selectedStatusFilter == OrderStatus.cancelled,
                          onTap: () => setState(() => _selectedStatusFilter = _selectedStatusFilter == OrderStatus.cancelled ? null : OrderStatus.cancelled),
                        ),
                        _SalesCard(title: "Sales", revenue: totalRevenue),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ACTIVE FILTER BADGE
                  if (_selectedStatusFilter != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Filtered: ${_getStatusLabel(_selectedStatusFilter!)}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryBlue),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _selectedStatusFilter = null),
                          child: const Text("Show All", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // HIGH PERFORMANCE ORDERS LIST
                  Expanded(
                    child: filteredOrders.isEmpty
                        ? const Center(
                            child: Text("No orders found.", style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            addAutomaticKeepAlives: true,
                            addRepaintBoundaries: true,
                            itemCount: filteredOrders.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: OrderCardItem(
                                  order: filteredOrders[index],
                                  statusLabel: _getStatusLabel(filteredOrders[index].status),
                                  onUpdateTap: () => _openPipelineManager(context, filteredOrders[index]),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _openPipelineManager(BuildContext parentContext, OrderModel order) {
    OrderStatus temporaryStatus = order.status;
    bool isSubmitting = false;

    showModalBottomSheet(
      isScrollControlled: true,
      context: parentContext,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Update Status", style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  Text("Order #${order.id.toUpperCase()}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const Divider(height: 20),
                  DropdownButtonFormField<OrderStatus>(
                    value: temporaryStatus,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.bgSurface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                    ),
                    items: OrderStatus.values.map((status) {
                      return DropdownMenuItem(value: status, child: Text(_getStatusLabel(status)));
                    }).toList(),
                    onChanged: isSubmitting ? null : (val) => setModalState(() => temporaryStatus = val ?? temporaryStatus),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setModalState(() => isSubmitting = true);
                              try {
                                String statusString = "Pending";
                                String notificationMessage = "";

                                switch (temporaryStatus) {
                                  case OrderStatus.toPay:
                                    statusString = "To Pay";
                                    notificationMessage = "Ang iyong order ay naghihintay ng kumpirmasyon sa bayad.";
                                    break;
                                  case OrderStatus.toShip:
                                    statusString = "To Ship";
                                    notificationMessage = "Inihahanda at pino-proseso na ang iyong order.";
                                    break;
                                  case OrderStatus.toDeliver:
                                    statusString = "To Deliver";
                                    notificationMessage = "Out for delivery na ang iyong order!";
                                    break;
                                  case OrderStatus.completed:
                                    statusString = "Completed";
                                    notificationMessage = "Na-deliver na ang iyong order! Maraming salamat!";
                                    break;
                                  case OrderStatus.cancelled:
                                    statusString = "Cancelled";
                                    notificationMessage = "Nakansela ang iyong order.";
                                    break;
                                }

                                final batch = FirebaseFirestore.instance.batch();
                                final orderRef = FirebaseFirestore.instance.collection("orders").doc(order.id);

                                batch.update(orderRef, {
                                  'status': statusString,
                                  'orderStatus': statusString,
                                  'isPaid': temporaryStatus == OrderStatus.completed,
                                  'lastUpdated': FieldValue.serverTimestamp(),
                                });

                                if (order.userId.isNotEmpty) {
                                  final notifRef = FirebaseFirestore.instance.collection("users").doc(order.userId).collection("notifications").doc();
                                  batch.set(notifRef, {
                                    "title": "Order Update",
                                    "body": notificationMessage,
                                    "type": "ORDER_UPDATE",
                                    "status": statusString,
                                    "orderId": order.id,
                                    "isRead": false,
                                    "createdAt": FieldValue.serverTimestamp(),
                                  });
                                }

                                await batch.commit();

                                if (!context.mounted) return;
                                Navigator.pop(context);
                              } catch (e) {
                                setModalState(() => isSubmitting = false);
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("Save Status", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

// ==================== OPTIMIZED SUB-WIDGETS ====================

class _MetricCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _MetricCard({
    required this.title,
    required this.count,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 95,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? color : AppTheme.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppTheme.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              "$count",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: isSelected ? Colors.white : color),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesCard extends StatelessWidget {
  final String title;
  final double revenue;

  const _SalesCard({required this.title, required this.revenue});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xff16A34A).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xff16A34A).withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xff16A34A))),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text("₱${revenue.toStringAsFixed(2)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xff16A34A))),
          ),
        ],
      ),
    );
  }
}

class OrderCardItem extends StatelessWidget {
  final OrderModel order;
  final String statusLabel;
  final VoidCallback onUpdateTap;

  const OrderCardItem({
    super.key,
    required this.order,
    required this.statusLabel,
    required this.onUpdateTap,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (order.status) {
      case OrderStatus.toPay: statusColor = const Color(0xffD97706); break;
      case OrderStatus.toShip: statusColor = Colors.purple; break;
      case OrderStatus.toDeliver: statusColor = const Color(0xff0891B2); break;
      case OrderStatus.completed: statusColor = const Color(0xff16A34A); break;
      case OrderStatus.cancelled: statusColor = const Color(0xffDC2626); break;
    }

    final displayId = order.id.length >= 8 ? order.id.substring(0, 8) : order.id;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("ORDER #${displayId.toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary, fontFamily: 'monospace')),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 6),
          Text("Buyer: ${order.customerName} (${order.contactNumber})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
          Text("Address: ${order.deliveryAddress}", style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const Divider(height: 16, color: AppTheme.border),

          ...order.items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 5, color: AppTheme.primaryBlue),
                  const SizedBox(width: 6),
                  Expanded(child: Text("${item.productName} (${item.quantity} ${item.unit})", style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary))),
                  Text("₱${(item.pricePerUnit * item.quantity).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ],
              ),
            );
          }),

          const Divider(height: 16, color: AppTheme.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total: ₱${order.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.primaryBlue)),
              InkWell(
                onTap: onUpdateTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AppTheme.textPrimary, borderRadius: BorderRadius.circular(6)),
                  child: const Text("Update Status", style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}