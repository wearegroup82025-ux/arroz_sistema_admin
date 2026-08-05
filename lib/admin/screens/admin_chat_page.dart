import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_conversation_page.dart';

class AdminChatPage extends StatelessWidget {
  const AdminChatPage({super.key});

  // Enterprise Color Palette - Gamit ang eksaktong Green mula sa iyong image (#2A6F4A)
  static const Color _bg = Color(0xffF8FAFC);
  static const Color _headerGreen = Color(0xff2A6F4A);
  static const Color _cardBg = Color(0xffFFFFFF);
  static const Color _textMain = Color(0xff0F172A);
  static const Color _textSub = Color(0xff64748B);
  static const Color _border = Color(0xffE2E8F0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _headerGreen,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Customer Messages",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                "Error loading chats: ${snapshot.error}",
                style: const TextStyle(color: _textSub),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _headerGreen),
            );
          }

          final chats = snapshot.data?.docs ?? [];

          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _headerGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 40,
                      color: _headerGreen,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "No messages yet",
                    style: TextStyle(
                      color: _textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Customer conversations will appear here.",
                    style: TextStyle(color: _textSub, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            itemCount: chats.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final chatDoc = chats[index];
              final data = chatDoc.data() as Map<String, dynamic>;
              final userId = chatDoc.id;
              final lastMessage = data['lastMessage'] ?? "No messages yet";
              final unread = data['unreadByAdmin'] ?? false;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .get(),
                builder: (context, userSnapshot) {
                  String displayName = data['userName'] ?? "";

                  if (displayName.isEmpty &&
                      userSnapshot.hasData &&
                      userSnapshot.data!.exists) {
                    final user =
                    userSnapshot.data!.data() as Map<String, dynamic>;
                    final firstName = user['firstName'] ?? user['name'] ?? '';
                    final lastName = user['lastName'] ?? '';
                    displayName = "$firstName $lastName".trim();
                  }

                  if (displayName.isEmpty) {
                    displayName = "Customer ($userId)";
                  }

                  final initialLetter = displayName.isNotEmpty
                      ? displayName[0].toUpperCase()
                      : "C";

                  return Container(
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: unread ? _headerGreen.withOpacity(0.5) : _border,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: unread
                            ? _headerGreen
                            : _headerGreen.withOpacity(0.12),
                        child: Text(
                          initialLetter,
                          style: TextStyle(
                            color: unread ? Colors.white : _headerGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        displayName,
                        style: TextStyle(
                          color: _textMain,
                          fontWeight:
                          unread ? FontWeight.bold : FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unread ? _textMain : _textSub,
                          fontSize: 13,
                          fontWeight:
                          unread ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      trailing: unread
                          ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          "NEW",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                          : const Icon(
                        Icons.chevron_right_rounded,
                        color: _textSub,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminConversationPage(
                              userId: userId,
                              userName: displayName,
                            ),
                          ),
                        );
                      },
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
}