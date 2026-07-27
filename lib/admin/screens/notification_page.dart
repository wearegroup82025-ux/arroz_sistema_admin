import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  String _activeTab = 'All';

  static const Color _background = Color(0xffF8FAFC);
  static const Color _surface = Color(0xffFFFFFF);
  static const Color _primary = Color(0xff16A34A);
  static const Color _textPrimary = Color(0xff0F172A);
  static const Color _textSecondary = Color(0xff475569);
  static const Color _border = Color(0xffE2E8F0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        iconTheme: const IconThemeData(color: _textPrimary),
        title: const Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: _primary, size: 22),
            SizedBox(width: 10),
            Text(
              "Notifications Hub",
              style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _markAllAsRead,
            icon: const Icon(Icons.done_all_rounded, size: 16, color: _primary),
            label: const Text(
              "Read All",
              style: TextStyle(color: _primary, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomFilterBar(),
            const Divider(height: 1, color: _border),
            Expanded(child: _buildNotificationsStream()),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomFilterBar() {
    final filters = ['All', 'Orders', 'Users', 'Stock', 'Weather'];

    return Container(
      color: _surface,
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _activeTab == filter;

          return InkWell(
            onTap: () => setState(() => _activeTab = filter),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? _primary : _background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? _primary : _border,
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : _textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 12,
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
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _primary));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final filteredDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final type = data['type'] ?? '';

          if (_activeTab == 'Orders') return type == 'order';
          if (_activeTab == 'Users') return type == 'user';
          if (_activeTab == 'Stock') return type == 'stock';
          if (_activeTab == 'Weather') return type == 'weather';
          return true;
        }).toList();

        if (filteredDocs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
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
    final title = data['title'] ?? 'Notification';
    final body = data['body'] ?? '';
    final type = data['type'] ?? 'general';
    final isRead = data['isRead'] ?? false;
    final Timestamp? timestamp = data['timestamp'];

    IconData icon;
    Color iconColor;
    Color iconBg;

    switch (type) {
      case 'order':
        icon = Icons.shopping_bag_rounded;
        iconColor = Colors.indigo;
        iconBg = const Color(0xffEEF2FF);
        break;
      case 'user':
        icon = Icons.person_add_alt_1_rounded;
        iconColor = Colors.teal;
        iconBg = const Color(0xffF0FDFA);
        break;
      case 'weather':
        icon = Icons.cloud_queue_rounded;
        iconColor = Colors.amber.shade800;
        iconBg = const Color(0xffFEF3C7);
        break;
      case 'stock':
        icon = Icons.warning_amber_rounded;
        iconColor = Colors.orange.shade800;
        iconBg = const Color(0xffFFF7ED);
        break;
      default:
        icon = Icons.notifications_none_rounded;
        iconColor = Colors.blue;
        iconBg = const Color(0xffEFF6FF);
    }

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRead ? _border : _primary.withOpacity(0.5),
          width: isRead ? 1.2 : 1.8,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () {
          FirebaseFirestore.instance.collection('notifications').doc(docId).update({'isRead': true});
        },
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: _textPrimary,
                  fontWeight: isRead ? FontWeight.w600 : FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: _primary, shape: BoxShape.circle),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                body,
                style: const TextStyle(color: _textSecondary, fontSize: 12, height: 1.3),
              ),
              const SizedBox(height: 6),
              Text(
                timestamp != null ? _formatDate(timestamp) : 'Just now',
                style: TextStyle(color: _textSecondary.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
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
          Icon(Icons.notifications_off_outlined, size: 40, color: _textSecondary.withOpacity(0.4)),
          const SizedBox(height: 12),
          const Text("Walang Notifications", style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
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

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return "$hour:${date.minute.toString().padLeft(2, '0')} $period • ${date.day}/${date.month}/${date.year}";
  }
}