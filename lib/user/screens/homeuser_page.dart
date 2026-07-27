import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_page.dart';
import 'orders_page.dart';
import 'product_page.dart';
import 'profile_page.dart';

enum AppLanguage { tagalog, english }

class AppLocalizations {
  final AppLanguage language;
  AppLocalizations(this.language);

  String get home => language == AppLanguage.english ? "Home" : "Tahanan";
  String get products => language == AppLanguage.english ? "Products" : "Mga Produkto";
  String get cart => language == AppLanguage.english ? "Cart" : "Kariton";
  String get orders => language == AppLanguage.english ? "Orders" : "Mga Order";
  String get profile => language == AppLanguage.english ? "Profile" : "Profile";

  String get welcome => language == AppLanguage.english ? "Welcome back" : "Maligayang pagbabalik";
  String get specsTitle => language == AppLanguage.english ? "Product Specifications" : "Tungkol sa Ating Palay";
  String get specsDesc => language == AppLanguage.english
      ? "Our premium palay is directly sourced and harvested from the rich agricultural fields of Kapalangan, Pampanga."
      : "Ang ating de-kalidad na palay ay direktang nagmula at inani sa mayayamang sakahan ng Kapalangan, Pampanga.";

  String get bestSeller => language == AppLanguage.english ? "🔥 Best Sellers" : "🔥 Pinakamabenta";
  String get recommended => language == AppLanguage.english ? "👍 Recommended for You" : "👍 Rekomendado sa Iyo";
  String get viewAll => language == AppLanguage.english ? "See All" : "Tingnan Lahat";
  String get noItems => language == AppLanguage.english ? "No items posted yet" : "Wala pang naka-post";

  String get activeOrders => language == AppLanguage.english ? "Active Orders" : "Mga Aktibong Order";
  String get myCart => language == AppLanguage.english ? "My Cart" : "Aking Kariton";
  String get favorites => language == AppLanguage.english ? "Favorites" : "Mga Paborito";
  String get availableProducts => language == AppLanguage.english ? "Available Products" : "Mga Produktong Abot-kaya";

  String get notifTitle => language == AppLanguage.english ? "Notifications" : "Mga Abiso";
  String get noNotif => language == AppLanguage.english ? "No new updates right now." : "Walang bagong balita sa ngayon.";

  String get chatTitle => language == AppLanguage.english ? "Chat Support / Admin" : "Sulat sa Admin";
  String get chatHint => language == AppLanguage.english ? "Ask about your order or product..." : "Magtanong tungkol sa order o produkto...";
  String get send => language == AppLanguage.english ? "Send" : "Ipadala";

  String get orderNow => language == AppLanguage.english ? "Order Now" : "Bumili Na";
  String get actionDesc => language == AppLanguage.english
      ? "Ready to secure your high-recovery palay supply? Tap below to start browsing."
      : "Handa nang kumuha ng de-kalidad na supply ng palay? Pindutin sa ibaba para makapili.";
}

class HomeUserPage extends StatefulWidget {
  const HomeUserPage({super.key});

  @override
  State<HomeUserPage> createState() => _HomeUserPageState();
}

class _HomeUserPageState extends State<HomeUserPage> {
  int _currentIndex = 0;
  AppLanguage _currentLang = AppLanguage.tagalog;

  List<Widget> _buildPages() {
    return [
      _DashboardView(
        language: _currentLang,
        onLanguageToggle: () {
          setState(() {
            _currentLang = _currentLang == AppLanguage.tagalog ? AppLanguage.english : AppLanguage.tagalog;
          });
        },
        onNavigateToProducts: () => setState(() => _currentIndex = 1),
        onNavigateToCart: () => setState(() => _currentIndex = 2),
        onNavigateToOrders: () => setState(() => _currentIndex = 3),
      ),
      const ProductPage(),
      const CartPage(),
      const OrdersPage(),
      const ProfilePage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations(_currentLang);
    final currentPages = _buildPages();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: IndexedStack(
        index: _currentIndex,
        children: currentPages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        elevation: 3,
        backgroundColor: Colors.white,
        indicatorColor: Colors.green[100],
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: local.home),
          NavigationDestination(icon: const Icon(Icons.storefront_outlined), selectedIcon: const Icon(Icons.storefront), label: local.products),
          NavigationDestination(icon: const Icon(Icons.shopping_cart_outlined), selectedIcon: const Icon(Icons.shopping_cart), label: local.cart),
          NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), selectedIcon: const Icon(Icons.receipt_long), label: local.orders),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: local.profile),
        ],
      ),
    );
  }
}

