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
  toPay("To Pay", Color(0xffD97706), "Ang iyong order ay naghihintay ng kumpirmasyon sa bayad."),
  toShip("To Ship", Colors.purple, "Inihahanda at pino-proseso na ang iyong order."),
  toDeliver("Out for Delivery", Color(0xff0891B2), "Out for delivery na ang iyong order!"),
  completed("Completed", Color(0xff16A34A), "Na-deliver na ang iyong order! Maraming salamat!"),
  cancelled("Cancelled", Color(0xffDC2626), "Nakansela ang iyong order.");

  final String label;
  final Color color;
  final String notificationMessage;

  const OrderStatus(this.label, this.color, this.notificationMessage);

  static OrderStatus parse(String rawStatus) {
    final status = rawStatus.toLowerCase().trim();
    if (['pending', 'topay', 'to pay', 'unpaid'].contains(status)) return OrderStatus.toPay;
    if (['toship', 'to ship', 'paid', 'processing'].contains(status)) return OrderStatus.toShip;
    // INAYOS: Idinagdag ang 'out for delivery' at 'outfordelivery' para ma-parse nang tama mula sa Firestore.
    if (['todeliver', 'to deliver', 'shipping', 'shipped', 'out for delivery', 'outfordelivery'].contains(status)) {
      return OrderStatus.toDeliver;
    }
    if (['completed', 'delivered', 'done'].contains(status)) return OrderStatus.completed;
    if (['cancelled', 'canceled'].contains(status)) return OrderStatus.cancelled;
    return OrderStatus.toPay;
  }
}

/// Default delivery notice values.
/// Keep these as normal Dart strings; customers can still edit the notice
/// through the Delivery Delay Notice dialog and the values are saved to Firestore.
const String kDefaultDeliveryNoticeTitle = 'Delivery Delay Notice';
const String kDefaultDeliveryNoticeMessage =
    'Maaaring magkaroon ng delay sa delivery dahil sa masamang panahon.';
const String kDefaultDeliveryNoticeDelay = '1–2 days';
const String kDefaultDeliveryNoticeReason = 'Severe Weather';

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
    required this.unit,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    final rawUnit = (map['unit'] ?? map['unitType'] ?? map['type'] ?? '').toString().toLowerCase().trim();
    final String name = map['name'] ?? map['productName'] ?? map['title'] ?? 'Product Item';

    String resolvedUnit = 'kg';
    if (rawUnit.isNotEmpty) {
      resolvedUnit = rawUnit;
    } else if (name.toLowerCase().contains('sako') || name.toLowerCase().contains('sack')) {
      resolvedUnit = 'sako';
    }

    return OrderItem(
      productId: map['productId'] ?? map['id'] ?? '',
      productName: name,
      quantity: int.tryParse(map['quantity']?.toString() ?? '1') ?? 1,
      pricePerUnit: double.tryParse(map['price']?.toString() ?? map['pricePerUnit']?.toString() ?? '0') ?? 0.0,
      unit: resolvedUnit,
    );
  }

  String get formattedQuantity {
    final cleanUnit = unit.toLowerCase().trim();
    if (cleanUnit == 'sako' || cleanUnit == 'sack' || cleanUnit == 'sacks') {
      return '$quantity sako';
    } else if (cleanUnit == 'kg' || cleanUnit == 'kilo' || cleanUnit == 'kilos') {
      return '$quantity kg';
    } else if (cleanUnit.isNotEmpty) {
      return '$quantity $cleanUnit';
    }
    return '$quantity';
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
  final bool inventoryDeducted;

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
    this.inventoryDeducted = false,
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

    final rawStatus = (data['orderStatus'] ?? data['status'] ?? '').toString();
    final OrderStatus parsedStatus = OrderStatus.parse(rawStatus);

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
      contactNumber: data['contactNumber'] ??
          data['phoneNumber'] ??
          data['phone'] ??
          data['mobile'] ??
          data['contact'] ??
          data['contactNo'] ??
          'No Contact',
      paymentMethod: data['paymentMethod'] ?? data['paymentType'] ?? 'COD',
      paymentRef: data['paymentRef'] ??
          data['referenceNumber'] ??
          data['refNumber'] ??
          data['refNo'] ??
          data['referenceNo'] ??
          data['transactionId'] ??
          data['paymentReference'] ??
          '',
      items: parsedItems,
      status: parsedStatus,
      totalAmount: calculatedTotal,
      orderDate: rawTimestamp?.toDate() ?? DateTime.now(),
      inventoryDeducted: data['inventoryDeducted'] ?? false,
    );
  }
}

