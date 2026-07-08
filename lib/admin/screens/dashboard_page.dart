import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import para sa Authentication

import 'inventory_page.dart';
import 'login_page.dart'; // Siguraduhing tama ang import path ng iyong LoginPage
// import 'order_page.dart';     
// import 'reports_page.dart';   
// import 'weather_page.dart';   
// import 'guidance_page.dart';  

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentMenuIndex = 0;

  // Premium, Natural Color Palette
  static const Color _background = Color(0xffF8FAFC); 
  static const Color _surface = Color(0xffFFFFFF);
  static const Color _primary = Color(0xff16A34A); 
  static const Color _textPrimary = Color(0xff0F172A); 
  static const Color _textSecondary = Color(0xff475569); 
  static const Color _border = Color(0xffE2E8F0);

  List<_NavigationItem> get _navigationMenu {
    return [
      _NavigationItem(Icons.dashboard_rounded, "Dashboard", _buildMainDashboardContent()),
      const _NavigationItem(Icons.inventory_2_outlined, "Inventory", InventoryPage()),
      const _NavigationItem(Icons.shopping_cart_outlined, "Orders", Center(child: Text("Orders Page Placeholder"))),
      const _NavigationItem(Icons.bar_chart_rounded, "Reports", Center(child: Text("Reports Page Placeholder"))),
      const _NavigationItem(Icons.cloud_outlined, "Weather Forecast", Center(child: Text("Weather Page Placeholder"))),
      const _NavigationItem(Icons.library_books_outlined, "Guidance Hub", Center(child: Text("Guidance Page Placeholder"))),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1000;

        return Scaffold(
          backgroundColor: _background,
          bottomNavigationBar: !isDesktop ? _buildBottomNavBar() : null,
          body: Column(
            children: [
              _buildTopGlobalNavbar(isDesktop),
              Expanded(
                child: _navigationMenu[_currentMenuIndex].page ?? _buildMainDashboardContent(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainDashboardContent() {
    final isDesktop = MediaQuery.of(context).size.width >= 1000;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(),
          const SizedBox(height: 28),
          _buildMetricsRow(isDesktop),
          const SizedBox(height: 36),
          _buildSplitContentWorkspace(isDesktop),
        ],
      ),
    );
  }

  /// --- PREMIUM TOP NAVBAR (UPDATED WITH PROFILE DROPDOWN) ---
  Widget _buildTopGlobalNavbar(bool isDesktop) {
    return Container(
      height: 85,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 20),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border, width: 1.5)),
      ),
      child: Row(
        children: [
          // Branding
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.eco_rounded, color: _primary, size: 26),
              ),
              const SizedBox(width: 14),
              const Text(
                "ArrozSistema",
                style: TextStyle(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
            ],
          ),
          const SizedBox(width: 40),

          // Navigation Links (Desktop)
          if (isDesktop)
            Expanded(
              child: SizedBox(
                height: 85,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _navigationMenu.length,
                  itemBuilder: (context, index) {
                    final item = _navigationMenu[index];
                    final isSelected = _currentMenuIndex == index;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Container(
                        alignment: Alignment.center,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? _primary.withOpacity(0.08) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: InkWell(
                            onTap: () => setState(() => _currentMenuIndex = index),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  Icon(item.icon, color: isSelected ? _primary : _textSecondary, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                      color: isSelected ? _primary : _textSecondary,
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            )
          else
            const Spacer(),

          // Admin Control Actions
          Row(
            children: [
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, color: _textSecondary, size: 26),
                    onPressed: () {},
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                    ),
                  )
                ],
              ),
              const SizedBox(width: 16),
              Container(width: 1.5, height: 28, color: _border),
              const SizedBox(width: 16),
              
              // ==================== PROFILE DROPDOWN MENU ====================
              PopupMenuButton<String>(
                offset: const Offset(0, 55), // Ipoposisyon nang maayos sa ilalim ng navbar
                elevation: 4,
                shadowColor: const Color(0xff0F172A).withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: _border, width: 1.2),
                ),
                color: _surface,
                tooltip: "Profile Options",
                onSelected: (value) {
                  if (value == 'settings') {
                    _showChangePasswordDialog(); // Bubuksan ang custom modal dialog sa ibaba
                  } else if (value == 'logout') {
                    _handleLogout(); // Isasagawa ang Firebase sign out pipeline
                  }
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _primary.withOpacity(0.2), width: 1.5),
                    ),
                    child: const CircleAvatar(
                      radius: 18,
                      backgroundColor: _border,
                      child: Icon(Icons.person, color: _textSecondary, size: 20),
                    ),
                  ),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'settings',
                    height: 44,
                    child: Row(
                      children: const [
                        Icon(Icons.settings_outlined, color: _textSecondary, size: 18),
                        SizedBox(width: 12),
                        Text(
                          "Settings",
                          style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(height: 1),
                  PopupMenuItem<String>(
                    value: 'logout',
                    height: 44,
                    child: Row(
                      children: const [
                        Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                        SizedBox(width: 12),
                        Text(
                          "Log out",
                          style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // ===============================================================
            ],
          ),
        ],
      ),
    );
  }

  /// --- LOGOUT LOGIC PIPELINE ---
  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    
    // I-clear ang stack at bumalik nang malinis sa LoginPage
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  /// --- CHANGE PASSWORD MODERN MODAL DIALOG ---
  void _showChangePasswordDialog() {
    final passwordController = TextEditingController();
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: _surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                "Account Settings", 
                style: TextStyle(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.w900)
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Update Password", 
                    style: TextStyle(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.w600)
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: "New Password",
                      labelStyle: const TextStyle(color: _textSecondary, fontSize: 13),
                      floatingLabelStyle: const TextStyle(color: _primary, fontWeight: FontWeight.w700),
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _border, width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _primary, width: 1.8),
                      ),
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
              actions: [
                TextButton(
                  onPressed: isUpdating ? null : () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: _textSecondary, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: isUpdating 
                      ? null 
                      : () async {
                          final newPassword = passwordController.text.trim();
                          if (newPassword.isEmpty || newPassword.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Password must be at least 6 characters.")),
                            );
                            return;
                          }

                          setModalState(() => isUpdating = true);
                          try {
                            // Firebase logic para mag-update ng password ng kasalukuyang user
                            await FirebaseAuth.instance.currentUser?.updatePassword(newPassword);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Password updated successfully!")),
                              );
                            }
                          } on FirebaseAuthException catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.message ?? "Failed to update password.")),
                              );
                            }
                          } finally {
                            setModalState(() => isUpdating = false);
                          }
                        },
                  child: isUpdating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// --- RESPONSIVE BOTTOM BAR ---
  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border, width: 1.5)),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentMenuIndex,
        selectedItemColor: _primary,
        unselectedItemColor: _textSecondary,
        type: BottomNavigationBarType.fixed,
        backgroundColor: _surface,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        onTap: (index) => setState(() => _currentMenuIndex = index),
        items: _navigationMenu.take(4).map((item) {
          return BottomNavigationBarItem(
            icon: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Icon(item.icon, size: 24),
            ),
            label: item.title,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          "Welcome to Your Control Hub \u{1F44B}",
          style: TextStyle(color: _textPrimary, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        SizedBox(height: 6),
        Text(
          "Monitor yields, review active supply chains, and optimize your farm inventory performance seamlessly.",
          style: TextStyle(color: _textSecondary, fontSize: 14, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildMetricsRow(bool isDesktop) {
    final contents = [
      Expanded(
        flex: isDesktop ? 1 : 0,
        child: _buildMetricTile(
          icon: Icons.wb_sunny_rounded,
          iconColor: Colors.orange.shade700,
          bgColor: const Color(0xffFFF7ED),
          label: "ENVIRONMENT WEATHER REAL-TIME",
          value: "29°C — Mostly Sunny",
          contextualText: "Excellent climate conditions evaluated for open grain yard drying operations.",
        ),
      ),
      SizedBox(width: isDesktop ? 24 : 0, height: isDesktop ? 0 : 16),
      Expanded(
        flex: isDesktop ? 1 : 0,
        child: _buildMetricTile(
          icon: Icons.insights_rounded,
          iconColor: _primary,
          bgColor: const Color(0xffF0FDF4),
          label: "LIVE FARM MARKET RATE",
          value: "₱32.00 / kg",
          contextualText: "Calculated benchmark rate pulled directly from localized trading hubs.",
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
      padding: const EdgeInsets.all(24),
      decoration: _cardStyle(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: iconColor, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: _textSecondary.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Text(value, style: const TextStyle(color: _textPrimary, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(contextualText, style: const TextStyle(color: _textSecondary, fontSize: 13, height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSplitContentWorkspace(bool isDesktop) {
    final leftPane = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Quick Infrastructure Toolkit", style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isDesktop ? 2 : 1,
          crossAxisSpacing: 18,
          mainAxisSpacing: 18,
          childAspectRatio: isDesktop ? 2.0 : 2.6,
          children: [
            _buildActionCard(Icons.inventory_2_rounded, "Manage Inventory", "Review stock variances & active seed lines.", _primary, 1),
            _buildActionCard(Icons.shopping_cart_outlined, "Monitor Orders", "Check logistical pipelines & buyer cycles.", Colors.indigo.shade600, 2),
            _buildActionCard(Icons.bar_chart_rounded, "Business Analytics", "Generate reports, yield sheets, and audits.", Colors.blue.shade600, 3),
            _buildActionCard(Icons.menu_book_rounded, "Agronomic Advice", "Access farming standards & guidance keys.", Colors.teal.shade600, 5),
          ],
        ),
      ],
    );

    final rightPane = Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardStyle(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Live Telemetry Logs", style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Text("Live Syncing", style: TextStyle(color: _primary, fontSize: 11, fontWeight: FontWeight.w700)),
              )
            ],
          ),
          const SizedBox(height: 24),
          _buildActivityTile(Icons.add_box_outlined, _primary, "20 sacks of grain successfully moved to storage", "10m ago"),
          const Divider(height: 28, color: _border),
          _buildActivityTile(Icons.assignment_turned_in_rounded, Colors.indigo, "B2B wholesale shipping manifest confirmed", "1h ago"),
          const Divider(height: 28, color: _border),
          _buildActivityTile(Icons.error_outline_rounded, Colors.redAccent, "Low threshold warnings detected on Stock Line Alpha", "3h ago"),
        ],
      ),
    );

    return isDesktop
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: leftPane),
              const SizedBox(width: 28),
              Expanded(flex: 2, child: rightPane),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              leftPane,
              const SizedBox(height: 32),
              rightPane,
            ],
          );
  }

  Widget _buildActionCard(IconData icon, String title, String subtitle, Color color, int menuIndex) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _currentMenuIndex = menuIndex),
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: _cardStyle(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: _textSecondary, fontSize: 12, height: 1.3)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: _textSecondary.withOpacity(0.5), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTile(IconData icon, Color color, String title, String timestamp) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.08), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 14, height: 1.3)),
              const SizedBox(height: 4),
              Text(timestamp, style: TextStyle(color: _textSecondary.withOpacity(0.8), fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  static BoxDecoration _cardStyle() {
    return BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border, width: 1.2),
      boxShadow: [
        BoxShadow(
          color: const Color(0xff0F172A).withOpacity(0.02),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

class _NavigationItem {
  final IconData icon;
  final String title;
  final Widget? page;
  const _NavigationItem(this.icon, this.title, this.page);
}