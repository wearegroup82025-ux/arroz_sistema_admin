import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserManagementPage extends StatelessWidget {
  const UserManagementPage({super.key});

  // Helper para sa confirmation dialogs (para iwas aksidente sa pag-block o delete)
  void _confirmAction(BuildContext context, String title, String content, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            child: const Text("Kumpirmahin"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: const Text('User Management & Controls'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff0F172A),
        elevation: 0,
      ),
      // Gumamit ng StreamBuilder para sa totoong real-time data mula sa Firestore
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("Walang nahanap na totoong user accounts.", style: TextStyle(color: Colors.grey)),
            );
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final doc = users[index];
              final data = doc.data() as Map<String, dynamic>;
              
              // Pagkuha ng totoong fields mula sa iyong Firestore document
              final String userId = doc.id;
              final String email = data['email'] ?? 'No Email';
              final String name = data['fullName'] ?? 'No Name';
              final String role = data['role'] ?? 'Client';
              final bool isBlocked = data['isBlocked'] ?? false;
              final String accountNumber = data['accountNumber'] ?? 'Walang Data';

              return _buildUserCard(context, userId, name, email, role, isBlocked, accountNumber);
            },
          );
        },
      ),
    );
  }

  // UI Component: Dito ipinapakita ang totoong impormasyon ng bawat User
  Widget _buildUserCard(
    BuildContext context, 
    String userId, 
    String name, 
    String email, 
    String role, 
    bool isBlocked, 
    String accountNumber,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xffE2E8F0), width: 1.2),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isBlocked ? Colors.red.shade50 : const Color(0xffF0FDF4),
          child: Icon(
            isBlocked ? Icons.block_flipped : Icons.person_outline_rounded,
            color: isBlocked ? Colors.red : const Color(0xff16A34A),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff0F172A))),
        subtitle: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Email: $email", style: const TextStyle(fontSize: 12, color: Color(0xff475569))),
              Text("Account No: $accountNumber", style: const TextStyle(fontSize: 12, color: Color(0xff475569))),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isBlocked ? Colors.red.withOpacity(0.12) : Colors.blueGrey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isBlocked ? "STATUS: BLOCKED (⚠️ SCAMMER)" : "Role: ${role.toUpperCase()}",
                  style: TextStyle(
                    color: isBlocked ? Colors.red.shade700 : const Color(0xff475569),
                    fontWeight: isBlocked ? FontWeight.bold : FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Button para i-Toggle ang Block/Unblock status sa Firestore
            IconButton(
              icon: Icon(
                isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                color: isBlocked ? Colors.green : Colors.orange.shade800,
              ),
              tooltip: isBlocked ? "Unblock Account" : "Block Scammer",
              onPressed: () {
                _confirmAction(
                  context,
                  isBlocked ? "I-unblock ang User?" : "I-block ang User (Anti-Scam)?",
                  "Sigurado ka ba na gusto mong baguhin ang status ng account ni $name?",
                  () {
                    FirebaseFirestore.instance.collection('users').doc(userId).update({
                      'isBlocked': !isBlocked,
                    });
                  },
                );
              },
            ),
            // Button para tuluyang burahin ang user sa database
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              tooltip: "Permanenteng Burahin",
              onPressed: () {
                _confirmAction(
                  context,
                  "Burahin ang Account?",
                  "Permanenteng mawawala sa system ang account ni $name. Sigurado ka ba?",
                  () {
                    FirebaseFirestore.instance.collection('users').doc(userId).delete();
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}