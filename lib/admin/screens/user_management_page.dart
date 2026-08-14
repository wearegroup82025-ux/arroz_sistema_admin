import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  String _searchQuery = "";

  // Helper para sa Phone Number Fallback
  String _getPhoneNumber(Map<String, dynamic> data) {
    final phone = data['phoneNumber'] ??
        data['phone'] ??
        data['mobileNumber'] ??
        data['contactNumber'] ??
        data['mobile'];

    if (phone != null && phone.toString().trim().isNotEmpty) {
      return phone.toString().trim();
    }
    return 'Walang Phone Number';
  }

  // Helper para sa Address Fallback
  String _getDirectAddress(Map<String, dynamic> data) {
    final addr = data['address'] ??
        data['fullAddress'] ??
        data['deliveryAddress'] ??
        data['location'];

    if (addr != null && addr.toString().trim().isNotEmpty) {
      return addr.toString().trim();
    }
    return 'Walang Naka-save na Address';
  }

  // Confirmation Dialog
  void _confirmAction(BuildContext context, String title, String content, Color actionColor, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(content, style: const TextStyle(fontSize: 14, color: Color(0xff475569))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            child: const Text("Kumpirmahin", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Pop-up Modal para sa Buong Detalye ng User
  void _showUserDetailsModal(BuildContext context, Map<String, dynamic> data, String userId) {
    final phone = _getPhoneNumber(data);
    final directAddress = _getDirectAddress(data);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xffEFF6FF),
                  radius: 22,
                  child: Text(
                    (data['fullName'] ?? data['name'] ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff2563EB), fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['fullName'] ?? data['name'] ?? 'Walang Pangalan',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xff0F172A)),
                      ),
                      Text(
                        "ID: $userId",
                        style: const TextStyle(fontSize: 11, color: Color(0xff94A3B8)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("PRIMARY INFORMATION", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff64748B), letterSpacing: 0.8)),
                    const SizedBox(height: 10),
                    _buildModalInfoTile(Icons.email_outlined, "Email Address", data['email'] ?? 'Walang Email'),
                    _buildModalInfoTile(Icons.phone_outlined, "Contact Number", phone),
                    _buildModalInfoTile(Icons.location_on_outlined, "Primary Address", directAddress),
                    _buildModalInfoTile(Icons.admin_panel_settings_outlined, "Role / Access", (data['role'] ?? 'Client').toString().toUpperCase()),
                    _buildModalInfoTile(
                      Icons.shield_outlined,
                      "Account Status",
                      (data['isBlocked'] ?? false) ? "BLOCKED / RESTRICTED" : "ACTIVE ACCOUNT",
                      isDanger: data['isBlocked'] ?? false,
                    ),

                    const SizedBox(height: 20),
                    const Text("SAVED ADDRESSES (SUBCOLLECTION)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff64748B), letterSpacing: 0.8)),
                    const SizedBox(height: 10),

                    // Live Fetch ng Subcollection Addresses
                    FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(userId).collection('addresses').get(),
                      builder: (context, addrSnapshot) {
                        if (addrSnapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: LinearProgressIndicator(minHeight: 2),
                          );
                        }
                        if (!addrSnapshot.hasData || addrSnapshot.data!.docs.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xffF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text("Walang naka-save na dagdag na address.", style: TextStyle(fontSize: 12, color: Color(0xff94A3B8), fontStyle: FontStyle.italic)),
                          );
                        }

                        final addresses = addrSnapshot.data!.docs;
                        return Column(
                          children: addresses.map((doc) {
                            final addrData = doc.data() as Map<String, dynamic>;
                            final fullAddr = addrData['fullAddress'] ?? addrData['address'] ?? 'Walang Detalye';
                            final addrPhone = addrData['mobileNumber'] ?? addrData['phoneNumber'] ?? addrData['phone'] ?? 'Walang Number';
                            final label = addrData['label'] ?? 'Address';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xffF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xffE2E8F0)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.place, size: 18, color: Color(0xff2563EB)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("[$label] $fullAddr", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xff1E293B))),
                                        const SizedBox(height: 2),
                                        Text("Contact: $addrPhone", style: const TextStyle(fontSize: 11, color: Color(0xff64748B))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                    // Dropdown para sa Raw Firestore Data para siguradong WALANG BUTAS
                    ExpansionTile(
                      title: const Text("Tingnan ang Lahat ng Raw Fields", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xff64748B))),
                      tilePadding: EdgeInsets.zero,
                      children: data.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("${entry.key}: ", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff334155))),
                              Expanded(
                                child: SelectableText(
                                  "${entry.value}",
                                  style: const TextStyle(fontSize: 11, color: Color(0xff64748B)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalInfoTile(IconData icon, String title, String value, {bool isDanger = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: isDanger ? Colors.red : const Color(0xff64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Color(0xff94A3B8))),
                SelectableText(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDanger ? Colors.red.shade700 : const Color(0xff0F172A),
                  ),
                ),
              ],
            ),
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
        title: const Text('User Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff0F172A),
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // SEARCH BAR HEADER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase().trim();
                });
              },
              decoration: InputDecoration(
                hintText: "Maghanap ng pangalan o email...",
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xff94A3B8)),
                prefixIcon: const Icon(Icons.search, color: Color(0xff64748B)),
                filled: true,
                fillColor: const Color(0xffF1F5F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // LIST OF USERS
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("Walang nahanap na accounts.", style: TextStyle(color: Colors.grey)),
                  );
                }

                // Filtering Base sa Search Query
                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['fullName'] ?? data['name'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || email.contains(_searchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text("Walang katugmang user sa hinahanap mo.", style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final String userId = doc.id;
                    final String email = data['email'] ?? 'No Email';
                    final String name = data['fullName'] ?? data['name'] ?? 'No Name';
                    final String role = data['role'] ?? 'Client';
                    final bool isBlocked = data['isBlocked'] ?? false;

                    final String phone = _getPhoneNumber(data);
                    final String address = _getDirectAddress(data);

                    return _buildCleanUserCard(context, userId, name, email, role, isBlocked, phone, address, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // MALINIS AT MALINAW NA USER CARD
  Widget _buildCleanUserCard(
    BuildContext context,
    String userId,
    String name,
    String email,
    String role,
    bool isBlocked,
    String phone,
    String address,
    Map<String, dynamic> rawData,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBlocked ? Colors.red.shade200 : const Color(0xffE2E8F0),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showUserDetailsModal(context, rawData, userId),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Avatar + Name & Status Badges
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: isBlocked ? Colors.red.shade50 : const Color(0xffF0FDF4),
                    radius: 20,
                    child: Icon(
                      isBlocked ? Icons.block : Icons.person_outline,
                      color: isBlocked ? Colors.red : const Color(0xff16A34A),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isBlocked ? Colors.red.shade900 : const Color(0xff0F172A),
                          ),
                        ),
                        Text(email, style: const TextStyle(fontSize: 12, color: Color(0xff64748B))),
                      ],
                    ),
                  ),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isBlocked ? Colors.red.shade50 : const Color(0xffF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isBlocked ? Colors.red.shade200 : const Color(0xffCBD5E1),
                      ),
                    ),
                    child: Text(
                      isBlocked ? "BLOCKED" : role.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isBlocked ? Colors.red : const Color(0xff475569),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, thickness: 0.8),

              // Middle Row: Quick Details (Phone & Address)
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 14, color: Color(0xff64748B)),
                  const SizedBox(width: 6),
                  Text(phone, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xff334155))),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: Color(0xff64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      address,
                      style: const TextStyle(fontSize: 12, color: Color(0xff64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Bottom Actions: Quick Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 16, color: Color(0xff2563EB)),
                    label: const Text("Tingnan Lahat", style: TextStyle(fontSize: 12, color: Color(0xff2563EB))),
                    onPressed: () => _showUserDetailsModal(context, rawData, userId),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    icon: Icon(
                      isBlocked ? Icons.lock_open : Icons.block,
                      size: 18,
                      color: isBlocked ? Colors.green : Colors.orange.shade800,
                    ),
                    tooltip: isBlocked ? "Unblock User" : "Block User",
                    onPressed: () {
                      _confirmAction(
                        context,
                        isBlocked ? "I-unblock ang User?" : "I-block ang User?",
                        "Sigurado ka ba sa pagbabago ng status ni $name?",
                        isBlocked ? Colors.green : Colors.orange.shade800,
                        () {
                          FirebaseFirestore.instance.collection('users').doc(userId).update({
                            'isBlocked': !isBlocked,
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    tooltip: "Burahin Account",
                    onPressed: () {
                      _confirmAction(
                        context,
                        "Burahin ang Account?",
                        "Permanenteng mawawala ang account ni $name.",
                        Colors.red,
                        () {
                          FirebaseFirestore.instance.collection('users').doc(userId).delete();
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}