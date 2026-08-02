import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

// Domain & Services
import '../../domain/weather_entity.dart';
import '../../domain/weather_repository.dart';
import '../../services/weather/weather_api_service.dart';
import '../../services/weather/weather_repository_impl.dart';

// Pages
import 'inventory_page.dart';
import 'order_page.dart';
import 'reports_page.dart';
import 'weather_page.dart';
import 'guidance_page.dart';
import 'notification_page.dart';
import 'user_management_page.dart';
import '../../services/notification/notification_service.dart';

class DashboardPage extends StatefulWidget {
  final String userRole;

  const DashboardPage({
    super.key,
    this.userRole = 'admin',
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentMenuIndex = 0;
  Timer? _inactivityTimer;

  static const int _adminTimeoutSeconds = 15 * 60;

  // Modern Enterprise Palette
  static const Color _bg = Color(0xffF8FAFC);
  static const Color _cardBg = Color(0xffFFFFFF);
  static const Color _primary = Color(0xff059669);
  static const Color _textMain = Color(0xff0F172A);
  static const Color _textSub = Color(0xff64748B);
  static const Color _border = Color(0xffE2E8F0);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _messageController = TextEditingController();

  StreamSubscription? _inventorySub;
  StreamSubscription? _ordersSub;
  StreamSubscription? _weatherSub;

  late final WeatherRepository _weatherRepository;
  late Future<WeatherEntity> _weatherFuture;

  static const double latitude = 14.9540;
  static const double longitude = 120.7594;

  @override
  void initState() {
    super.initState();
    
    final apiService = WeatherApiService(http.Client());
    _weatherRepository = WeatherRepositoryImpl(apiService: apiService);
    _fetchLiveWeather();

    _resetInactivityTimer();
    _initRealtimeListeners();
  }

  void _fetchLiveWeather() {
    setState(() {
      _weatherFuture = _weatherRepository.getWeatherByCoordinates(latitude, longitude);
    });
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (widget.userRole == 'admin') {
      _inactivityTimer = Timer(const Duration(seconds: _adminTimeoutSeconds), () {
        if (mounted) _showAutoLogoutDialog();
      });
    }
  }

  void _showAutoLogoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Session Expired"),
        content: const Text("Na-auto logout ka dahil sa kawalan ng galaw bilang Admin."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performLogout();
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _performLogout() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Naka-logout na ang session.")),
    );
  }

  void _initRealtimeListeners() {
    // 1. INVENTORY LISTENER (products collection)
    _inventorySub = FirebaseFirestore.instance.collection('products').snapshots().listen((snap) {
      for (var change in snap.docChanges) {
        if (change.type == DocumentChangeType.modified || change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            final stockVal = int.tryParse(data['stock']?.toString() ?? '0') ?? 0;
            final lowThreshold = int.tryParse(data['lowStockThreshold']?.toString() ?? '10') ?? 10;
            
            if (stockVal <= lowThreshold) {
              _sendSystemNotification(
                title: "⚠️ Low Stock Alert",
                body: "Mababa na ang stock ng '${data['name'] ?? data['productName'] ?? 'Rice'}'.",
                channelId: NotificationService.channelAlerts,
              );
            }
          }
        }
      }
    });

    // 2. ORDERS LISTENER
    _ordersSub = FirebaseFirestore.instance.collection('orders').snapshots().listen((snap) {
      for (var change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;
          _sendSystemNotification(
            title: "🛍️ Bagong Order",
            body: "Order mula kay ${data['customerName'] ?? data['clientName'] ?? 'Customer'}.",
            channelId: NotificationService.channelOrders,
          );
        }
      }
    });

