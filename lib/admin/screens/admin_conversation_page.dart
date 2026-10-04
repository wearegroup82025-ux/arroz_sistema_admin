import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  static const Color _green = Color(0xff2E7D32);
  static const Color _background = Color(0xffF0F2F5);
  static const Color _text = Color(0xff050505);
  static const Color _subText = Color(0xff65676B);
  static const Color _otherBubble = Color(0xffE4E6EB);

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  Future<void> _markAsRead() async {
    await FirebaseFirestore.instance
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

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.userName?.trim().isNotEmpty == true
        ? widget.userName!.trim()
        : 'Customer';

    final initial = displayName[0].toUpperCase();

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _text),
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _green.withOpacity(.12),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 11,
                    height: 11,
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
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    'Active now',
                    style: TextStyle(
                      color: _subText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1),
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

                final messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return _EmptyConversation(
                    name: displayName,
                    initial: initial,
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg =
                        messages[index].data() as Map<String, dynamic>;

                    final isAdmin = msg['senderId'] == 'admin';
                    final text = msg['text'] ?? '';
                    final timestamp = msg['timestamp'] as Timestamp?;

                    return _MessageBubble(
                      text: text,
                      isAdmin: isAdmin,
                      timestamp: timestamp,
                      otherInitial: initial,
                    );
                  },
                );
              },
            ),
          ),
          _MessageInput(
            controller: _controller,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isAdmin;
  final Timestamp? timestamp;
  final String otherInitial;

  const _MessageBubble({
    required this.text,
    required this.isAdmin,
    required this.timestamp,
    required this.otherInitial,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment:
            isAdmin ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isAdmin) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xff2E7D32).withOpacity(.12),
              child: Text(
                otherInitial,
                style: const TextStyle(
                  color: Color(0xff2E7D32),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * .72,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: isAdmin
                    ? const Color(0xff2E7D32)
                    : const Color(0xffE4E6EB),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isAdmin ? 20 : 5),
                  bottomRight: Radius.circular(isAdmin ? 5 : 20),
                ),
              ),
              child: Column(
                crossAxisAlignment: isAdmin
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color: isAdmin ? Colors.white : const Color(0xff050505),
                      fontSize: 15,
                      height: 1.25,
                    ),
                  ),
                  if (timestamp != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      _formatTime(timestamp!),
                      style: TextStyle(
                        color: isAdmin
                            ? Colors.white.withOpacity(.75)
                            : const Color(0xff65676B),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class _EmptyConversation extends StatelessWidget {
  final String name;
  final String initial;

  const _EmptyConversation({
    required this.name,
    required this.initial,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: const Color(0xff2E7D32).withOpacity(.12),
            child: Text(
              initial,
              style: const TextStyle(
                color: Color(0xff2E7D32),
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: const TextStyle(
              color: Color(0xff050505),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Start a conversation',
            style: TextStyle(
              color: Color(0xff65676B),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _MessageInput({
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 5,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Aa',
                  hintStyle: const TextStyle(
                    color: Color(0xff65676B),
                    fontSize: 15,
                  ),
                  filled: true,
                  fillColor: const Color(0xffF0F2F5),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: onSend,
              icon: const Icon(
                Icons.send_rounded,
                color: Color(0xff2E7D32),
                size: 25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}