class _DashboardView extends StatelessWidget {
  final AppLanguage language;
  final VoidCallback onLanguageToggle;
  final VoidCallback onNavigateToProducts;
  final VoidCallback onNavigateToCart;
  final VoidCallback onNavigateToOrders;

  const _DashboardView({
    required this.language,
    required this.onLanguageToggle,
    required this.onNavigateToProducts,
    required this.onNavigateToCart,
    required this.onNavigateToOrders,
  });

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return language == AppLanguage.english ? "Good Morning! 🌾" : "Magandang Umaga! 🌾";
    if (hour < 18) return language == AppLanguage.english ? "Good Afternoon! ☀️" : "Magandang Hapon! ☀️";
    return language == AppLanguage.english ? "Good Evening! 🌙" : "Magandang Gabi! 🌙";
  }

  // DIALOG / BOTTOM SHEET PARA SA CHAT SA ADMIN
  void _showAdminChatPanel(BuildContext context, AppLocalizations local, String userId) {
    final messageController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.green[100],
                      child: Icon(Icons.support_agent_rounded, color: Colors.green[800]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            local.chatTitle,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            language == AppLanguage.english ? "Active • Support Team" : "Aktibo • Suporta sa Mamimili",
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                const Divider(),

                // Chat Stream
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chats')
                        .doc(userId)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                language == AppLanguage.english
                                    ? "No messages yet. Send a message to Admin!"
                                    : "Wala pang mensahe. Mag-iwan ng tanong sa Admin!",
                                style: TextStyle(color: Colors.grey[500], fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        reverse: true,
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final msg = docs[index].data() as Map<String, dynamic>;
                          final bool isMe = msg['senderId'] == userId;

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.green[700] : Colors.grey[200],
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(14),
                                  topRight: const Radius.circular(14),
                                  bottomLeft: Radius.circular(isMe ? 14 : 0),
                                  bottomRight: Radius.circular(isMe ? 0 : 14),
                                ),
                              ),
                              child: Text(
                                msg['text'] ?? '',
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black87,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Input Bar
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: messageController,
                        decoration: InputDecoration(
                          hintText: local.chatHint,
                          hintStyle: const TextStyle(fontSize: 13),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green[700],
                      ),
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: () async {
                        final text = messageController.text.trim();
                        if (text.isEmpty) return;

                        messageController.clear();

                        // Save message to user's chat subcollection
                        final ref = FirebaseFirestore.instance
                            .collection('chats')
                            .doc(userId)
                            .collection('messages');

                        await ref.add({
                          'senderId': userId,
                          'text': text,
                          'timestamp': FieldValue.serverTimestamp(),
                        });

                        // Update metadata for Admin View
                        await FirebaseFirestore.instance.collection('chats').doc(userId).set({
                          'lastMessage': text,
                          'lastUpdated': FieldValue.serverTimestamp(),
                          'userId': userId,
                          'unreadByAdmin': true,
                        }, SetOptions(merge: true));
                      },
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

  void _showNotificationPanel(BuildContext context, AppLocalizations local, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(local.notifTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.done_all, color: Colors.green, size: 20),
                        tooltip: "I-mark lahat bilang nabasa",
                        onPressed: () async {
                          final batch = FirebaseFirestore.instance.batch();
                          final unread = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(userId)
                              .collection('notifications')
                              .where('isRead', isEqualTo: false)
                              .get();
                          for (var doc in unread.docs) {
                            batch.update(doc.reference, {'isRead': true});
                          }
                          await batch.commit();
                        },
                      )
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .collection('notifications')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return Center(
                            child: Text(local.noNotif, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                          );
                        }

                        return ListView.builder(
                          controller: scrollController,
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final notif = docs[index].data() as Map<String, dynamic>;
                            final bool isRead = notif['isRead'] ?? false;
                            final String type = notif['type'] ?? 'GENERAL';

                            IconData notifIcon = Icons.notifications;
                            Color iconColor = Colors.green;

                            if (type == 'ORDER_UPDATE') {
                              notifIcon = Icons.local_shipping;
                              iconColor = Colors.blue;
                            } else if (type == 'RESTOCK_ALERT') {
                              notifIcon = Icons.storefront;
                              iconColor = Colors.orange;
                            } else if (type == 'CART_NUDGE') {
                              notifIcon = Icons.shopping_cart;
                              iconColor = Colors.red;
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isRead ? Colors.transparent : Colors.green.shade50.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: iconColor.withOpacity(0.15),
                                  child: Icon(notifIcon, color: iconColor, size: 20),
                                ),
                                title: Text(
                                  notif['title'] ?? 'Notification',
                                  style: TextStyle(
                                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  notif['body'] ?? '',
                                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                                ),
                                onTap: () {
                                  docs[index].reference.update({'isRead': true});
                                  if (type == 'ORDER_UPDATE') {
                                    Navigator.pop(context);
                                    onNavigateToOrders();
                                  } else if (type == 'CART_NUDGE') {
                                    Navigator.pop(context);
                                    onNavigateToCart();
                                  } else if (type == 'RESTOCK_ALERT') {
                                    Navigator.pop(context);
                                    onNavigateToProducts();
                                  }
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showFavoritesPanel(BuildContext context, AppLocalizations local, String userId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(local.favorites, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(height: 24),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('favorites').where('userId', isEqualTo: userId).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(child: Text(local.noItems, style: TextStyle(color: Colors.grey[500])));
                    }
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final fav = docs[index].data() as Map<String, dynamic>;
                        return ListTile(
                          leading: const Icon(Icons.favorite, color: Colors.red),
                          title: Text(fav['productName'] ?? 'Palay Item'),
                          subtitle: Text("₱${fav['price'] ?? 0}"),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations(language);
    final currentUser = FirebaseAuth.instance.currentUser;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 125.0,
          floating: false,
          pinned: true,
          elevation: 0,
          scrolledUnderElevation: 2,
          backgroundColor: Colors.green[700],
          actions: [
            // LANGUAGE TOGGLE
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white.withOpacity(0.9)),
              onPressed: onLanguageToggle,
              icon: const Icon(Icons.translate, size: 16),
              label: Text(language == AppLanguage.tagalog ? "EN" : "TAG", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),

            // CHAT WITH ADMIN BUTTON (BAGONG DAGDAG)
            if (currentUser != null)
              IconButton(
                icon: const Icon(Icons.chat_outlined, color: Colors.white),
                tooltip: "Kausapin ang Admin",
                onPressed: () => _showAdminChatPanel(context, local, currentUser.uid),
              ),

            // NOTIFICATIONS BUTTON WITH BADGE
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: currentUser == null
                  ? const SizedBox.shrink()
                  : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .collection('notifications')
                    .where('isRead', isEqualTo: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  final unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return IconButton(
                    icon: Badge(
                      label: Text("$unreadCount", style: const TextStyle(fontSize: 10, color: Colors.white)),
                      backgroundColor: Colors.red,
                      isLabelVisible: unreadCount > 0,
                      child: const Icon(Icons.notifications_none_outlined, color: Colors.white),
                    ),
                    onPressed: () => _showNotificationPanel(context, local, currentUser.uid),
                  );
                },
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.green[700]!, Colors.green[900]!],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(right: 40, bottom: -30, child: Text("🌾", style: TextStyle(fontSize: 100, color: Colors.white.withOpacity(0.06)))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(_getTimeGreeting(), style: TextStyle(color: Colors.green[100], fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        StreamBuilder<DocumentSnapshot>(
                          stream: currentUser != null
                              ? FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots()
                              : const Stream.empty(),
                          builder: (context, snapshot) {
                            String name = language == AppLanguage.english ? "Buyer" : "Mamimili";
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final data = snapshot.data!.data() as Map<String, dynamic>;
                              name = data['firstName'] ?? data['name'] ?? name;
                            }
                            return Text(
                              "${local.welcome}, ${name.trim()}!",
                              style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: currentUser == null
                ? const SizedBox.shrink()
                : _DashboardCardGrid(
              userId: currentUser.uid,
              local: local,
              onOrdersTap: onNavigateToOrders,
              onCartTap: onNavigateToCart,
              onFavoritesTap: () => _showFavoritesPanel(context, local, currentUser.uid),
              onProductsTap: onNavigateToProducts,
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.gavel_outlined, color: Colors.green[700], size: 18),
                    const SizedBox(width: 8),
                    Text(local.specsTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(local.specsDesc, style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.green.withOpacity(0.2)),
              ),
              color: Colors.green[50]!.withOpacity(0.6),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            local.actionDesc,
                            style: TextStyle(fontSize: 12.5, color: Colors.grey[800], height: 1.4),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: onNavigateToProducts,
                            icon: const Icon(Icons.shopping_basket_outlined, size: 16),
                            label: Text(local.orderNow, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.eco_outlined, size: 54, color: Colors.green[300]),
                  ],
                ),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(child: _HorizontalProductSection(local: local, title: local.bestSeller, categoryFilter: 'best_seller', onSeeAll: onNavigateToProducts)),
        SliverToBoxAdapter(child: _HorizontalProductSection(local: local, title: local.recommended, categoryFilter: 'recommended', onSeeAll: onNavigateToProducts)),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class _DashboardCardGrid extends StatelessWidget {
  final String userId;
  final AppLocalizations local;
  final VoidCallback onOrdersTap;
  final VoidCallback onCartTap;
  final VoidCallback onFavoritesTap;
  final VoidCallback onProductsTap;

  const _DashboardCardGrid({
    required this.userId,
    required this.local,
    required this.onOrdersTap,
    required this.onCartTap,
    required this.onFavoritesTap,
    required this.onProductsTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.1,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildMetricCard(
          stream: FirebaseFirestore.instance.collection('orders').where('userId', isEqualTo: userId).snapshots(),
          label: local.activeOrders, icon: Icons.local_shipping_outlined, color: Colors.blue,
          onTap: onOrdersTap,
        ),
        _buildMetricCard(
          stream: FirebaseFirestore.instance.collection('cart').where('userId', isEqualTo: userId).snapshots(),
          label: local.myCart, icon: Icons.shopping_bag_outlined, color: Colors.orange,
          onTap: onCartTap,
        ),
        _buildMetricCard(
          stream: FirebaseFirestore.instance.collection('favorites').where('userId', isEqualTo: userId).snapshots(),
          label: local.favorites, icon: Icons.favorite_border, color: Colors.red,
          onTap: onFavoritesTap,
        ),
        _buildMetricCard(
          stream: FirebaseFirestore.instance.collection('products').where('stock', isGreaterThan: 0).snapshots(),
          label: local.availableProducts, icon: Icons.warehouse_outlined, color: Colors.green,
          onTap: onProductsTap,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required Stream<QuerySnapshot> stream,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.08), radius: 18, child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: stream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text("!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold));
                      }
                      final count = snapshot.hasData ? snapshot.data!.docs.length.toString() : "...";
                      return Text(count, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: -0.5));
                    },
                  ),
                  Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _HorizontalProductSection extends StatelessWidget {
  final AppLocalizations local;
  final String title;
  final String categoryFilter;
  final VoidCallback onSeeAll;

  const _HorizontalProductSection({
    required this.local,
    required this.title,
    required this.categoryFilter,
    required this.onSeeAll
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: -0.3)),
              TextButton(
                onPressed: onSeeAll,
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap
                ),
                child: Text(local.viewAll, style: TextStyle(color: Colors.green[700], fontSize: 13, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('products').where(categoryFilter, isEqualTo: true).limit(5).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green))
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(left: 20.0),
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(local.noItems, style: TextStyle(color: Colors.grey[400], fontSize: 12))
                  ),
                );
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final prod = docs[index].data() as Map<String, dynamic>;
                  return Container(
                    width: 130,
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 55,
                            width: double.infinity,
                            decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.grain, color: Colors.amber[800], size: 28),
                          ),
                          const Spacer(),
                          Text(
                              prod['name'] ?? 'Palay Bag',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis
                          ),
                          const SizedBox(height: 2),
                          Text(
                              "₱${prod['price'] ?? 0}",
                              style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold)
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}