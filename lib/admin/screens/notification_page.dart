import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  String _activeTab = 'All';

  static const Color _bgSlate = Color(0xffF8FAFC);
  static const Color _cardWhite = Color(0xffFFFFFF);
  static const Color _brandPrimary = Color(0xff059669);
  static const Color _textDark = Color(0xff0F172A);
  static const Color _textMuted = Color(0xff64748B);
  static const Color _borderSubtle = Color(0xffE2E8F0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgSlate,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: _cardWhite,
        iconTheme: const IconThemeData(color: _textDark),
        centerTitle: false,
        title: const Text(
          "Notifications Hub",
          style: TextStyle(
            color: _textDark,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _markAllAsRead,
            icon: const Icon(Icons.done_all_rounded, size: 18, color: _brandPrimary),
            label: const Text(
              "Mark all read",
              style: TextStyle(color: _brandPrimary, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomFilterBar(),
            const Divider(height: 1, color: _borderSubtle),
            Expanded(child: _buildNotificationsStream()),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomFilterBar() {
    final filters = ['All', 'Weather', 'Orders', 'Users', 'Stock'];

    return Container(
      color: _cardWhite,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _activeTab == filter;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            child: InkWell(
              onTap: () => setState(() => _activeTab = filter),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? _brandPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? _brandPrimary : _borderSubtle,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    filter,
                    style: TextStyle(
                      color: isSelected ? Colors.white : _textMuted,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationsStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('notifications').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _brandPrimary, strokeWidth: 2.5),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Error loading notifications: ${snapshot.error}",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w500),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final allDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final recipient = data['recipientType'] ?? '';
          return recipient != 'customer';
        }).toList();

        allDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final Timestamp? aTime = aData['timestamp'];
          final Timestamp? bTime = bData['timestamp'];
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        final weatherKeywords = [
          'weather', 'rain', 'typhoon', 'bagyo', 'habagat', 'amihan', 'monsoon',
          'hightide', 'lowtide', 'tide', 'flood', 'baha', 'dam', 'spillway',
          'landslide', 'storm', 'thunderstorm', 'lightning', 'cyclone', 'tsunami',
          'stormsurge', 'heatindex', 'heatwave', 'drought', 'elprino', 'lanina',
          'wind', 'gale', 'volcano', 'ashfall', 'earthquake', 'fog', 'cloud',
          'humidity', 'uv', 'airquality'
        ];

        final filteredDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final type = (data['type'] ?? '').toString().toLowerCase().trim();
          final subCategory = (data['subCategory'] ?? '').toString().toLowerCase().trim();

          final isWeatherType = weatherKeywords.contains(type) || weatherKeywords.contains(subCategory);

          if (_activeTab == 'All') {
            final validTypes = ['order', 'orders', 'user', 'users', 'stock', 'stocks'];
            return validTypes.contains(type) || isWeatherType;
          }

          if (_activeTab == 'Weather') return isWeatherType;
          if (_activeTab == 'Orders') return type == 'order' || type == 'orders';
          if (_activeTab == 'Users') return type == 'user' || type == 'users';
          if (_activeTab == 'Stock') return type == 'stock' || type == 'stocks';

          return false;
        }).toList();

        if (filteredDocs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildNotificationCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildNotificationCard(String docId, Map<String, dynamic> data) {
    final title = data['title'] ?? 'System Notification';
    final body = data['body'] ?? '';
    final type = (data['type'] ?? 'general').toString().toLowerCase().trim();
    final subCategory = (data['subCategory'] ?? '').toString().toLowerCase().trim();
    final severity = (data['severity'] ?? 'info').toString().toLowerCase().trim();
    final isRead = data['isRead'] ?? false;
    final Timestamp? timestamp = data['timestamp'];

    IconData icon;
    Color iconColor;
    Color iconBg;

    final weatherKeywords = [
      'weather', 'rain', 'typhoon', 'bagyo', 'habagat', 'amihan', 'monsoon',
      'hightide', 'lowtide', 'tide', 'flood', 'baha', 'dam', 'spillway',
      'landslide', 'storm', 'thunderstorm', 'lightning', 'cyclone', 'tsunami',
      'stormsurge', 'heatindex', 'heatwave', 'drought', 'elprino', 'lanina',
      'wind', 'gale', 'volcano', 'ashfall', 'earthquake', 'fog', 'cloud',
      'humidity', 'uv', 'airquality'
    ];

    if (weatherKeywords.contains(type) || weatherKeywords.contains(subCategory)) {
      if (subCategory == 'rain' || subCategory == 'flood' || subCategory == 'storm') {
        icon = Icons.grain_rounded;
        iconColor = const Color(0xff0284C7);
        iconBg = const Color(0xffE0F2FE);
      } else if (subCategory == 'heatindex' || subCategory == 'heatwave') {
        icon = Icons.wb_sunny_rounded;
        iconColor = const Color(0xffEA580C);
        iconBg = const Color(0xffFFF7ED);
      } else {
        icon = Icons.cloud_outlined;
        iconColor = severity == 'warning' || severity == 'critical'
            ? const Color(0xffD97706)
            : const Color(0xff059669);
        iconBg = severity == 'warning' || severity == 'critical'
            ? const Color(0xffFFFBEB)
            : const Color(0xffECFDF5);
      }
    } else {
      switch (type) {
        case 'order':
        case 'orders':
          icon = Icons.shopping_cart_rounded;
          iconColor = const Color(0xff2563EB);
          iconBg = const Color(0xffEFF6FF);
          break;
        case 'user':
        case 'users':
          icon = Icons.person_add_rounded;
          iconColor = const Color(0xff0D9488);
          iconBg = const Color(0xffF0FDFA);
          break;
        case 'stock':
        case 'stocks':
          icon = Icons.inventory_2_rounded;
          iconColor = const Color(0xffEA580C);
          iconBg = const Color(0xffFFF7ED);
          break;
        default:
          icon = Icons.notifications_rounded;
          iconColor = const Color(0xff4F46E5);
          iconBg = const Color(0xffEEF2FF);
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (!isRead) {
            FirebaseFirestore.instance.collection('notifications').doc(docId).update({'isRead': true});
          }
          if (weatherKeywords.contains(type) || weatherKeywords.contains(subCategory)) {
            Navigator.pushNamed(context, '/weather');
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: _cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRead ? _borderSubtle : _brandPrimary.withOpacity(0.4),
              width: isRead ? 1 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: _textDark,
                                fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: _brandPrimary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: const TextStyle(
                          color: _textMuted,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        timestamp != null ? _formatExactTime(timestamp) : 'Just now',
                        style: TextStyle(
                          color: _textMuted.withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xffF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_off_outlined, size: 32, color: _textMuted),
          ),
          const SizedBox(height: 12),
          const Text(
            "No notifications found",
            style: TextStyle(color: _textDark, fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),
          const Text(
            "New activity and weather alerts will appear here.",
            style: TextStyle(color: _textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _markAllAsRead() async {
    final batch = FirebaseFirestore.instance.batch();
    final snapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  String _formatExactTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }

    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');

    return "$hour:$minute $period • ${date.day}/${date.month}/${date.year}";
  }
}