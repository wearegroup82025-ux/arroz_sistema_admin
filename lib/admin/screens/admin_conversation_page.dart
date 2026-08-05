import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminConversationPage extends StatefulWidget {
  final String userId;
  final String? userName;

  const AdminConversationPage({
    super.key,
    required this.userId,
    this.userName,
  });

  @override
  State<AdminConversationPage> createState() => _AdminConversationPageState();
}

class _AdminConversationPageState extends State<AdminConversationPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Modern Enterprise Palette - Gamit ang exact Green shade (#2A6F4A)
  static const Color _bg = Color(0xffF8FAFC);
  static const Color _cardBg = Color(0xffFFFFFF);
  static const Color _primary = Color(0xff2A6F4A);
  static const Color _textMain = Color(0xff0F172A);
  static const Color _textSub = Color(0xff64748B);
  static const Color _border = Color(0xffE2E8F0);

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  void _markAsRead() {
    FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.userId)
        .set({'unreadByAdmin': false}, SetOptions(merge: true));
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    final chatRef =
    FirebaseFirestore.instance.collection('chats').doc(widget.userId);

    await chatRef.collection('messages').add({
      'senderId': 'admin',
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await chatRef.set({
      'lastMessage': text,
      'lastUpdated': FieldValue.serverTimestamp(),
      'unreadByUser': true,
      'unreadByAdmin': false,
    }, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.userName ?? widget.userId;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _cardBg,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _textMain),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: _primary.withOpacity(0.12),
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'C',
                style: const TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: _textMain,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "User ID: ${widget.userId}",
                    style: const TextStyle(color: _textSub, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: _border, height: 1.0),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.userId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _primary),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "Start the conversation by sending a message.",
                      style: TextStyle(color: _textSub, fontSize: 13),
                    ),
                  );
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg =
                    messages[index].data() as Map<String, dynamic>;
                    final bool isAdmin = msg['senderId'] == 'admin';
                    final Timestamp? time = msg['timestamp'] as Timestamp?;

                    return Align(
                      alignment: isAdmin
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isAdmin ? _primary : _cardBg,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14),
                            topRight: const Radius.circular(14),
                            bottomLeft: Radius.circular(isAdmin ? 14 : 2),
                            bottomRight: Radius.circular(isAdmin ? 2 : 14),
                          ),
                          border: isAdmin ? null : Border.all(color: _border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: isAdmin
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg['text'] ?? '',
                              style: TextStyle(
                                color: isAdmin ? Colors.white : _textMain,
                                fontSize: 14,
                                height: 1.3,
                              ),
                            ),
                            if (time != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(time),
                                style: TextStyle(
                                  color: isAdmin
                                      ? Colors.white.withOpacity(0.7)
                                      : _textSub,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Message Input Field
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: _cardBg,
              border: Border(top: BorderSide(color: _border)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: _textMain, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Type a reply...",
                        hintStyle:
                        const TextStyle(color: _textSub, fontSize: 14),
                        filled: true,
                        fillColor: _bg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: _border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: _border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: _primary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: _primary,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: _sendMessage,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $period";
  }
}