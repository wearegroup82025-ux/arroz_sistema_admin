import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  String _searchQuery = "";
  // Selected Tab: 0 = Active Users, 1 = Blocklist
  int _selectedTabIndex = 0;

  static const Color primaryBlue = Color(0xff1E40AF);
  static const Color slateBg = Color(0xffF8FAFC);
  static const Color cardBorder = Color(0xffE2E8F0);
  static const Color textMain = Color(0xff0F172A);
  static const Color textMuted = Color(0xff64748B);

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

  // Helper para sa Direct Address sa Main Document
  String _getDirectAddress(Map<String, dynamic> data) {
    final addr = data['address'] ??
        data['fullAddress'] ??
        data['deliveryAddress'] ??
        data['location'] ??
        data['mainAddress'];

    if (addr != null && addr.toString().trim().isNotEmpty && addr.toString() != 'N/A') {
      return addr.toString().trim();
    }

    final street = data['streetBuildingHouseNo'] ?? data['street'] ?? '';
    final brgy = data['barangay'] ?? '';
    final city = data['cityMunicipality'] ?? data['city'] ?? '';
    final prov = data['province'] ?? '';

    final combined = [street, brgy, city, prov]
        .where((e) => e.toString().trim().isNotEmpty)
        .join(', ');

    return combined;
  }

  // Smart Address Widget para sa Card (Fallback sa Subcollection kapag walang Main Address)
  Widget _buildCardAddressWidget(String userId, Map<String, dynamic> rawData) {
    final directAddress = _getDirectAddress(rawData);
    if (directAddress.isNotEmpty) {
      return Text(
        directAddress,
        style: const TextStyle(fontSize: 12, color: textMuted),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('addresses')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text(
            "Kinukuha ang address...",
            style: TextStyle(fontSize: 12, color: textMuted, fontStyle: FontStyle.italic),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text(
            "Walang Naka-save na Address",
            style: TextStyle(fontSize: 12, color: textMuted),
          );
        }

        final docs = snapshot.data!.docs;
        DocumentSnapshot? defaultDoc;
        try {
          defaultDoc = docs.firstWhere((d) {
            final m = d.data() as Map<String, dynamic>;
            return (m['isDefault'] == true) || (m['isMain'] == true) || (m['default'] == true);
          });
        } catch (_) {
          defaultDoc = docs.first;
        }

        final addrData = defaultDoc.data() as Map<String, dynamic>;
        String fullAddr = addrData['fullAddress'] ?? addrData['address'] ?? '';
        if (fullAddr.isEmpty) {
          final street = addrData['streetBuildingHouseNo'] ?? addrData['street'] ?? '';
          final brgy = addrData['barangay'] ?? '';
          final city = addrData['cityMunicipality'] ?? addrData['city'] ?? '';
          final prov = addrData['province'] ?? '';
          fullAddr = [street, brgy, city, prov]
              .where((e) => e.toString().trim().isNotEmpty)
              .join(', ');
        }

        final label = addrData['label'] ?? 'Main';

        return Text(
          "[$label] ${fullAddr.isEmpty ? 'Walang Detalye' : fullAddr}",
          style: const TextStyle(fontSize: 12, color: textMain, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }

  // Confirmation Dialog
  void _confirmAction({
    required BuildContext context,
    required String title,
    required String content,
    required Color actionColor,
    required String confirmLabel,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: actionColor, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textMain),
              ),
            ),
          ],
        ),
        content: Text(
          content,
          style: const TextStyle(fontSize: 14, color: textMuted, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: cardBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("Kanselahin", style: TextStyle(color: textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Text(confirmLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Modal Window para sa Buong Detalye
  void _showUserDetailsModal(BuildContext context, Map<String, dynamic> data, String userId) {
    final phone = _getPhoneNumber(data);
    final directAddress = _getDirectAddress(data);
    final bool isBlocked = data['isBlocked'] ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isBlocked ? Colors.red.shade50 : const Color(0xffEFF6FF),
                  radius: 26,
                  child: Text(
                    (data['fullName'] ?? data['name'] ?? 'U')[0].toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isBlocked ? Colors.red : primaryBlue,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['fullName'] ?? data['name'] ?? 'Walang Pangalan',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textMain),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Text("User ID: ", style: TextStyle(fontSize: 11, color: textMuted)),
                          Expanded(
                            child: SelectableText(
                              userId,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 28, color: cardBorder),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "PRIMARY INFORMATION",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 12),
                    _buildModalInfoTile(Icons.email_outlined, "Email Address", data['email'] ?? 'Walang Email'),
                    _buildModalInfoTile(Icons.phone_outlined, "Contact Number", phone),
                    _buildModalInfoTile(Icons.location_on_outlined, "Primary Address", directAddress.isEmpty ? 'Walang Naka-save na Address' : directAddress),
                    _buildModalInfoTile(
                      Icons.shield_outlined,
                      "Account Status",
                      isBlocked ? "BLOCKED / RESTRICTED" : "ACTIVE ACCOUNT",
                      isDanger: isBlocked,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "SAVED ADDRESSES (SUBCOLLECTION)",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(userId).collection('addresses').get(),
                      builder: (context, addrSnapshot) {
                        if (addrSnapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: LinearProgressIndicator(minHeight: 2, color: primaryBlue),
                          );
                        }
                        if (!addrSnapshot.hasData || addrSnapshot.data!.docs.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: slateBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: cardBorder),
                            ),
                            child: const Text(
                              "Walang naka-save na karagdagang address sa subcollection.",
                              style: TextStyle(fontSize: 12, color: textMuted, fontStyle: FontStyle.italic),
                            ),
                          );
                        }

                        final addresses = addrSnapshot.data!.docs;
                        return Column(
                          children: addresses.map((doc) {
                            final addrData = doc.data() as Map<String, dynamic>;
                            final street = addrData['streetBuildingHouseNo'] ?? addrData['street'] ?? '';
                            final brgy = addrData['barangay'] ?? '';
                            final city = addrData['cityMunicipality'] ?? addrData['city'] ?? '';
                            final prov = addrData['province'] ?? '';
                            final postal = addrData['postalCode'] ?? '';

                            String fullAddr = addrData['fullAddress'] ?? addrData['address'] ?? '';
                            if (fullAddr.isEmpty) {
                              fullAddr = [street, brgy, city, prov, postal].where((e) => e.toString().trim().isNotEmpty).join(', ');
                            }

                            final addrPhone = addrData['mobileNumber'] ?? addrData['phoneNumber'] ?? addrData['phone'] ?? 'Walang Number';
                            final label = addrData['label'] ?? 'Address';
                            final receiverName = addrData['fullName'] ?? addrData['name'] ?? '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: slateBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: cardBorder),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Color(0xffDBEAFE),
                                    child: Icon(Icons.place, size: 16, color: primaryBlue),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: cardBorder),
                                              ),
                                              child: Text(
                                                label.toString().toUpperCase(),
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryBlue),
                                              ),
                                            ),
                                            if (receiverName.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  "($receiverName)",
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textMain),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ]
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          fullAddr.isEmpty ? 'Walang Detalye' : fullAddr,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textMain, height: 1.3),
                                        ),
                                        const SizedBox(height: 4),
                                        Text("Contact: $addrPhone", style: const TextStyle(fontSize: 11, color: textMuted)),
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
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDanger ? Colors.red.shade50 : slateBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: isDanger ? Colors.red : primaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDanger ? Colors.red.shade700 : textMain,
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
      backgroundColor: slateBg,
      appBar: AppBar(
        title: const Text(
          'User Management',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textMain),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: cardBorder, height: 1.0),
        ),
      ),
      body: Column(
        children: [
          // SEARCH BAR AT MAIN TAB SWITCHER (Active vs Blocklist)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase().trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Maghanap ng pangalan, email, o phone...",
                    hintStyle: const TextStyle(fontSize: 13, color: textMuted),
                    prefixIcon: const Icon(Icons.search, color: textMuted, size: 20),
                    filled: true,
                    fillColor: slateBg,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: primaryBlue),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // TAB SELECTION (Active Users vs Blocklist)
                Container(
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: slateBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Row(
                    children: [
                      // TAB 1: Active Users
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTabIndex = 0;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: _selectedTabIndex == 0 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _selectedTabIndex == 0
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : [],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline_rounded,
                                  size: 18,
                                  color: _selectedTabIndex == 0 ? primaryBlue : textMuted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Active Users",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _selectedTabIndex == 0 ? FontWeight.bold : FontWeight.w500,
                                    color: _selectedTabIndex == 0 ? primaryBlue : textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // TAB 2: Blocklist
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTabIndex = 1;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: _selectedTabIndex == 1 ? Colors.red : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _selectedTabIndex == 1
                                  ? [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : [],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.block_rounded,
                                  size: 18,
                                  color: _selectedTabIndex == 1 ? Colors.white : textMuted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Blocklist",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _selectedTabIndex == 1 ? FontWeight.bold : FontWeight.w500,
                                    color: _selectedTabIndex == 1 ? Colors.white : textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // LIST OF USERS
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryBlue));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("Walang nahanap na user accounts.", style: TextStyle(color: textMuted)),
                  );
                }

                // Strictly Filter based on Tab Selection:
                // Tab Index 0 = Active Users (isBlocked == false)
                // Tab Index 1 = Blocklist (isBlocked == true)
                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['fullName'] ?? data['name'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final phone = _getPhoneNumber(data).toLowerCase();
                  final bool isBlocked = data['isBlocked'] ?? false;

                  final matchesSearch = name.contains(_searchQuery) || email.contains(_searchQuery) || phone.contains(_searchQuery);

                  if (_selectedTabIndex == 0) {
                    // Active Users List
                    return matchesSearch && !isBlocked;
                  } else {
                    // Blocklist
                    return matchesSearch && isBlocked;
                  }
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Text(
                      _selectedTabIndex == 0
                          ? "Walang active users sa listahan."
                          : "Walang mga naka-block na user sa ngayon.",
                      style: const TextStyle(color: textMuted),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final String userId = doc.id;
                    final String email = data['email'] ?? 'Walang Email';
                    final String name = data['fullName'] ?? data['name'] ?? 'Walang Pangalan';
                    final bool isBlocked = data['isBlocked'] ?? false;
                    final String phone = _getPhoneNumber(data);

                    return _buildCleanUserCard(context, userId, name, email, isBlocked, phone, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // USER CARD
  Widget _buildCleanUserCard(
    BuildContext context,
    String userId,
    String name,
    String email,
    bool isBlocked,
    String phone,
    Map<String, dynamic> rawData,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBlocked ? Colors.red.shade200 : cardBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showUserDetailsModal(context, rawData, userId),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar + Name & Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: isBlocked ? Colors.red.shade50 : const Color(0xffEFF6FF),
                      radius: 20,
                      child: Icon(
                        isBlocked ? Icons.block : Icons.person_outline_rounded,
                        color: isBlocked ? Colors.red : primaryBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isBlocked ? Colors.red.shade900 : textMain,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(email, style: const TextStyle(fontSize: 12, color: textMuted)),
                        ],
                      ),
                    ),

                    // Status Badge (BLOCKED / ACTIVE)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isBlocked ? Colors.red.shade50 : slateBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isBlocked ? Colors.red.shade200 : cardBorder,
                        ),
                      ),
                      child: Text(
                        isBlocked ? "BLOCKED" : "ACTIVE",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isBlocked ? Colors.red : textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20, color: cardBorder),

                // Middle Row: Quick Details (Phone & Address)
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 15, color: textMuted),
                    const SizedBox(width: 8),
                    Text(phone, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMain)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 15, color: textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCardAddressWidget(userId, rawData),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Bottom Row: Action Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => _showUserDetailsModal(context, rawData, userId),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.visibility_outlined, size: 16, color: primaryBlue),
                            SizedBox(width: 4),
                            Text(
                              "Tingnan ang Detalye",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryBlue),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                          icon: Icon(
                            isBlocked ? Icons.lock_open_rounded : Icons.block_outlined,
                            size: 19,
                            color: isBlocked ? Colors.green.shade700 : Colors.orange.shade800,
                          ),
                          tooltip: isBlocked ? "Unblock User" : "Block User",
                          onPressed: () {
                            _confirmAction(
                              context: context,
                              title: isBlocked ? "I-unblock ang User?" : "I-block ang User?",
                              content: isBlocked
                                  ? "Mawawala si $name sa Blocklist at mababalik sa Active Users."
                                  : "Mapupunta si $name sa Blocklist at malilimitahan ang kanyang account access.",
                              actionColor: isBlocked ? Colors.green.shade700 : Colors.orange.shade800,
                              confirmLabel: isBlocked ? "Unblock" : "Block",
                              onConfirm: () async {
                                await FirebaseFirestore.instance.collection('users').doc(userId).update({
                                  'isBlocked': !isBlocked,
                                });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isBlocked
                                            ? "Na-unblock na si $name at pinalipat sa Active Users."
                                            : "Na-block na si $name at inilipat sa Blocklist.",
                                      ),
                                      backgroundColor: isBlocked ? Colors.green : Colors.red,
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                          icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Colors.red),
                          tooltip: "Burahin Account",
                          onPressed: () {
                            _confirmAction(
                              context: context,
                              title: "Burahin ang Account?",
                              content: "Permanenteng mawawala sa Firestore ang account record ni $name.",
                              actionColor: Colors.red,
                              confirmLabel: "Burahin",
                              onConfirm: () async {
                                await FirebaseFirestore.instance.collection('users').doc(userId).delete();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Nabura na ang account ni $name"),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}