    // 3. WEATHER ALERTS LISTENER
    _weatherSub = FirebaseFirestore.instance.collection('weather_alerts').snapshots().listen((snap) {
      for (var change in snap.docChanges) {
        final data = change.doc.data();
        if (data != null && (data['isTyphoonWarning'] ?? false)) {
          _sendSystemNotification(
            title: "🚨 SOS: PAPARATING NA BAGYO",
            body: "Babala: ${data['typhoonName'] ?? 'Bagyo'} sa sakahan.",
            channelId: NotificationService.channelTyphoonSOS,
          );
        }
      }
    });
  }

  Future<void> _sendSystemNotification({
    required String title,
    required String body,
    required String channelId,
  }) async {
    NotificationService.showNotification(title: title, body: body, channelId: channelId);
    await FirebaseFirestore.instance.collection('notifications').add({
      'title': title,
      'body': body,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _inventorySub?.cancel();
    _ordersSub?.cancel();
    _weatherSub?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  List<_NavigationItem> get _navigationMenu {
    final list = [
      const _NavigationItem(Icons.grid_view_rounded, "Dashboard", null),
      const _NavigationItem(Icons.inventory_2_outlined, "Inventory", InventoryPage()),
      const _NavigationItem(Icons.shopping_bag_outlined, "Orders", OrdersPage()),
      const _NavigationItem(Icons.menu_book_outlined, "Guidance", GuidancePage()),
      const _NavigationItem(Icons.analytics_outlined, "Reports", ReportsPage()),
      const _NavigationItem(Icons.cloud_outlined, "Weather", WeatherPage()),
    ];

    if (widget.userRole == 'admin') {
      list.add(const _NavigationItem(Icons.admin_panel_settings_outlined, "Users", UserManagementPage()));
    }

    return list;
  }

  void _openChatModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.65,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("System Messages", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textMain)),
                    IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const Divider(color: _border),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('messages').orderBy('timestamp', descending: true).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final docs = snapshot.data!.docs;
                      
                      if (docs.isEmpty) {
                        return const Center(child: Text("Walang mensahe.", style: TextStyle(color: _textSub)));
                      }

                      return ListView.builder(
                        reverse: true,
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final isMe = data['senderRole'] == widget.userRole;

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? _primary : const Color(0xffF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(data['senderName'] ?? 'User', style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : _textSub, fontWeight: FontWeight.bold)),
                                  Text(data['text'] ?? '', style: TextStyle(color: isMe ? Colors.white : _textMain, fontSize: 13)),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: "Isulat ang mensahe...",
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            fillColor: _bg,
                            filled: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send_rounded, color: _primary),
                        onPressed: () async {
                          if (_messageController.text.trim().isEmpty) return;
                          final text = _messageController.text.trim();
                          _messageController.clear();
                          await FirebaseFirestore.instance.collection('messages').add({
                            'text': text,
                            'senderName': widget.userRole == 'admin' ? 'Admin' : 'User',
                            'senderRole': widget.userRole,
                            'timestamp': FieldValue.serverTimestamp(),
                          });
                        },
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _resetInactivityTimer(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;
          final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 900;
          
          final menuList = _navigationMenu;
          final safeIndex = _currentMenuIndex < menuList.length ? _currentMenuIndex : 0;

          final Widget activeBody = AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: safeIndex == 0
                ? _buildDashboardHome(isDesktop, isTablet)
                : (menuList[safeIndex].page ?? _buildDashboardHome(isDesktop, isTablet)),
          );

          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: _bg,
            endDrawer: _buildDrawer(),
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(isDesktop),
                  Expanded(child: activeBody),
                  _buildUniversalNavBar(isDesktop),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 12),
      decoration: const BoxDecoration(
        color: _cardBg,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: _primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.eco_rounded, color: _primary, size: 20),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    "ArrozSistema",
                    style: TextStyle(color: _textMain, fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: _textSub, size: 20),
            onPressed: _openChatModal,
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('notifications').where('isRead', isEqualTo: false).snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, color: _textSub, size: 22),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPage())),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
            child: const CircleAvatar(
              radius: 14,
              backgroundColor: _border,
              child: Icon(Icons.person, size: 16, color: _textSub),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardHome(bool isDesktop, bool isTablet) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Admin Command Center 👋", style: TextStyle(color: _textMain, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("Live metrics & operational status", style: TextStyle(color: _textSub, fontSize: 11)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _primary.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.circle, color: _primary, size: 8),
                    SizedBox(width: 4),
                    Text("LIVE", style: TextStyle(color: _primary, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 14),
          
          _buildGoogleStyleWeatherCard(),
          const SizedBox(height: 14),

          // LIVE FARM MARKET RATE CARD (REALTIME ACCURATE DATA)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('products').snapshots(),
            builder: (context, snapshot) {
              String rateDisplay = "₱0.00 / kg";
              String productName = "No Product Registered";

              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                final docData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                final price = docData['price']?.toString() ?? '0';
                productName = docData['name'] ?? docData['productName'] ?? 'Palay';
                rateDisplay = "₱$price.00 / kg";
              }

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.trending_up_rounded, color: _primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text("MARKET RATE", style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 6),
                              Text("• $productName", style: const TextStyle(color: _textSub, fontSize: 10, fontWeight: FontWeight.w500)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(rateDisplay, style: const TextStyle(color: _textMain, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 18),

          const Text("Operations & Metrics Overview", style: TextStyle(color: _textMain, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          
          // RESPONSIVE INTERACTIVE KPI GRID
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: isDesktop ? 280 : (isTablet ? 250 : 180),
              mainAxisExtent: 125,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            children: [
              // 1. INVENTORY MODULE KPI
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('products').snapshots(),
                builder: (context, snapshot) {
                  int totalStock = 0;
                  bool hasLowStock = false;

                  if (snapshot.hasData) {
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final stockVal = int.tryParse(data['stock']?.toString() ?? '0') ?? 0;
                      final lowThreshold = int.tryParse(data['lowStockThreshold']?.toString() ?? '10') ?? 10;
                      
                      totalStock += stockVal;
                      if (stockVal <= lowThreshold) hasLowStock = true;
                    }
                  }

                  return _buildInteractiveKpiCard(
                    categoryLabel: "INVENTORY",
                    title: "Total Rice Stocks",
                    value: "$totalStock Sacks",
                    subtitle: hasLowStock ? "Low Stock Alert!" : "Optimal Supply Level",
                    icon: Icons.inventory_2_rounded,
                    color: Colors.blue,
                    hasAlert: hasLowStock,
                    alertText: "LOW",
                    onTap: () => setState(() => _currentMenuIndex = 1),
                  );
                },
              ),

              // 2. ORDERS MODULE KPI (MGA UNPAID / TO PAY ORDERS LAMANG)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('orders').snapshots(),
                builder: (context, snapshot) {
                  int toPayCount = 0;

                  if (snapshot.hasData) {
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final status = (data['status'] ?? '').toString().toLowerCase();
                      final isPaid = data['isPaid'] ?? true;

                      // KUKUNIN LANG ANG MGA HINDI PA PAID (isPaid == false O status na 'to pay' / 'pending')
                      if (isPaid == false || status == 'to pay' || status == 'pending' || status == 'unpaid') {
                        toPayCount++;
                      }
                    }
                  }

                  return _buildInteractiveKpiCard(
                    categoryLabel: "ORDERS",
                    title: "New Orders (To Pay)",
                    value: "$toPayCount Orders",
                    subtitle: toPayCount > 0 ? "Awaiting Payment" : "No Pending Orders",
                    icon: Icons.shopping_bag_rounded,
                    color: Colors.orange,
                    hasAlert: toPayCount > 0,
                    alertText: "$toPayCount TO PAY",
                    onTap: () => setState(() => _currentMenuIndex = 2),
                  );
                },
              ),

              // 3. GUIDANCE MODULE KPI (100% REALTIME DYNAMICAL DATA)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('crop_tracker').limit(1).snapshots(),
                builder: (context, snapshot) {
                  String cropAgeText = "No Active Crop";
                  String conditionText = "Optimal Condition";
                  bool hasWarning = false;

                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    final data = snapshot.data!.docs.first.data() as Map<String, dynamic>?;
                    final days = int.tryParse(data?['plantingDays']?.toString() ?? '0') ?? 0;
                    
                    if (days > 0) {
                      if (days <= 15) {
                        cropAgeText = "Vegetative (Day $days)";
                        conditionText = "Optimal Condition";
                      } else if (days <= 60) {
                        cropAgeText = "Reproductive (Day $days)";
                        conditionText = "Watch Water Level";
                      } else {
                        cropAgeText = "Ripening (Day $days)";
                        conditionText = "Ready for Harvest";
                      }
                    }

                    if (data?['warning'] != null && data!['warning'].toString().isNotEmpty) {
                      conditionText = data['warning'];
                      hasWarning = true;
                    }
                  }

                  return _buildInteractiveKpiCard(
                    categoryLabel: "GUIDANCE",
                    title: "Crop Health Status",
                    value: cropAgeText,
                    subtitle: conditionText,
                    icon: Icons.eco_rounded,
                    color: Colors.teal,
                    hasAlert: hasWarning,
                    alertText: "ALERT",
                    onTap: () => setState(() => _currentMenuIndex = 3),
                  );
                },
              ),

              // 4. REPORTS MODULE KPI (MGA COMPLETED / PAID ORDERS LAMANG - ACCURATE)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('orders').snapshots(),
                builder: (context, snapshot) {
                  double totalCompletedRevenue = 0.0;

                  if (snapshot.hasData) {
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final isPaid = data['isPaid'] ?? false;
                      final status = (data['status'] ?? '').toString().toLowerCase();

                      // BABASAHIN LANG ANG REVENUE KUNG NAKUMPLETO O NABAYARAN NA ANG ORDER (isPaid == true)
                      if (isPaid == true || status == 'completed' || status == 'paid' || status == 'delivered') {
                        double orderTotal = double.tryParse(data['totalAmount']?.toString() ?? data['totalPrice']?.toString() ?? '0') ?? 0.0;
                        
                        // Kung walang direct total sum sa top field, kwentahin mula sa items list
                        if (orderTotal == 0.0 && data['items'] != null && data['items'] is List) {
                          final items = data['items'] as List<dynamic>;
                          for (var item in items) {
                            final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
                            final qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
                            orderTotal += (price * qty);
                          }
                        }

                        totalCompletedRevenue += orderTotal;
                      }
                    }
                  }

                  return _buildInteractiveKpiCard(
                    categoryLabel: "REPORTS",
                    title: "Completed Revenue",
                    value: "₱${totalCompletedRevenue.toStringAsFixed(2)}",
                    subtitle: "100% Realtime Sales",
                    icon: Icons.analytics_rounded,
                    color: Colors.green,
                    hasAlert: false,
                    alertText: "",
                    onTap: () => setState(() => _currentMenuIndex = 4),
                  );
                },
              ),

              // 5. USER MANAGEMENT MODULE KPI
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, snapshot) {
                  int totalUsers = 0;
                  bool hasNewUser = false;

                  if (snapshot.hasData) {
                    totalUsers = snapshot.data!.docs.length;
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (data['isNew'] == true) hasNewUser = true;
                    }
                  }

                  return _buildInteractiveKpiCard(
                    categoryLabel: "USERS",
                    title: "Registered Users",
                    value: "$totalUsers Accounts",
                    subtitle: "Active System Users",
                    icon: Icons.people_alt_rounded,
                    color: Colors.indigo,
                    hasAlert: hasNewUser,
                    alertText: "NEW",
                    onTap: () {
                      if (widget.userRole == 'admin') {
                        setState(() => _currentMenuIndex = 6);
                      }
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveKpiCard({
    required String categoryLabel,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool hasAlert,
    required String alertText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: hasAlert ? Colors.redAccent.withOpacity(0.5) : _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(icon, size: 16, color: color),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          categoryLabel,
                          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: _textSub),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(color: _textMain, fontSize: 15, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: hasAlert ? Colors.redAccent : _textSub, fontSize: 10, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (hasAlert)
            Positioned(
              top: 8,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  alertText,
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGoogleStyleWeatherCard() {
    return FutureBuilder<WeatherEntity>(
      future: _weatherFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xff047857),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xff047857),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_off_rounded, color: Colors.white),
                const SizedBox(width: 10),
                const Expanded(child: Text("Offline / Weather Unavailable", style: TextStyle(color: Colors.white, fontSize: 12))),
                IconButton(icon: const Icon(Icons.refresh, color: Colors.white, size: 18), onPressed: _fetchLiveWeather),
              ],
            ),
          );
        }

        final weather = snapshot.data!;

        return InkWell(
          onTap: () => setState(() => _currentMenuIndex = 5),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff065F46), Color(0xff047857)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xff059669).withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_on_rounded, color: Colors.white70, size: 14),
                        SizedBox(width: 4),
                        Text("Capalangan, Pampanga", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                      child: const Text("WEATHER MODULE", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _getWeatherIcon(weather.condition),
                        const SizedBox(width: 10),
                        Text("${weather.temperature.toStringAsFixed(1)}°C", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(weather.condition, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text("Humidity: ${weather.humidity}%", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        Text("Feels Like: ${weather.feelsLike}°C", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                      ],
                    )
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _getWeatherIcon(String condition) {
    final lower = condition.toLowerCase();
    if (lower.contains('rain')) return const Icon(Icons.grain_rounded, color: Color(0xff93C5FD), size: 32);
    if (lower.contains('cloud')) return const Icon(Icons.cloud_queue_rounded, color: Colors.white70, size: 32);
    return const Icon(Icons.wb_sunny_rounded, color: Color(0xffFDE047), size: 32);
  }

  Widget _buildUniversalNavBar(bool isDesktop) {
    final primaryItems = [
      {'index': 0, 'icon': Icons.grid_view_rounded, 'label': 'Dashboard'},
      {'index': 1, 'icon': Icons.inventory_2_outlined, 'label': 'Inventory'},
      {'index': 2, 'icon': Icons.shopping_bag_outlined, 'label': 'Orders'},
      {'index': 3, 'icon': Icons.menu_book_outlined, 'label': 'Guidance'},
    ];

    return Container(
      decoration: const BoxDecoration(color: _cardBg, border: Border(top: BorderSide(color: _border))),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 4, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ...primaryItems.map((item) {
            final isSelected = _currentMenuIndex == item['index'];
            return Expanded(
              child: InkWell(
                onTap: () => setState(() => _currentMenuIndex = item['index'] as int),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item['icon'] as IconData, color: isSelected ? _primary : _textSub, size: 18),
                    const SizedBox(height: 2),
                    Text(item['label'] as String, style: TextStyle(color: isSelected ? _primary : _textSub, fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
            );
          }),
          Expanded(
            child: PopupMenuButton<int>(
              onSelected: (index) => setState(() => _currentMenuIndex = index),
              icon: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.more_horiz_rounded, color: _currentMenuIndex >= 4 ? _primary : _textSub, size: 18),
                  const SizedBox(height: 2),
                  Text('More', style: TextStyle(color: _currentMenuIndex >= 4 ? _primary : _textSub, fontSize: 10)),
                ],
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 4, child: Text("Reports")),
                const PopupMenuItem(value: 5, child: Text("Weather Forecast")),
                if (widget.userRole == 'admin') const PopupMenuItem(value: 6, child: Text("Managing Accounts")),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _cardBg,
      child: SafeArea(
        child: Column(
          children: [
            const UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: _bg),
              accountName: Text("System Admin", style: TextStyle(color: _textMain, fontWeight: FontWeight.bold)),
              accountEmail: Text("admin@arrozsistema.com", style: TextStyle(color: _textSub)),
              currentAccountPicture: CircleAvatar(backgroundColor: _primary, child: Icon(Icons.person, color: Colors.white)),
            ),
            ListTile(
              leading: const Icon(Icons.grid_view_rounded),
              title: const Text("Dashboard Overview"),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentMenuIndex = 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text("Inventory"),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentMenuIndex = 1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_bag_outlined),
              title: const Text("Orders"),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentMenuIndex = 2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text("Guidance Hub"),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentMenuIndex = 3);
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics_outlined),
              title: const Text("Reports"),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentMenuIndex = 4);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text("Weather Forecast"),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentMenuIndex = 5);
              },
            ),
            if (widget.userRole == 'admin')
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text("User Management"),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentMenuIndex = 6);
                },
              ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: const Text("Logout"),
              onTap: () {
                Navigator.pop(context);
                _performLogout();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationItem {
  final IconData icon;
  final String title;
  final Widget? page;
  const _NavigationItem(this.icon, this.title, this.page);
}