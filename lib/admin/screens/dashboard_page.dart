import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'system_control_hub.dart';
import 'inventory_page.dart';
import 'order_page.dart';
import 'reports_page.dart';
import 'weather_page.dart';
import 'guidance_page.dart';
import 'notification_page.dart';
import '../../notification_service.dart';

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
  late Timer _marketTimer;
  Timer? _inactivityTimer;
  final Random _random = Random();
  double _liveMarketRate = 32.00;

  static const int _adminTimeoutSeconds = 15 * 60; // 15 mins inactivity timeout

  static const Color _background = Color(0xffF8FAFC);
  static const Color _surface = Color(0xffFFFFFF);
  static const Color _primary = Color(0xff16A34A);
  static const Color _textPrimary = Color(0xff0F172A);
  static const Color _textSecondary = Color(0xff475569);
  static const Color _border = Color(0xffE2E8F0);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Messaging State Data
  final List<Map<String, String>> _messages = [
    {"sender": "System Support", "text": "Welcome to ArrozSistema! Let us know if you need help.", "time": "10:00 AM", "isMe": "false"},
    {"sender": "Farm Supervisor", "text": "Mababa na po ang stock natin sa Warehouse B.", "time": "10:15 AM", "isMe": "false"},
  ];
  final TextEditingController _messageController = TextEditingController();
  int _unreadMessagesCount = 2;

  // Realtime Subscriptions
  StreamSubscription? _logSubscription;
  StreamSubscription? _inventorySubscription;
  StreamSubscription? _ordersSubscription;
  StreamSubscription? _usersSubscription;
  StreamSubscription? _weatherSubscription;

  @override
  void initState() {
    super.initState();
    _startMarketTicker();
    _listenToSystemLogs();
    _resetInactivityTimer();
    _initAllRealtimeListeners();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (widget.userRole == 'admin') {
      _inactivityTimer = Timer(const Duration(seconds: _adminTimeoutSeconds), () {
        _handleAutoLogout();
      });
    }
  }

  void _handleAutoLogout() {
    if (!mounted) return;
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
      const SnackBar(content: Text("Naka-logout na ang Admin session.")),
    );
  }

  void _initAllRealtimeListeners() {
    // Inventory Alerts
    _inventorySubscription = FirebaseFirestore.instance
        .collection('inventory')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified || change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null && (data['stock'] ?? 0) <= 10) {
            _triggerAlert(
              title: "⚠️ Low Stock Alert!",
              body: "Mababa na ang stock ng '${data['name'] ?? 'Rice'}'. (${data['stock']} sacks nalang).",
              type: "stock",
              channelId: NotificationService.channelAlerts,
            );
          }
        }
      }
    });

    // Orders Listener
    _ordersSubscription = FirebaseFirestore.instance
        .collection('orders')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          final clientName = data['clientName'] ?? 'Unknown Customer';
          final items = data['orderItems'] ?? 'Rice Sacks';
          final total = data['totalAmount'] ?? '0.00';
          final orderId = change.doc.id.length >= 6 ? change.doc.id.substring(0, 6).toUpperCase() : change.doc.id;

          _triggerAlert(
            title: "🛍️ Bagong Order mula kay $clientName!",
            body: "Order #$orderId: $items | Total: ₱$total.",
            type: "order",
            channelId: NotificationService.channelOrders,
          );
        }
      }
    });

    // User Registrations
    _usersSubscription = FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          final name = data['fullName'] ?? data['email'] ?? 'Bagong User';
          final role = data['role'] ?? 'Client';

          _triggerAlert(
            title: "👤 Bagong User Account!",
            body: "Gumawa ng bagong account si $name ($role).",
            type: "user",
            channelId: NotificationService.channelUsers,
          );
        }
      }
    });

    // Weather & Emergency SOS
    _weatherSubscription = FirebaseFirestore.instance
        .collection('weather_alerts')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;

        final isTyphoon = data['isTyphoonWarning'] ?? false;
        final typhoonName = data['typhoonName'] ?? 'Bagyo';
        final forecastTomorrow = data['forecastTomorrow'] ?? 'Cagayan Valley Area';

        if (isTyphoon) {
          int sosId = 999111;
          NotificationService.showNotification(
            id: sosId,
            title: "🚨 SOS EMERGENCY: PAPARATING NA BAGYO ($typhoonName)",
            body: "BABALA: May malakas na bagyong papasok sa sakahan ($forecastTomorrow). Aksyunan agad!",
            channelId: NotificationService.channelTyphoonSOS,
            isOngoing: true,
          );
          _showTyphoonEmergencyDialog(typhoonName, forecastTomorrow, sosId);
        } else {
          _triggerAlert(
            title: "🌤️ Weather Forecast para Bukas",
            body: "Inaasahang panahon bukas: $forecastTomorrow.",
            type: "weather",
            channelId: NotificationService.channelWeather,
          );
        }
      }
    });
  }

  void _showTyphoonEmergencyDialog(String typhoonName, String details, int notificationId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xffFEF2F2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
              SizedBox(width: 10),
              Text("MMDRMC SOS ALARM", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("MAY PAPARATING NA BAGYO: $typhoonName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text("Forecast Details: $details"),
              const SizedBox(height: 12),
              const Text(
                "⚠️ Ang wang-wang alert ay titigil lamang kapag pinindot mo ang button sa ibaba.",
                style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text("KUMPIRMAHIN AT PATAYIN ANG ALARM"),
              onPressed: () {
                NotificationService.dismissNotification(notificationId);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _triggerAlert({
    required String title,
    required String body,
    required String type,
    required String channelId,
  }) async {
    NotificationService.showNotification(
      title: title,
      body: body,
      channelId: channelId,
    );

    await FirebaseFirestore.instance.collection('notifications').add({
      'title': title,
      'body': body,
      'type': type,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _listenToSystemLogs() {
    _logSubscription = SystemControlHub().logsStream.listen((logs) {
      if (logs.isNotEmpty) {
        final latestLog = logs.first;
        NotificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: "ArrozSistema: ${latestLog.title}",
          body: "May bagong system log updates.",
        );
      }
    });
  }

  @override
  void dispose() {
    _marketTimer.cancel();
    _inactivityTimer?.cancel();
    _logSubscription?.cancel();
    _inventorySubscription?.cancel();
    _ordersSubscription?.cancel();
    _usersSubscription?.cancel();
    _weatherSubscription?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  void _startMarketTicker() {
    _marketTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          double change = (_random.nextDouble() * 0.8) - 0.40;
          _liveMarketRate = max(28.00, min(40.00, _liveMarketRate + change));
        });
      }
    });
  }

  void _navigateToPage(int index) {
    setState(() {
      _currentMenuIndex = index;
    });
  }

  List<_NavigationItem> get _navigationMenu {
    return [
      const _NavigationItem(Icons.dashboard_rounded, "Dashboard", null),
      const _NavigationItem(Icons.inventory_2_outlined, "Inventory", InventoryPage()),
      const _NavigationItem(Icons.shopping_cart_outlined, "Orders", OrdersPage()),
      const _NavigationItem(Icons.bar_chart_rounded, "Reports", ReportsPage()),
      const _NavigationItem(Icons.cloud_outlined, "Weather", WeatherPage()),
      const _NavigationItem(Icons.library_books_outlined, "Guidance Hub", GuidancePage()),
    ];
  }

  void _openMessagesModal() {
    setState(() {
      _unreadMessagesCount = 0;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: _surface,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            void sendMessage() {
              if (_messageController.text.trim().isEmpty) return;
              
              final now = TimeOfDay.now();
              final timeString = "${now.hourOfPeriod}:${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}";

              setState(() {
                _messages.add({
                  "sender": "Admin",
                  "text": _messageController.text.trim(),
                  "time": timeString,
                  "isMe": "true"
                });
              });

              setModalState(() {
                _messageController.clear();
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.65,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, color: _primary),
                            SizedBox(width: 8),
                            Text("System Messages", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                    const Divider(color: _border),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg["isMe"] == "true";

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
                                  if (!isMe)
                                    Text(msg["sender"]!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                  Text(
                                    msg["text"]!,
                                    style: TextStyle(color: isMe ? Colors.white : _textPrimary, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    msg["time"]!,
                                    style: TextStyle(color: isMe ? Colors.white70 : _textSecondary, fontSize: 9),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: InputDecoration(
                                hintText: "Type a message...",
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: _border),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.send_rounded, color: _primary),
                            onPressed: sendMessage,
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _resetInactivityTimer(),
      onPointerMove: (_) => _resetInactivityTimer(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1000;

          final Widget activeBody = _currentMenuIndex == 0
              ? _buildMainDashboardContent(isDesktop)
              : (_navigationMenu[_currentMenuIndex].page ?? _buildMainDashboardContent(isDesktop));

          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: _background,
            endDrawer: _buildProfileDrawer(),
            bottomNavigationBar: !isDesktop ? _buildBottomNavigationBar() : null,
            body: SafeArea(
              child: Column(
                children: [
                  _buildTopGlobalNavbar(isDesktop),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: KeyedSubtree(
                        key: ValueKey<int>(_currentMenuIndex),
                        child: activeBody,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopGlobalNavbar(bool isDesktop) {
    return Container(
      height: 65,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border, width: 1.5)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => _navigateToPage(0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.eco_rounded, color: _primary, size: 22),
                ),
                const SizedBox(width: 10),
                const Text(
                  "ArrozSistema",
                  style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (isDesktop)
            Row(
              children: List.generate(_navigationMenu.length, (index) {
                final isSelected = _currentMenuIndex == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: TextButton(
                    onPressed: () => _navigateToPage(index),
                    style: TextButton.styleFrom(
                      backgroundColor: isSelected ? _primary.withOpacity(0.1) : Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _navigationMenu[index].title,
                      style: TextStyle(
                        color: isSelected ? _primary : _textSecondary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }),
            ),
          if (isDesktop) const SizedBox(width: 16),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: _textSecondary),
                onPressed: _openMessagesModal,
              ),
              if (_unreadMessagesCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$_unreadMessagesCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('isRead', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, color: _textSecondary),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotificationPage()),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: _primary,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _primary, width: 2),
              ),
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: _border,
                child: Icon(Icons.person, size: 18, color: _textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    int selectedIndex = _currentMenuIndex;
    if (_currentMenuIndex > 3) {
      selectedIndex = 4;
    }

    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border, width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          if (index == 4) {
            _showMoreMenuModal();
          } else {
            _navigateToPage(index);
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: _surface,
        selectedItemColor: _primary,
        unselectedItemColor: _textSecondary,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), label: 'Inventory'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_outlined), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.widgets_outlined), label: 'More'),
        ],
      ),
    );
  }

  void _showMoreMenuModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: _surface,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Other Modules",
                  style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.cloud_outlined, color: Colors.amber),
                  title: const Text("Weather Forecast", style: TextStyle(fontWeight: FontWeight.w600)),
                  selected: _currentMenuIndex == 4,
                  selectedTileColor: _primary.withOpacity(0.08),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToPage(4);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.library_books_outlined, color: Colors.teal),
                  title: const Text("Guidance Hub & Docs", style: TextStyle(fontWeight: FontWeight.w600)),
                  selected: _currentMenuIndex == 5,
                  selectedTileColor: _primary.withOpacity(0.08),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToPage(5);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileDrawer() {
    return Drawer(
      backgroundColor: _surface,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: _background,
                border: Border(bottom: BorderSide(color: _border)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: _primary,
                    child: Icon(Icons.person, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "System Admin",
                          style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.userRole.toUpperCase(),
                            style: const TextStyle(color: _primary, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  ListTile(
                    leading: const Icon(Icons.dashboard_outlined, color: _textSecondary),
                    title: const Text("Overview Dashboard", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToPage(0);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.library_books_outlined, color: Colors.teal),
                    title: const Text("Guidance Hub & Docs", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToPage(5);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined, color: _textSecondary),
                    title: const Text("System Alerts", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotificationPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(color: _border, height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.redAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text("Logout Session", style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(context);
                    _performLogout();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainDashboardContent(bool isDesktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(),
          const SizedBox(height: 20),
          _buildMetricsRow(isDesktop),
          const SizedBox(height: 24),
          _buildQuickAccessSection(isDesktop),
          const SizedBox(height: 24),
          _buildLogsSection(),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Control Hub Overview 👋",
          style: TextStyle(color: _textPrimary, fontSize: 22, fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 4),
        Text(
          "Real-time monitoring of operations, market rates, and supply chain analytics.",
          style: TextStyle(color: _textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildMetricsRow(bool isDesktop) {
    final contents = [
      Expanded(
        flex: isDesktop ? 1 : 0,
        child: StreamBuilder<String>(
          stream: SystemControlHub().weatherStream,
          initialData: SystemControlHub().currentWeather,
          builder: (context, snapshot) {
            return InkWell(
              onTap: () => _navigateToPage(4),
              borderRadius: BorderRadius.circular(16),
              child: _buildMetricTile(
                icon: Icons.cloud_queue_rounded,
                iconColor: Colors.blue.shade600,
                bgColor: const Color(0xffEFF6FF),
                label: "ENVIRONMENT WEATHER",
                value: snapshot.data ?? "Loading Weather...",
                contextualText: "Click for complete forecast",
              ),
            );
          },
        ),
      ),
      SizedBox(width: isDesktop ? 16 : 0, height: isDesktop ? 0 : 12),
      Expanded(
        flex: isDesktop ? 1 : 0,
        child: _buildMetricTile(
          icon: Icons.insights_rounded,
          iconColor: _primary,
          bgColor: const Color(0xffF0FDF4),
          label: "LIVE FARM MARKET RATE",
          value: "₱${_liveMarketRate.toStringAsFixed(2)} / kg",
          contextualText: "Updated live from market hubs",
        ),
      ),
    ];

    return isDesktop
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: contents)
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: contents);
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String value,
    required String contextualText,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardStyle(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: _textSecondary.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
                Text(contextualText, style: const TextStyle(color: _textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessSection(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("System Operations", style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isDesktop ? 4 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isDesktop ? 1.8 : 1.5,
          children: [
            _buildNavCard(Icons.inventory_2_rounded, "Inventory", "Stock & Supplies", _primary, 1),
            _buildNavCard(Icons.shopping_cart_outlined, "Orders", "Track Orders", Colors.indigo, 2),
            _buildNavCard(Icons.bar_chart_rounded, "Reports", "Audits & Metrics", Colors.blue.shade600, 3),
            _buildNavCard(Icons.library_books_outlined, "Guidance Hub", "Docs & Standards", Colors.teal.shade600, 5),
          ],
        ),
      ],
    );
  }

  Widget _buildNavCard(IconData icon, String title, String subtitle, Color color, int menuIndex) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _navigateToPage(menuIndex),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardStyle(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(color: _textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardStyle(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Live System Logs", style: TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Text("Syncing", style: TextStyle(color: _primary, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<LogEntry>>(
            stream: SystemControlHub().logsStream,
            initialData: SystemControlHub().currentLogs,
            builder: (context, snapshot) {
              final logs = snapshot.data ?? [];
              if (logs.isEmpty) {
                return const Text("No logs recorded.", style: TextStyle(color: _textSecondary, fontSize: 12));
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: min(3, logs.length),
                separatorBuilder: (context, index) => const Divider(height: 16, color: _border),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: _primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          log.title,
                          style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(log.time, style: const TextStyle(color: _textSecondary, fontSize: 10)),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  static BoxDecoration _cardStyle() {
    return BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border, width: 1.2),
    );
  }
}

class _NavigationItem {
  final IconData icon;
  final String title;
  final Widget? page;
  const _NavigationItem(this.icon, this.title, this.page);
}