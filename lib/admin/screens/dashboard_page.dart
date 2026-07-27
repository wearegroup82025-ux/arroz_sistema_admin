import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import 'system_control_hub.dart';
import 'inventory_page.dart';
import 'order_page.dart';
import 'reports_page.dart';
import 'weather_page.dart';
import 'guidance_page.dart';
import 'notification_page.dart'; // Isinama ang NotificationPage
import '../../notification_service.dart'; // Isinama ang NotificationService

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentMenuIndex = 0;
  late Timer _marketTimer;
  final Random _random = Random();
  double _liveMarketRate = 32.00;

  static const Color _background = Color(0xffF8FAFC);
  static const Color _surface = Color(0xffFFFFFF);
  static const Color _primary = Color(0xff16A34A);
  static const Color _textPrimary = Color(0xff0F172A);
  static const Color _textSecondary = Color(0xff475569);
  static const Color _border = Color(0xffE2E8F0);

  StreamSubscription? _logSubscription;

  @override
  void initState() {
    super.initState();
    _startMarketTicker();
    _listenToSystemLogs(); // Makikinig sa system logs para mag-notif sa CP
  }

  // Makikinig sa System Logs para mag-pop up at tumunog ang CP notification
  void _listenToSystemLogs() {
    _logSubscription = SystemControlHub().logsStream.listen((logs) {
      if (logs.isNotEmpty) {
        final latestLog = logs.first;
        
        // Tumawag sa Phone Notification Service
        NotificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: "ArrozSistema: ${latestLog.title}",
          body: "May bagong system log updates. I-check ang system hub.",
        );
      }
    });
  }

  @override
  void dispose() {
    _marketTimer.cancel();
    _logSubscription?.cancel();
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1000;

        final Widget activeBody = _currentMenuIndex == 0
            ? _buildMainDashboardContent(isDesktop)
            : (_navigationMenu[_currentMenuIndex].page ?? _buildMainDashboardContent(isDesktop));

        return Scaffold(
          backgroundColor: _background,
          drawer: !isDesktop ? _buildMobileDrawer() : null,
          bottomNavigationBar: !isDesktop ? _buildResponsiveBottomNavBar() : null,
          body: Column(
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
        );
      },
    );
  }

  // --- REST OF DASHBOARD CONTENT ---
  Widget _buildMainDashboardContent(bool isDesktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(),
          const SizedBox(height: 24),
          _buildMetricsRow(isDesktop),
          const SizedBox(height: 28),
          _buildSplitContentWorkspace(isDesktop),
        ],
      ),
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
                label: "ENVIRONMENT WEATHER REAL-TIME",
                value: snapshot.data ?? "Loading Weather...",
                contextualText: "Naka-sync sa weather module. I-click para sa kumpletong forecast.",
              ),
            );
          },
        ),
      ),
      SizedBox(width: isDesktop ? 24 : 0, height: isDesktop ? 0 : 16),
      Expanded(
        flex: isDesktop ? 1 : 0,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _buildMetricTile(
            key: ValueKey<double>(_liveMarketRate),
            icon: Icons.insights_rounded,
            iconColor: _primary,
            bgColor: const Color(0xffF0FDF4),
            label: "LIVE FARM MARKET RATE",
            value: "₱${_liveMarketRate.toStringAsFixed(2)} / kg",
            contextualText: "Calculated live benchmark rate pulled directly from localized trading hubs.",
          ),
        ),
      ),
    ];

    return isDesktop
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: contents)
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: contents);
  }

  Widget _buildSplitContentWorkspace(bool isDesktop) {
    final leftPane = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Quick Infrastructure Toolkit", style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = isDesktop ? 2 : (constraints.maxWidth > 600 ? 2 : 1);
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isDesktop ? 2.0 : 2.5,
              children: [
                _buildActionCard(Icons.inventory_2_rounded, "Manage Inventory", "Suriin ang mga kulang na stocks dito.", _primary, 1),
                _buildActionCard(Icons.shopping_cart_outlined, "Monitor Orders", "Tingnan ang lahat ng kasalukuyang orders.", Colors.indigo.shade600, 2),
                _buildActionCard(Icons.bar_chart_rounded, "Business Analytics", "Generate reports, yield sheets, and audits.", Colors.blue.shade600, 3),
                _buildActionCard(Icons.cloud_outlined, "Weather Forecast", "Mag-check ng lagay ng panahon.", Colors.amber.shade700, 4),
                _buildActionCard(Icons.menu_book_rounded, "Agronomic Advice", "Access farming standards & guidance keys.", Colors.teal.shade600, 5),
              ],
            );
          },
        ),
      ],
    );

    final rightPane = Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardStyle(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("System Scope Logs", style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  children: [
                    SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 1.5, color: _primary)),
                    SizedBox(width: 6),
                    Text("Live Syncing", style: TextStyle(color: _primary, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          StreamBuilder<List<LogEntry>>(
            stream: SystemControlHub().logsStream,
            initialData: SystemControlHub().currentLogs,
            builder: (context, snapshot) {
              final logs = snapshot.data ?? [];
              if (logs.isEmpty) {
                return const Text("No system logs detected yet.", style: TextStyle(color: _textSecondary, fontSize: 14));
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: logs.length,
                separatorBuilder: (context, index) => const Divider(height: 20, color: _border),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  IconData logIcon = Icons.info_outline_rounded;
                  Color logColor = _primary;

                  if (log.type == 'success') {
                    logIcon = Icons.check_circle_outline_rounded;
                    logColor = Colors.indigo;
                  } else if (log.type == 'warning') {
                    logIcon = Icons.warning_amber_rounded;
                    logColor = Colors.redAccent;
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: logColor.withValues(alpha: 0.08), shape: BoxShape.circle),
                        child: Icon(logIcon, color: logColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(log.title, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 13, height: 1.3)),
                            const SizedBox(height: 2),
                            Text(log.time, style: TextStyle(color: _textSecondary.withValues(alpha: 0.7), fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );

    return isDesktop
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: leftPane),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: rightPane),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              leftPane,
              const SizedBox(height: 28),
              rightPane,
            ],
          );
  }

  Widget _buildHeaderSection() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Welcome to Your Control Hub 👋", style: TextStyle(color: _textPrimary, fontSize: 24, fontWeight: FontWeight.w900)),
        SizedBox(height: 4),
        Text("Monitor yields, review active supply chains, and optimize your farm performance.", style: TextStyle(color: _textSecondary, fontSize: 13)),
      ],
    );
  }

  Widget _buildMetricTile({Key? key, required IconData icon, required Color iconColor, required Color bgColor, required String label, required String value, required String contextualText}) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(20),
      decoration: _cardStyle(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: _textSecondary.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(contextualText, style: const TextStyle(color: _textSecondary, fontSize: 12, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(IconData icon, String title, String subtitle, Color color, int menuIndex) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _navigateToPage(menuIndex),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardStyle(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _textSecondary, fontSize: 11, height: 1.2)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: _textSecondary.withValues(alpha: 0.4), size: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildTopGlobalNavbar(bool isDesktop) {
    return Container(
      height: 70,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16),
      decoration: const BoxDecoration(color: _surface, border: Border(bottom: BorderSide(color: _border, width: 1.5))),
      child: Row(
        children: [
          if (!isDesktop)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded, color: _textPrimary),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          InkWell(
            onTap: () => _navigateToPage(0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.eco_rounded, color: _primary, size: 22),
                ),
                const SizedBox(width: 10),
                const Text("ArrozSistema", style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(width: 24),
          if (isDesktop)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_navigationMenu.length, (index) {
                    final isSelected = _currentMenuIndex == index;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isSelected ? _primary.withValues(alpha: 0.08) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: InkWell(
                          onTap: () => _navigateToPage(index),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              children: [
                                Icon(_navigationMenu[index].icon, color: isSelected ? _primary : _textSecondary, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  _navigationMenu[index].title,
                                  style: TextStyle(
                                    color: isSelected ? _primary : _textSecondary,
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            )
          else
            const Spacer(),
          Row(
            children: [
              // BINAGONG NOTIFICATION BUTTON: Mapupunta sa NotificationPage at Pwede ring Mag-test Notification
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: _textSecondary),
                onPressed: () {
                  // Mag-trigger ng Test Notification para marinig na tumutunog sa CP
                  NotificationService.showNotification(
                    id: 1,
                    title: "⚠️ Low Stock Alert!",
                    body: "Ang iyong Rice stock ay mababa na sa 10 sacks.",
                  );

                  // Mag-navigate patungong Notification Page
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationPage()),
                  );
                },
              ),
              const SizedBox(width: 8),
              const CircleAvatar(radius: 15, backgroundColor: _border, child: Icon(Icons.person, size: 16, color: _textSecondary)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildResponsiveBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border, width: 1)),
      ),
      height: 65,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _navigationMenu.length,
        itemBuilder: (context, index) {
          final isSelected = _currentMenuIndex == index;
          final item = _navigationMenu[index];
          return InkWell(
            onTap: () => _navigateToPage(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, color: isSelected ? _primary : _textSecondary, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    style: TextStyle(
                      color: isSelected ? _primary : _textSecondary,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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

  Widget _buildMobileDrawer() {
    return Drawer(
      backgroundColor: _surface,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: _background),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.eco_rounded, color: _primary, size: 28),
                ),
                const SizedBox(width: 14),
                const Text("ArrozSistema", style: TextStyle(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _navigationMenu.length,
              itemBuilder: (context, index) {
                final isSelected = _currentMenuIndex == index;
                final item = _navigationMenu[index];
                return ListTile(
                  leading: Icon(item.icon, color: isSelected ? _primary : _textSecondary),
                  title: Text(
                    item.title,
                    style: TextStyle(
                      color: isSelected ? _primary : _textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: _primary.withValues(alpha: 0.08),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToPage(index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static BoxDecoration _cardStyle() {
    return BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border, width: 1.2));
  }
}

class _NavigationItem {
  final IconData icon;
  final String title;
  final Widget? page;
  const _NavigationItem(this.icon, this.title, this.page);
}