class DeliveryDelayNoticeDialog extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> noticeRef;
  final Map<String, dynamic> initialData;

  const DeliveryDelayNoticeDialog({
    super.key,
    required this.noticeRef,
    required this.initialData,
  });

  @override
  State<DeliveryDelayNoticeDialog> createState() =>
      _DeliveryDelayNoticeDialogState();
}

class _DeliveryDelayNoticeDialogState
    extends State<DeliveryDelayNoticeDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _messageController;
  late final TextEditingController _delayController;
  late final TextEditingController _reasonController;

  late bool _enabled;
  bool _isSaving = false;
  String? _errorMessage;

  String _valueOrDefault(String key, String fallback) {
    final value = widget.initialData[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  @override
  void initState() {
    super.initState();

    _enabled = widget.initialData['enabled'] == true;

    _titleController = TextEditingController(
      text: _valueOrDefault(
        'title',
        kDefaultDeliveryNoticeTitle,
      ),
    );

    _messageController = TextEditingController(
      text: _valueOrDefault(
        'message',
        kDefaultDeliveryNoticeMessage,
      ),
    );

    _delayController = TextEditingController(
      text: _valueOrDefault(
        'estimatedDelay',
        kDefaultDeliveryNoticeDelay,
      ),
    );

    _reasonController = TextEditingController(
      text: _valueOrDefault(
        'reason',
        kDefaultDeliveryNoticeReason,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _delayController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    final estimatedDelay = _delayController.text.trim();
    final reason = _reasonController.text.trim();

    try {
      await widget.noticeRef.set(
        {
          'enabled': _enabled,
          'title': title.isEmpty ? kDefaultDeliveryNoticeTitle : title,
          'message': message.isEmpty
              ? kDefaultDeliveryNoticeMessage
              : message,
          'estimatedDelay': estimatedDelay.isEmpty
              ? kDefaultDeliveryNoticeDelay
              : estimatedDelay,
          'reason': reason.isEmpty
              ? kDefaultDeliveryNoticeReason
              : reason,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      Navigator.of(context).pop(_enabled);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _errorMessage = 'Unable to save delivery notice. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Text(kDefaultDeliveryNoticeTitle),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ipakita sa customers'),
              subtitle: const Text(
                'Makikita sa Checkout at Orders page.',
              ),
              value: _enabled,
              onChanged: _isSaving
                  ? null
                  : (value) {
                      setState(() => _enabled = value);
                    },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              enabled: !_isSaving,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _messageController,
              enabled: !_isSaving,
              maxLines: 3,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _delayController,
              enabled: !_isSaving,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Estimated Delay',
                hintText: 'e.g. 1–2 days',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reasonController,
              enabled: !_isSaving,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'e.g. Severe Weather',
                border: OutlineInputBorder(),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save, color: Colors.white),
          label: Text(
            _isSaving ? 'Saving...' : 'Save',
            style: const TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
          ),
        ),
      ],
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
  late final Stream<QuerySnapshot> _ordersStream;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _ordersStream = FirebaseFirestore.instance
        .collection("orders")
        .orderBy("createdAt", descending: true)
        .limit(100)
        .snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgSurface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase().trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Search ID, phone, address, payment, name...",
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
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _openDeliveryDelayNoticeDialog(context),
                  icon: const Icon(Icons.cloud_off_outlined, size: 18),
                  label: const Text("Delivery Delay Notice"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade800,
                    side: BorderSide(color: Colors.orange.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _ordersStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue));
                    }

                    final docs = snapshot.data?.docs ?? [];
                    final List<OrderModel> allOrders = docs.map((d) => OrderModel.fromFirestore(d)).toList();

                    final Map<OrderStatus, int> statusCounts = { for (var e in OrderStatus.values) e : 0 };
                    double totalRevenue = 0;

                    for (var order in allOrders) {
                      statusCounts[order.status] = (statusCounts[order.status] ?? 0) + 1;
                      if (order.status == OrderStatus.completed) {
                        totalRevenue += order.totalAmount;
                      }
                    }

                    List<OrderModel> filteredOrders = allOrders;

                    if (_selectedStatusFilter != null) {
                      filteredOrders = filteredOrders.where((o) => o.status == _selectedStatusFilter).toList();
                    }

                    if (_searchQuery.isNotEmpty) {
                      filteredOrders = filteredOrders.where((o) {
                        final query = _searchQuery;

                        final matchesId = o.id.toLowerCase().contains(query);
                        final matchesCustomer = o.customerName.toLowerCase().contains(query);
                        final matchesContact = o.contactNumber.toLowerCase().contains(query);
                        final matchesAddress = o.deliveryAddress.toLowerCase().contains(query);
                        final matchesPaymentMethod = o.paymentMethod.toLowerCase().contains(query);
                        final matchesPaymentRef = o.paymentRef.toLowerCase().contains(query);

                        final matchesItemName = o.items.any((item) => item.productName.toLowerCase().contains(query));

                        return matchesId ||
                            matchesCustomer ||
                            matchesContact ||
                            matchesAddress ||
                            matchesPaymentMethod ||
                            matchesPaymentRef ||
                            matchesItemName;
                      }).toList();
                    }

                    return Column(
                      children: [
                        SizedBox(
                          height: 58,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            children: [
                              ...OrderStatus.values.map((status) => _MetricCard(
                                title: status.label,
                                count: statusCounts[status] ?? 0,
                                color: status.color,
                                isSelected: _selectedStatusFilter == status,
                                onTap: () => setState(() => _selectedStatusFilter = _selectedStatusFilter == status ? null : status),
                              )),
                              _SalesCard(title: "Sales", revenue: totalRevenue),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (_selectedStatusFilter != null) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Filtered: ${_selectedStatusFilter!.label}",
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
                                        onUpdateTap: () => _openPipelineManager(context, filteredOrders[index]),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
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

  Future<void> _openDeliveryDelayNoticeDialog(BuildContext parentContext) async {
    final noticeRef = FirebaseFirestore.instance
        .collection('app_settings')
        .doc('delivery_notice');

    try {
      final existing = await noticeRef.get();

      if (!parentContext.mounted) return;

      final data = existing.data() ?? <String, dynamic>{};

      final result = await showDialog<bool>(
        context: parentContext,
        barrierDismissible: true,
        builder: (dialogContext) {
          return DeliveryDelayNoticeDialog(
            noticeRef: noticeRef,
            initialData: data,
          );
        },
      );

      if (!parentContext.mounted || result == null) return;

      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(
          content: Text(
            result
                ? 'Delivery delay notice enabled.'
                : 'Delivery delay notice disabled.',
          ),
        ),
      );
    } catch (e) {
      if (!parentContext.mounted) return;

      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(
          content: Text('Unable to load delivery notice: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                      return DropdownMenuItem(value: status, child: Text(status.label));
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
                                bool shouldDeductStock = false;
                                bool shouldRestoreStock = false;

                                const activeStatuses = [OrderStatus.toShip, OrderStatus.toDeliver, OrderStatus.completed];

                                if (activeStatuses.contains(temporaryStatus) && !order.inventoryDeducted) {
                                  shouldDeductStock = true;
                                } else if (temporaryStatus == OrderStatus.cancelled && order.inventoryDeducted) {
                                  shouldRestoreStock = true;
                                }

                                await FirebaseFirestore.instance.runTransaction((transaction) async {
                                  final orderRef = FirebaseFirestore.instance.collection("orders").doc(order.id);

                                  if (shouldDeductStock || shouldRestoreStock) {
                                    for (var item in order.items) {
                                      int deductionKg = item.quantity;
                                      if (item.unit.toLowerCase().contains('sako') || item.unit.toLowerCase().contains('sack')) {
                                        deductionKg = item.quantity * 50; 
                                      }

                                      DocumentReference? productRef;

                                      if (item.productId.isNotEmpty) {
                                        final prodDoc = FirebaseFirestore.instance.collection("products").doc(item.productId);
                                        final snap = await transaction.get(prodDoc);
                                        if (snap.exists) {
                                          productRef = prodDoc;
                                        }
                                      }

                                      if (productRef == null) {
                                        final querySnap = await FirebaseFirestore.instance
                                            .collection("products")
                                            .where("isDeleted", isEqualTo: false)
                                            .get();

                                        for (var pDoc in querySnap.docs) {
                                          final pData = pDoc.data();
                                          final pName = (pData['name'] ?? '').toString().toLowerCase();
                                          if (pName.contains(item.productName.toLowerCase()) || item.productName.toLowerCase().contains(pName)) {
                                            productRef = pDoc.reference;
                                            break;
                                          }
                                        }
                                      }

                                      if (productRef != null) {
                                        final pSnap = await transaction.get(productRef);
                                        if (pSnap.exists) {
                                          final pData = pSnap.data() as Map<String, dynamic>? ?? {};
                                          final double currentRemainingKg = ((pData['remainingKg'] ?? pData['totalKg'] ?? 0.0) as num).toDouble();

                                          double newRemainingKg = currentRemainingKg;
                                          if (shouldDeductStock) {
                                            newRemainingKg = (currentRemainingKg - deductionKg).clamp(0.0, double.infinity);
                                          } else if (shouldRestoreStock) {
                                            newRemainingKg = currentRemainingKg + deductionKg;
                                          }

                                          transaction.update(productRef, {
                                            'remainingKg': newRemainingKg,
                                            'updatedAt': FieldValue.serverTimestamp(),
                                          });
                                        }
                                      }
                                    }
                                  }

                                  transaction.update(orderRef, {
                                    'status': temporaryStatus.label,
                                    'orderStatus': temporaryStatus.label,
                                    'isPaid': temporaryStatus == OrderStatus.completed,
                                    'inventoryDeducted': shouldDeductStock
                                        ? true
                                        : (shouldRestoreStock ? false : order.inventoryDeducted),
                                    'lastUpdated': FieldValue.serverTimestamp(),
                                  });

                                  if (order.userId.isNotEmpty) {
                                    final notifRef = FirebaseFirestore.instance.collection("users").doc(order.userId).collection("notifications").doc();
                                    transaction.set(notifRef, {
                                      "title": "Order Update",
                                      "body": temporaryStatus.notificationMessage,
                                      "type": "ORDER_UPDATE",
                                      "status": temporaryStatus.label,
                                      "orderId": order.id,
                                      "isRead": false,
                                      "createdAt": FieldValue.serverTimestamp(),
                                    });
                                  }
                                });

                                if (!context.mounted) return;
                                Navigator.pop(context);
                              } catch (e) {
                                setModalState(() => isSubmitting = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Error updating order: $e"), backgroundColor: Colors.red),
                                  );
                                }
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

// ==================== SUB-WIDGETS ====================

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
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: isSelected ? Colors.white : AppTheme.textPrimary),
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

  const _SalesCard({
    required this.title,
    required this.revenue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
          const SizedBox(height: 2),
          Text(
            "₱${revenue.toStringAsFixed(2)}",
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.primaryBlue),
          ),
        ],
      ),
    );
  }
}

class OrderCardItem extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onUpdateTap;

  const OrderCardItem({
    super.key,
    required this.order,
    required this.onUpdateTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Order #${order.id.substring(0, order.id.length > 8 ? 8 : order.id.length).toUpperCase()}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: order.status.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  order.status.label,
                  style: TextStyle(color: order.status.color, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text("Customer: ${order.customerName}", style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Text("Phone: ${order.contactNumber}", style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Text("Address: ${order.deliveryAddress}", style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const Divider(height: 16),
          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("• ${item.productName}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    Text("${item.formattedQuantity} x ₱${item.pricePerUnit}", style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              )),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total: ₱${order.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryBlue)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: onUpdateTap,
                icon: const Icon(Icons.edit_note, size: 16, color: Colors.white),
                label: const Text("Update", style: TextStyle(color: Colors.white, fontSize: 11)),
              )
            ],
          )
        ],
      ),
    );
  }
}