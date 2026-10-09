import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

// Auth Page
import 'login_page.dart'; 

// Domain & Services
import '../../domain/weather_entity.dart';
import '../../domain/weather_repository.dart';
import '../../services/weather/weather_api_service.dart';
import '../../services/weather/weather_repository_impl.dart';

// Pages
import 'inventory_page.dart';
import 'admin_order_page.dart';
import 'reports_page.dart';
import 'weather_page.dart';
import 'guidance_page.dart';
import 'notification_page_admin.dart';
import 'user_management_page.dart';
import '../../services/notification/notification_service_admin.dart';
import 'admin_chat_page.dart';

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

  // Palette
  static const Color _bg = Color(0xffF8FAFC);
  static const Color _cardBg = Color(0xffFFFFFF);
  static const Color _primary = Color(0xff059669);
  static const Color _textMain = Color(0xff0F172A);
  static const Color _textSub = Color(0xff64748B);
  static const Color _border = Color(0xffE2E8F0);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  StreamSubscription? _inventorySub;
  StreamSubscription? _ordersSub;
  StreamSubscription? _weatherSub;

  late final WeatherRepository _weatherRepository;
  late Future<WeatherEntity> _weatherFuture;

  // Fixed coordinates para sa Capalangan, Apalit, Pampanga
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
    if (!mounted) return;
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
        title: const Text("Naka-logout Muna"),
        content: const Text("Nakalimutan niyo po bang bukas ito? Naka-logout na po muna para safe ang inyong account."),
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

  void _performLogout() async {
    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Naka-logout na po kayo."),
          backgroundColor: Colors.redAccent,
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()), 
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pasensya na, nagka-problema sa pag-logout.")),
      );
    }
  }

  void _initRealtimeListeners() {
    // Inayos ang listener para maiwasan ang freezing sa pag-bootup ng app sa mobile
    _inventorySub = FirebaseFirestore.instance.collection('products').snapshots().listen((snap) {
      if (!mounted) return;
      for (var change in snap.docChanges) {
        if (change.type == DocumentChangeType.modified || change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            final stockVal = int.tryParse(data['remainingKg']?.toString() ?? data['totalKg']?.toString() ?? data['stock']?.toString() ?? '0') ?? 0;
            final lowThreshold = int.tryParse(data['lowStockThreshold']?.toString() ?? '10') ?? 10;

            if (stockVal <= lowThreshold) {
              _sendSystemNotification(
                title: "⚠️ Low Stock Alert",
                body: "⚠️ Paalala: Paubos na po ang supply ng '${data['name'] ?? data['productName'] ?? 'Bigas'}'.",
                channelId: NotificationService.channelAlerts,
              );
            }
          }
        }
      }
    }, onError: (err) => print("Inventory sub error: $err"));

    _ordersSub = FirebaseFirestore.instance.collection('orders').snapshots().listen((snap) {
      if (!mounted) return;
      for (var change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;
          _sendSystemNotification(
            title: "🛍️ Bagong Bili",
            body: "🛍️ May bagong bumibili! Order mula kay ${data['customerName'] ?? data['clientName'] ?? 'Customer'}.",
            channelId: NotificationService.channelOrders,
          );
        }
      }
    }, onError: (err) => print("Orders sub error: $err"));

    _weatherSub = FirebaseFirestore.instance.collection('weather_alerts').snapshots().listen((snap) {
      if (!mounted) return;
      for (var change in snap.docChanges) {
        final data = change.doc.data();
        if (data != null && (data['isTyphoonWarning'] ?? false)) {
          _sendSystemNotification(
            title: "🚨 BABALA SA BAGYO",
            body: "🚨 May paparating na bagyong ${data['typhoonName'] ?? 'Bagyo'}. Mag-ingat po sa sakahan!",
            channelId: NotificationService.channelTyphoonSOS,
          );
        }
      }
    }, onError: (err) => print("Weather sub error: $err"));
  }

  Future<void> _sendSystemNotification({
    required String title,
    required String body,
    required String channelId,
  }) async {
    try {
      NotificationService.showNotification(title: title, body: body, channelId: channelId);
    } catch (_) {
      // Pinipigilan ang pag-crash kapag kulang ang mobile local notification permission
    }
    
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': title,
        'body': body,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _inventorySub?.cancel();
    _ordersSub?.cancel();
    _weatherSub?.cancel();
    super.dispose();
  }

  List<_NavigationItem> get _navigationMenu {
    final list = [
      const _NavigationItem(Icons.grid_view_rounded, "Dashboard", null),
      const _NavigationItem(Icons.inventory_2_outlined, "Inventory", InventoryPage()),
      const _NavigationItem(Icons.shopping_bag_outlined, "Order/s", OrdersPage()),
      const _NavigationItem(Icons.menu_book_outlined, "Gabay sa Pagtatanim", GuidancePage()),
      const _NavigationItem(Icons.analytics_outlined, "Reports", ReportsPage()),
      const _NavigationItem(Icons.cloud_outlined, "Weather Updates", WeatherPage()),
    ];

    if (widget.userRole == 'admin') {
      list.add(const _NavigationItem(Icons.admin_panel_settings_outlined, "User Management", UserManagementPage()));
    }

    return list;
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
            drawer: !isDesktop ? _buildDrawer() : null,
            endDrawer: isDesktop ? _buildDrawer() : null,
            body: SafeArea(
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildDesktopSidebar(menuList, safeIndex),
                        Expanded(
                          child: Column(
                            children: [
                              _buildHeader(true),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 1440),
                                    child: activeBody,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildHeader(false),
                        Expanded(child: activeBody),
                        _buildUniversalNavBar(),
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
      constraints: BoxConstraints(minHeight: isDesktop ? 60 : 56),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 12,
        vertical: isDesktop ? 6 : 4,
      ),
      decoration: const BoxDecoration(
        color: _cardBg,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          if (!isDesktop)
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: _textMain),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
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
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: _textSub,
              size: 20,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminChatPage(),
                ),
              );
            },
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
            onTap: () {
              if (isDesktop) {
                _scaffoldKey.currentState?.openEndDrawer();
              } else {
                _scaffoldKey.currentState?.openDrawer();
              }
            },
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
    final horizontalPadding = isDesktop ? 24.0 : (isTablet ? 18.0 : 12.0);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: isDesktop ? 16 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Dashboard",
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textMain,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Araw-araw na Lagay ng Sakahan",
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textSub,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _primary.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: _primary, size: 8),
                    SizedBox(width: 4),
                    Text("LIVE", style: TextStyle(color: _primary, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 12),

          _buildGoogleStyleWeatherCard(),
          const SizedBox(height: 16),

          const Text("Buod ng Sakahan", style: TextStyle(color: _textMain, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 4 : (isTablet ? 3 : 2),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 130, // Tinitiyak na kasya ang teksto sa lahat ng mobile devices
            ),
            children: [
              // 1. INVENTORY MODULE
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('products').snapshots(),
                builder: (context, snapshot) {
                  double totalStockKg = 0;
                  bool hasLowStock = false;

                  if (snapshot.hasData) {
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (data['isDeleted'] == true) continue;

                      final double currentTotalKg =
                          ((data['remainingKg'] ?? data['totalKg'] ?? data['stock'] ?? 0.0) as num).toDouble();
                      final lowThreshold = double.tryParse(data['lowStockThreshold']?.toString() ?? '10') ?? 10.0;

                      totalStockKg += currentTotalKg;
                      if (currentTotalKg <= lowThreshold) hasLowStock = true;
                    }
                  }

                  return _buildInteractiveKpiCard(
                    categoryLabel: "Inventory",
                    title: "Bigas at Supply",
                    value: "${totalStockKg.toStringAsFixed(0)} kg",
                    subtitle: hasLowStock ? "⚠️ Paubos na!" : "Sapat ang supply",
                    icon: Icons.inventory_2_rounded,
                    color: Colors.blue,
                    hasAlert: hasLowStock,
                    alertText: "KULANG",
                    onTap: () => setState(() => _currentMenuIndex = 1),
                  );
                },
              ),

              // 2. ORDERS MODULE
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('orders').snapshots(),
                builder: (context, snapshot) {
                  int toPayCount = 0;

                  if (snapshot.hasData) {
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final rawStatus = (data['orderStatus'] ?? data['status'] ?? '').toString();
                      final parsedStatus = OrderStatus.parse(rawStatus);

                      if (parsedStatus == OrderStatus.toPay) {
                        toPayCount++;
                      }
                    }
                  }

                  return _buildInteractiveKpiCard(
                    categoryLabel: "Order/s",
                    title: "Bagong Bili",
                    value: "$toPayCount Order",
                    subtitle: toPayCount > 0 ? "Kailangan Bayaran" : "Walang nakatambak",
                    icon: Icons.shopping_bag_rounded,
                    color: Colors.orange,
                    hasAlert: toPayCount > 0,
                    alertText: "$toPayCount KILOS",
                    onTap: () => setState(() => _currentMenuIndex = 2),
                  );
                },
              ),

              // 3. GUIDANCE MODULE
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('crop_tracker')
                    .doc('active_crop')
                    .snapshots(),
                builder: (context, snapshot) {
                  String cropAgeText = "Walang Tanim";
                  String conditionText = "Pumili sa Gabay";
                  bool hasWarning = false;

                  final data = snapshot.data?.data();
                  final plantingTimestamp = data?['plantingDate'];

                  DateTime? plantingDate;
                  if (plantingTimestamp is Timestamp) {
                    plantingDate = plantingTimestamp.toDate();
                  } else if (plantingTimestamp is String) {
                    plantingDate = DateTime.tryParse(plantingTimestamp);
                  }

                  if (plantingDate != null) {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final pDate = DateTime(
                      plantingDate.year,
                      plantingDate.month,
                      plantingDate.day,
                    );

                    final calculatedDays = today.difference(pDate).inDays;
                    final days = calculatedDays < 0 ? 0 : calculatedDays;

                    if (days == 0) {
                      cropAgeText = "Araw 0";
                    } else if (days <= 15) {
                      cropAgeText = "Lumalaki (Day $days)";
                    } else if (days <= 60) {
                      cropAgeText = "Naglalaman (Day $days)";
                    } else {
                      cropAgeText = "Edad ng palay (Day $days)";
                    }

                    conditionText = "${pDate.month}/${pDate.day}/${pDate.year}";

                    if (data?['warning'] != null &&
                        data!['warning'].toString().isNotEmpty) {
                      conditionText = data['warning'].toString();
                      hasWarning = true;
                    }
                  }

                  return _buildInteractiveKpiCard(
                    categoryLabel: "Gabay",
                    title: "Kalagayan ng Tanim",
                    value: cropAgeText,
                    subtitle: conditionText,
                    icon: Icons.eco_rounded,
                    color: Colors.teal,
                    hasAlert: hasWarning,
                    alertText: "ALERTO",
                    onTap: () => setState(() => _currentMenuIndex = 3),
                  );
                },
              ),

              // 4. REPORTS MODULE
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('orders').snapshots(),
                builder: (context, snapshot) {
                  double totalCompletedRevenue = 0.0;

                  if (snapshot.hasData) {
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final rawStatus = (data['orderStatus'] ?? data['status'] ?? '').toString();
                      final parsedStatus = OrderStatus.parse(rawStatus);

                      if (parsedStatus == OrderStatus.completed) {
                        double orderTotal = double.tryParse(data['totalAmount']?.toString() ?? data['totalPrice']?.toString() ?? '0') ?? 0.0;

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
                    categoryLabel: "Reports",
                    title: "Total Revenue",
                    value: "₱${totalCompletedRevenue.toStringAsFixed(0)}",
                    subtitle: "Nakuha sa benta",
                    icon: Icons.analytics_rounded,
                    color: Colors.green,
                    hasAlert: false,
                    alertText: "",
                    onTap: () => setState(() => _currentMenuIndex = 4),
                  );
                },
              ),

              // 5. USER MANAGEMENT MODULE
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
                    categoryLabel: "User",
                    title: "Mga Account",
                    value: "$totalUsers Users",
                    subtitle: "Gamit ang System",
                    icon: Icons.people_alt_rounded,
                    color: Colors.indigo,
                    hasAlert: hasNewUser,
                    alertText: "BAGO",
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
      child: Container(
        padding: const EdgeInsets.all(10),
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
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(icon, size: 14, color: color),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          categoryLabel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasAlert)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      alertText,
                      style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: _textSub),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(color: _textMain, fontSize: 14, fontWeight: FontWeight.bold),
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
    );
  }

  Widget _buildGoogleStyleWeatherCard() {
    return FutureBuilder<WeatherEntity>(
      future: _weatherFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xff047857),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xff047857),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Walang koneksyon / hindi makuha ang lagay ng panahon",
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                  onPressed: _fetchLiveWeather,
                ),
              ],
            ),
          );
        }

        final weather = snapshot.data!;

        return InkWell(
          onTap: () => setState(() => _currentMenuIndex = 5),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
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
                  blurRadius: 8,
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
                        Icon(Icons.location_on_rounded, color: Colors.white70, size: 12),
                        SizedBox(width: 4),
                        Text("Capalangan, Pampanga", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                      child: const Text("PANAHON", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _getWeatherIcon(weather.condition),
                        const SizedBox(width: 8),
                        Text(
                          "${weather.temperature.toStringAsFixed(1)}°C",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(weather.condition, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        Text("Alinsangan: ${weather.humidity}%", style: const TextStyle(color: Colors.white70, fontSize: 9)),
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
  }

  Widget _getWeatherIcon(String condition) {
    final lower = condition.toLowerCase();
    if (lower.contains('rain')) return const Icon(Icons.grain_rounded, color: Color(0xff93C5FD), size: 26);
    if (lower.contains('cloud')) return const Icon(Icons.cloud_queue_rounded, color: Colors.white70, size: 26);
    return const Icon(Icons.wb_sunny_rounded, color: Color(0xffFDE047), size: 26);
  }

  Widget _buildDesktopSidebar(
    List<_NavigationItem> menuList,
    int safeIndex,
  ) {
    return Container(
      width: 248,
      decoration: const BoxDecoration(
        color: _cardBg,
        border: Border(
          right: BorderSide(color: _border),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    color: _primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "ArrozSistema",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _textMain,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: menuList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final item = menuList[index];
                final selected = safeIndex == index;

                return Material(
                  color: selected
                      ? _primary.withOpacity(0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (index == safeIndex) return;
                      setState(() => _currentMenuIndex = index);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            size: 20,
                            color: selected ? _primary : _textSub,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected ? _primary : _textMain,
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (selected)
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: _primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _performLogout,
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Logout",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUniversalNavBar() {
    final primaryItems = [
      {'index': 0, 'icon': Icons.grid_view_rounded, 'label': 'Dashboard'},
      {'index': 1, 'icon': Icons.inventory_2_outlined, 'label': 'Imbak'},
      {'index': 2, 'icon': Icons.shopping_bag_outlined, 'label': 'Benta'},
      {'index': 3, 'icon': Icons.menu_book_outlined, 'label': 'Gabay'},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: _cardBg,
        border: Border(top: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
                    Icon(item['icon'] as IconData, color: isSelected ? _primary : _textSub, size: 20),
                    const SizedBox(height: 2),
                    Text(
                      item['label'] as String,
                      style: TextStyle(
                        color: isSelected ? _primary : _textSub,
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
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
                  Icon(Icons.more_horiz_rounded, color: _currentMenuIndex >= 4 ? _primary : _textSub, size: 20),
                  const SizedBox(height: 2),
                  Text('Iba pa', style: TextStyle(color: _currentMenuIndex >= 4 ? _primary : _textSub, fontSize: 10)),
                ],
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 4, child: Text("Kikitain at Ulat")),
                const PopupMenuItem(value: 5, child: Text("Ulat ng Panahon")),
                if (widget.userRole == 'admin') const PopupMenuItem(value: 6, child: Text("Mga Tao sa System")),
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
              accountName: Text("Tagapamahala (Admin)", style: TextStyle(color: _textMain, fontWeight: FontWeight.bold)),
              accountEmail: Text("admin@arrozsistema.com", style: TextStyle(color: _textSub)),
              currentAccountPicture: CircleAvatar(backgroundColor: _primary, child: Icon(Icons.person, color: Colors.white)),
            ),
            ListTile(
              leading: const Icon(Icons.grid_view_rounded),
              title: const Text("Dashboard"),
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
              title: const Text("Order/s"),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentMenuIndex = 2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text("Gabay sa Pagtatanim"),
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
              title: const Text("Ulat ng Panahon"),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentMenuIndex = 5);
              },
            ),
            if (widget.userRole == 'admin')
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text("User/s"),
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