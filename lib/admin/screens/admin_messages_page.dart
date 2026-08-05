import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_conversation_page.dart';

class AdminMessagesPage extends StatelessWidget {
  const AdminMessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Customer Messages"),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("chats")
            .orderBy("lastUpdated", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text("Error: ${snapshot.error}"),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final chats = snapshot.data?.docs ?? [];

          if (chats.isEmpty) {
            return const Center(
              child: Text("No customer messages."),
            );
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final data = chat.data() as Map<String, dynamic>;

              final userId = chat.id;
              final lastMessage = data["lastMessage"] ?? "";
              final unread = data["unreadByAdmin"] ?? false;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection("users")
                    .doc(userId)
                    .get(),
                builder: (context, userSnapshot) {
                  String customerName = "Customer";

                  if (userSnapshot.hasData &&
                      userSnapshot.data!.exists) {
                    final user =
                    userSnapshot.data!.data() as Map<String, dynamic>;

                    customerName =
                        "${user["firstName"] ?? ""} ${user["lastName"] ?? ""}"
                            .trim();

                    if (customerName.isEmpty) {
                      customerName = "Customer";
                    }
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        customerName[0].toUpperCase(),
                      ),
                    ),
                    title: Text(customerName),
                    subtitle: Text(
                      lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: unread
                        ? Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    )
                        : null,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminConversationPage(
                            userId: userId,
                          ),
                        ),
                      );
                    },
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