import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_conversation_page.dart';

class AdminMessagesPage extends StatelessWidget {
  const AdminMessagesPage({super.key});

  static const Color _green = Color(0xff2E7D32);
  static const Color _background = Color(0xffF5F6F7);
  static const Color _text = Color(0xff050505);
  static const Color _subText = Color(0xff65676B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: const Text(
          'Messages',
          style: TextStyle(
            color: _text,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        // Tinanggal na ang actions na may lapis (edit_outlined)
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .orderBy('lastUpdated', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: _subText),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _green),
            );
          }

          final chats = snapshot.data?.docs ?? [];

          if (chats.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 54,
                    color: _subText,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No messages yet',
                    style: TextStyle(
                      color: _text,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 20),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final data = chat.data() as Map<String, dynamic>;

              final userId = chat.id;
              final lastMessage = data['lastMessage'] ?? '';
              final unread = data['unreadByAdmin'] == true;
              final lastUpdated = data['lastUpdated'] as Timestamp?;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .get(),
                builder: (context, userSnapshot) {
                  String customerName = data['userName'] ?? '';

                  if (customerName.isEmpty &&
                      userSnapshot.hasData &&
                      userSnapshot.data!.exists) {
                    final user =
                        userSnapshot.data!.data() as Map<String, dynamic>;

                    customerName =
                        '${user['firstName'] ?? user['name'] ?? ''} '
                                '${user['lastName'] ?? ''}'
                            .trim();
                  }

                  if (customerName.isEmpty) {
                    customerName = 'Customer';
                  }

                  final initial = customerName[0].toUpperCase();

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminConversationPage(
                            userId: userId,
                            userName: customerName,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      child: Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 29,
                                backgroundColor:
                                    _green.withOpacity(.12),
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    color: _green,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (!unread)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 15,
                                    height: 15,
                                    decoration: BoxDecoration(
                                      color: const Color(0xff31A24C),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        customerName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _text,
                                          fontSize: 16,
                                          fontWeight: unread
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (lastUpdated != null)
                                      Text(
                                        _formatDate(lastUpdated),
                                        style: TextStyle(
                                          color: unread
                                              ? _green
                                              : _subText,
                                          fontSize: 12,
                                          fontWeight: unread
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        lastMessage.isEmpty
                                            ? 'Start a conversation'
                                            : lastMessage,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: unread ? _text : _subText,
                                          fontSize: 14,
                                          fontWeight: unread
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    if (unread) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 9,
                                        height: 9,
                                        decoration: const BoxDecoration(
                                          color: _green,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  static String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays == 0) return '${difference.inHours}h';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d';

    return '${date.month}/${date.day}/${date.year}';
  }
}