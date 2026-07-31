import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth/auth.service.dart';
import 'address_picker.dart';

// ============================================================================
// 🎨 FB & MODERN ENTERPRISE COLOR PALETTE
// ============================================================================
class ArrozTheme {
  static const Color bgGrey = Color(0xFFF4F6F8);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color emerald = Color(0xFF0F5132);
  static const Color emeraldLight = Color(0xFF198754);
  static const Color mintAccent = Color(0xFFE8F5E9);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textSub = Color(0xFF64748B);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color warningOrange = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color dividerColor = Color(0xFFE2E8F0);
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingImage = false;
  bool _hasTriggeredNameWarning = false;

  // Function para magdagdag ng Warning Notification sa Firestore
  Future<void> _sendNameWarningNotification() async {
    if (_currentUser == null) return;
    try {
      final userNotifsRef = FirebaseFirestore.instance
          .collection("users")
          .doc(_currentUser!.uid)
          .collection("notifications");

      final existingWarning = await userNotifsRef
          .where('type', isEqualTo: 'PROFILE_NAME_WARNING')
          .where('isRead', isEqualTo: false)
          .get();

      if (existingWarning.docs.isEmpty) {
        await userNotifsRef.add({
          'title': '⚠️ Kailangan ng Pangalan',
          'body': 'Kailangan mong maglagay ng iyong pangalan sa Profile para sa mas mabilis na pag-process ng iyong mga order.',
          'type': 'PROFILE_NAME_WARNING',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("Error sending notification warning: $e");
    }
  }

  // Dialog para sa mabilisang pag-update ng pangalan
  void _showEditNameDialog(String currentFName, String currentMI, String currentLName) {
    final fNameController = TextEditingController(text: currentFName);
    final miController = TextEditingController(text: currentMI);
    final lNameController = TextEditingController(text: currentLName);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.edit_note_rounded, color: ArrozTheme.emerald),
                SizedBox(width: 8),
                Text("I-set ang Pangalan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Pakilagay ang iyong buong pangalan para makilala ka ng aming riders at shop Sellers.",
                    style: TextStyle(fontSize: 12, color: ArrozTheme.textSub),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: fNameController,
                    decoration: const InputDecoration(labelText: "First Name", border: OutlineInputBorder()),
                    validator: (v) => v == null || v.trim().isEmpty ? "Kailangan ang First Name" : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: miController,
                          maxLength: 2,
                          decoration: const InputDecoration(labelText: "M.I.", border: OutlineInputBorder(), counterText: ""),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 4,
                        child: TextFormField(
                          controller: lNameController,
                          decoration: const InputDecoration(labelText: "Last Name", border: OutlineInputBorder()),
                          validator: (v) => v == null || v.trim().isEmpty ? "Kailangan ang Last Name" : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text("Kanselahin", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: ArrozTheme.emerald),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setDialogState(() => isSaving = true);
                          try {
                            final String newFName = fNameController.text.trim();
                            final String newMI = miController.text.trim();
                            final String newLName = lNameController.text.trim();
                            final String full = "$newFName ${newMI.isNotEmpty ? '$newMI. ' : ''}$newLName".trim();

                            await FirebaseFirestore.instance.collection("users").doc(_currentUser!.uid).update({
                              'firstName': newFName,
                              'middleInitial': newMI,
                              'lastName': newLName,
                              'name': full,
                            });

                            await _currentUser!.updateDisplayName(full);

                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Matagumpay na na-update ang pangalan!"), backgroundColor: ArrozTheme.emerald),
                            );
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Pumalya sa pag-save: $e"), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("I-save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(
        backgroundColor: ArrozTheme.bgGrey,
        body: Center(child: Text("Walang naka-login na user.")),
      );
    }

    return Scaffold(
      backgroundColor: ArrozTheme.bgGrey,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection("users").doc(_currentUser!.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: ArrozTheme.emerald));
          }

          Map<String, dynamic> userData = {};
          if (snapshot.hasData && snapshot.data!.data() != null) {
            userData = snapshot.data!.data() as Map<String, dynamic>;
          }

          final String firstName = userData['firstName'] ?? '';
          final String middleInitial = userData['middleInitial'] ?? '';
          final String lastName = userData['lastName'] ?? '';

          String formattedFullName = "$firstName ${middleInitial.isNotEmpty ? '$middleInitial. ' : ''}$lastName".trim();
          bool isNameMissing = false;

          if (formattedFullName.isEmpty) {
            final String rawName = userData['name'] ?? _currentUser!.displayName ?? '';
            if (rawName.isEmpty || rawName == 'Arroz User') {
              formattedFullName = 'Walang Pangalan';
              isNameMissing = true;
            } else {
              formattedFullName = rawName;
            }
          }

          // Trigger warning notification & alert pag walang pangalan
          if (isNameMissing && !_hasTriggeredNameWarning) {
            _hasTriggeredNameWarning = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _sendNameWarningNotification();
            });
          }

          final String userEmail = userData['email'] ?? _currentUser!.email ?? 'Walang Email';
          final String userPhone = userData['phone'] ?? 'Walang Phone Number';
          final String? photoUrl = userData['photoUrl'] ?? _currentUser!.photoURL;

          return LayoutBuilder(
            builder: (context, constraints) {
              final double maxContentWidth = constraints.maxWidth > 600 ? 600 : constraints.maxWidth;

              return Center(
                child: SizedBox(
                  width: maxContentWidth,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // 1. HEADER BANNER & PROFILE AVATAR
                      SliverToBoxAdapter(
                        child: Container(
                          color: ArrozTheme.cardWhite,
                          child: Column(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  // Banner Background
                                  Container(
                                    height: 160,
                                    width: double.infinity,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [ArrozTheme.emerald, ArrozTheme.emeraldLight],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                  ),
                                  // Profile Picture sa Gitna
                                  Positioned(
                                    bottom: -50,
                                    child: Stack(
                                      alignment: Alignment.bottomRight,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 4),
                                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                                          ),
                                          child: CircleAvatar(
                                            radius: 54,
                                            backgroundColor: ArrozTheme.mintAccent,
                                            backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                                            child: _isUploadingImage
                                                ? const CircularProgressIndicator(color: ArrozTheme.emerald)
                                                : (photoUrl == null || photoUrl.isEmpty)
                                                    ? Text(
                                                        formattedFullName.isNotEmpty ? formattedFullName[0].toUpperCase() : "A",
                                                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: ArrozTheme.emerald),
                                                      )
                                                    : null,
                                          ),
                                        ),
                                        // MISMONG CAMERA BUTTON SA DITO LANG SA PROFILE AVATAR
                                        GestureDetector(
                                          onTap: () => _showImageSourcePicker(context),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                                            ),
                                            child: const Icon(Icons.camera_alt, size: 18, color: ArrozTheme.emerald),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 58),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    formattedFullName,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: isNameMissing ? ArrozTheme.dangerRed : ArrozTheme.textDark,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20, color: ArrozTheme.emerald),
                                    onPressed: () => _showEditNameDialog(firstName, middleInitial, lastName),
                                  )
                                ],
                              ),
                              Text(
                                userEmail,
                                style: const TextStyle(fontSize: 14, color: ArrozTheme.textSub),
                              ),
                              const SizedBox(height: 16),

                              // ⚠️ WARNING CARD BANNER (Lumalabas kapag walang pangalan)
                              if (isNameMissing) ...[
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: ArrozTheme.warningBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: ArrozTheme.warningOrange.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, color: ArrozTheme.warningOrange, size: 28),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "Kailangan ng Pangalan!",
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ArrozTheme.warningOrange),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "Mangyaring i-set ang iyong pangalan upang mapabilis ang pagproseso ng iyong order.",
                                              style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: ArrozTheme.warningOrange,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () => _showEditNameDialog(firstName, middleInitial, lastName),
                                        child: const Text("I-set Now", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],

                              const Divider(height: 1, color: ArrozTheme.dividerColor),
                            ],
                          ),
                        ),
                      ),

                      // 2. MAIN MENU NAVIGATION
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 4, bottom: 8),
                                child: Text("Account Settings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ArrozTheme.textSub)),
                              ),
                              _buildMenuTile(
                                icon: Icons.person_outline,
                                title: "Personal Details",
                                subtitle: isNameMissing ? "⚠️ Walang pangalan na nakalagay" : "Tingnan ang pangalan, email, at phone number",
                                isWarning: isNameMissing,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PersonalDetailsPage(
                                        fullName: formattedFullName,
                                        email: userEmail,
                                        phone: userPhone,
                                        isNameMissing: isNameMissing,
                                        onEditNameTap: () => _showEditNameDialog(firstName, middleInitial, lastName),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              _buildMenuTile(
                                icon: Icons.security_outlined,
                                title: "Security & Addresses",
                                subtitle: "Password reset via OTP at shipping addresses",
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SecurityAndAddressPage(
                                        email: userEmail,
                                        fullName: formattedFullName,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              _buildMenuTile(
                                icon: Icons.tune_outlined,
                                title: "Preferences",
                                subtitle: "Notifications at Wika ng application",
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const PreferencesPage(),
                                    ),
                                  );
                                },
                              ),
                              _buildMenuTile(
                                icon: Icons.help_outline_rounded,
                                title: "Help & Support Guide",
                                subtitle: "Gabay kung paano gamitin ang ArrozApp at FAQs",
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const HelpGuidePage(),
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 20),

                              // LOGOUT BUTTON
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade50,
                                    foregroundColor: ArrozTheme.dangerRed,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(color: Colors.red.shade200),
                                    ),
                                  ),
                                  icon: const Icon(Icons.logout, size: 20),
                                  label: const Text("Log Out", style: TextStyle(fontWeight: FontWeight.bold)),
                                  onPressed: () => _showLogoutDialog(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isWarning = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isWarning ? ArrozTheme.warningBg : ArrozTheme.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: isWarning ? Border.all(color: ArrozTheme.warningOrange.withOpacity(0.5)) : null,
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 1, offset: Offset(0, 1))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isWarning ? ArrozTheme.warningOrange.withOpacity(0.15) : ArrozTheme.mintAccent,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isWarning ? ArrozTheme.warningOrange : ArrozTheme.emerald, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: ArrozTheme.textDark)),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isWarning ? FontWeight.bold : FontWeight.normal,
            color: isWarning ? ArrozTheme.warningOrange : ArrozTheme.textSub,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: ArrozTheme.textSub),
        onTap: onTap,
      ),
    );
  }

  void _showImageSourcePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: ArrozTheme.emerald),
              title: const Text('Mula sa Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: ArrozTheme.emerald),
              title: const Text('Kumuha ng Litrato'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 75, maxWidth: 600);
      if (pickedFile == null) return;

      setState(() => _isUploadingImage = true);

      final File imageFile = File(pickedFile.path);
      final String refPath = 'profile_pictures/${_currentUser!.uid}.jpg';

      final storageRef = FirebaseStorage.instance.ref().child(refPath);
      await storageRef.putFile(imageFile);

      final String downloadUrl = await storageRef.getDownloadURL();

      await _currentUser!.updatePhotoURL(downloadUrl);
      await FirebaseFirestore.instance.collection("users").doc(_currentUser!.uid).update({'photoUrl': downloadUrl});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Na-upload na ang Profile Picture!"), backgroundColor: ArrozTheme.emerald),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Log Out"),
        content: const Text("Sigurado ka bang nais mong lumabas sa ArrozApp?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/', (route) => false);
            },
            child: const Text("Log Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 📱 1. PERSONAL DETAILS PAGE
// ============================================================================

class PersonalDetailsPage extends StatelessWidget {
  final String fullName;
  final String email;
  final String phone;
  final bool isNameMissing;
  final VoidCallback onEditNameTap;

  const PersonalDetailsPage({
    super.key,
    required this.fullName,
    required this.email,
    required this.phone,
    this.isNameMissing = false,
    required this.onEditNameTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArrozTheme.bgGrey,
      appBar: AppBar(
        title: const Text("Personal Details", style: TextStyle(color: ArrozTheme.textDark, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: ArrozTheme.textDark),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text("Contact & Identity", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ArrozTheme.textSub)),
            ),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.person,
                      color: isNameMissing ? ArrozTheme.warningOrange : ArrozTheme.emerald,
                    ),
                    title: const Text("Buong Pangalan"),
                    subtitle: Text(
                      fullName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isNameMissing ? ArrozTheme.warningOrange : ArrozTheme.textDark,
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: onEditNameTap,
                      child: Text(
                        isNameMissing ? "I-set" : "I-edit",
                        style: TextStyle(
                          color: isNameMissing ? ArrozTheme.warningOrange : ArrozTheme.emerald,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.email, color: ArrozTheme.emerald),
                    title: const Text("Email Address"),
                    subtitle: Text(email),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.phone, color: ArrozTheme.emerald),
                    title: const Text("Phone Number"),
                    subtitle: Text(phone),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 🔴 DELETE ACCOUNT ENTRY
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text("Account Ownership", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ArrozTheme.textSub)),
            ),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.delete_forever_rounded, color: ArrozTheme.dangerRed, size: 22),
                ),
                title: const Text("Delete Account", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: ArrozTheme.dangerRed)),
                subtitle: const Text("I-schedule ang iyong account para sa permanent deletion"),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: ArrozTheme.textSub),
                onTap: () {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AccountDeletionPage(userId: uid, userEmail: email),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 🔴 2. SENIOR-DEV LEVEL DELETE ACCOUNT PAGE (100% WATERPROOF & NO DEVIATION)
// ============================================================================

class AccountDeletionPage extends StatefulWidget {
  final String userId;
  final String userEmail;
  const AccountDeletionPage({super.key, required this.userId, required this.userEmail});

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  bool _isProcessing = false;

  // STEP 1: STRICT ORDER CHECKING (WATERPROOF GUARD)
  Future<void> _startDeletionFlow() async {
    setState(() => _isProcessing = true);

    try {
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: widget.userId)
          .get();

      List<DocumentSnapshot> activeShippingOrders = [];
      List<DocumentSnapshot> cancellablePendingOrders = [];

      for (var doc in ordersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String status = (data['orderStatus'] ?? data['status'] ?? 'Pending').toString();
        final bool isPaid = data['isPaid'] ?? false;
        final bool prepareToShip = data['prepareToShip'] ?? false;

        bool isToShipOrActive = (status == "Pending" || status == "Paid") && (isPaid || prepareToShip);
        bool isShippingOrDelivered = status == "Shipping" || status == "Delivered" || status == "To Receive";

        if (isToShipOrActive || isShippingOrDelivered) {
          activeShippingOrders.add(doc);
        } else if ((status == "Pending" || status == "Unpaid") && !isPaid && !prepareToShip) {
          cancellablePendingOrders.add(doc);
        }
      }

      setState(() => _isProcessing = false);

      if (activeShippingOrders.isNotEmpty) {
        if (!mounted) return;
        _showShippingBlockerDialog();
        return;
      }

      if (!mounted) return;
      _showPasswordVerificationDialog(cancellablePendingOrders);
    } catch (e) {
      setState(() => _isProcessing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  void _showShippingBlockerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.gavel_rounded, color: ArrozTheme.dangerRed, size: 28),
            SizedBox(width: 8),
            Text("Bawal Mag-Delete", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "Mayroon ka pang active order na kasalukuyang nasa TO SHIP, TO RECEIVE, o SHIPPING.\n\nHindi mo maaaring i-delete ang iyong account habang ipinapadala o inihahanda pa ang iyong order upang maiwasan ang panloloko o scam sa seller.",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ArrozTheme.emerald),
            onPressed: () => Navigator.pop(context),
            child: const Text("Naintindihan Ko", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // STEP 2: RE-AUTHENTICATION VIA PASSWORD
  void _showPasswordVerificationDialog(List<DocumentSnapshot> cancellableOrders) {
    final passwordController = TextEditingController();
    String passwordError = "";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text("Kumpirmahin ang Deletion", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "⚠️ BABALA: Ang iyong account ay maa-access pa sa loob ng 30 days bago PERMANENTENG MABURA. Pakilagay ang password.",
                    style: TextStyle(fontSize: 13, color: ArrozTheme.textSub),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Password",
                      errorText: passwordError.isNotEmpty ? passwordError : null,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: ArrozTheme.dangerRed),
                  onPressed: () async {
                    FocusScope.of(context).unfocus();
                    final pass = passwordController.text.trim();
                    if (pass.isEmpty) {
                      setDialogState(() => passwordError = "Required ang password!");
                      return;
                    }

                    try {
                      final currentUser = FirebaseAuth.instance.currentUser;
                      AuthCredential cred = EmailAuthProvider.credential(email: widget.userEmail, password: pass);
                      await currentUser!.reauthenticateWithCredential(cred);

                      if (!context.mounted) return;
                      Navigator.pop(context);

                      _executeDeleteAction(cancellableOrders);
                    } catch (e) {
                      setDialogState(() => passwordError = "Maling password!");
                    }
                  },
                  child: const Text("I-confirm at I-delete", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // STEP 3: ATOMIC DATABASE TRANSACTION (STOCK RESTORATION & SCHEDULED DELETION)
  Future<void> _executeDeleteAction(List<DocumentSnapshot> cancellableOrders) async {
    setState(() => _isProcessing = true);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        for (var orderDoc in cancellableOrders) {
          final orderRef = FirebaseFirestore.instance.collection("orders").doc(orderDoc.id);
          final orderData = orderDoc.data() as Map<String, dynamic>;
          final List<dynamic> itemsList = orderData['items'] ?? [];

          transaction.update(orderRef, {
            'orderStatus': 'Cancelled',
            'status': 'Cancelled',
            'cancellationReason': 'Account Scheduled for Deletion',
            'cancelledAt': FieldValue.serverTimestamp(),
          });

          for (var item in itemsList) {
            final String productId = item['productId'] ?? '';
            final int quantityToReturn = item['quantity'] ?? 0;

            if (productId.isNotEmpty && quantityToReturn > 0) {
              final productRef = FirebaseFirestore.instance.collection("products").doc(productId);
              final productSnapshot = await transaction.get(productRef);

              if (productSnapshot.exists) {
                final currentStock = productSnapshot.data()?['stock'] ?? 0;
                transaction.update(productRef, {
                  'stock': currentStock + quantityToReturn,
                });
              }
            }
          }
        }

        final userRef = FirebaseFirestore.instance.collection('users').doc(widget.userId);
        DateTime deletionDate = DateTime.now().add(const Duration(days: 30));

        transaction.update(userRef, {
          'isScheduledForDeletion': true,
          'scheduledDeletionDate': Timestamp.fromDate(deletionDate),
          'deletedAtRequest': FieldValue.serverTimestamp(),
        });
      });

      await FirebaseAuth.instance.signOut();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Na-schedule na ang account deletion sa loob ng 30 days. Naibalik na rin ang stock ng pending orders."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );

      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      setState(() => _isProcessing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Pumalya ang transaksyon: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArrozTheme.bgGrey,
      appBar: AppBar(
        title: const Text("Delete Account", style: TextStyle(color: ArrozTheme.textDark, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: ArrozTheme.textDark),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: ArrozTheme.dangerRed, size: 26),
                        SizedBox(width: 8),
                        Text("Sigurado ka ba?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ArrozTheme.dangerRed)),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Kapag itinuloy mo ang pagbura ng iyong account:\n\n"
                      "• Magkakaroon ka ng 30 days Grace Period upang baguhin ang iyong isip sa pamamanan ng muling pag-login.\n"
                      "• Pagkatapos ng 30 days, PERMANENTENG MABURA ang iyong profile, saved address, at order history.\n"
                      "• Ang anumang pending at unpaid order ay awtomatikong ma-ca-cancel at ibabalik sa stock inventory ng shop.",
                      style: TextStyle(fontSize: 13, height: 1.5, color: ArrozTheme.textDark),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ArrozTheme.dangerRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: _isProcessing ? null : _startDeletionFlow,
                  child: _isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Permanenteng I-delete Ang Account",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 📱 OTHER DEDICATED FULL-SCREEN PAGES
// ============================================================================

class SecurityAndAddressPage extends StatelessWidget {
  final String email;
  final String fullName;

  const SecurityAndAddressPage({super.key, required this.email, required this.fullName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArrozTheme.bgGrey,
      appBar: AppBar(
        title: const Text("Security & Address", style: TextStyle(color: ArrozTheme.textDark, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: ArrozTheme.textDark),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.lock_outline, color: ArrozTheme.emerald),
                title: const Text("Palitan ang Password"),
                subtitle: const Text("Magpapadala ng OTP code sa iyong email"),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _startOTPReset(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.location_on_outlined, color: ArrozTheme.emerald),
                title: const Text("Delivery Address Manager"),
                subtitle: const Text("Pumili o magdagdag ng lokasyon"),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  GlobalAddressSelectionService.showAddressPicker(
                    context: context,
                    onAddressSelected: (addr) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Napiling address: ${addr['barangay']}"), backgroundColor: ArrozTheme.emerald),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startOTPReset(BuildContext context) async {
    showDialog(context: context, builder: (context) => const Center(child: CircularProgressIndicator()));
    await AuthService.instance.generateAndSaveEmailOTP(email: email, name: fullName, reason: "Password Reset");
    if (!context.mounted) return;
    Navigator.pop(context);

    final otpController = TextEditingController();
    final passController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Verify OTP Code"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: otpController, decoration: const InputDecoration(labelText: "6-Digit OTP")),
            TextField(controller: passController, obscureText: true, decoration: const InputDecoration(labelText: "Bagong Password")),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              bool valid = await AuthService.instance.verifyEmailOTP(email: email, typedOtp: otpController.text.trim());
              if (valid) {
                await FirebaseAuth.instance.currentUser!.updatePassword(passController.text.trim());
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Napaltan na ang password!")));
              }
            },
            child: const Text("Verify & Save"),
          )
        ],
      ),
    );
  }
}

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  bool notif = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArrozTheme.bgGrey,
      appBar: AppBar(
        title: const Text("Preferences", style: TextStyle(color: ArrozTheme.textDark, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: ArrozTheme.textDark),
      ),
      body: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              activeColor: ArrozTheme.emerald,
              title: const Text("Push Notifications"),
              subtitle: const Text("Makatanggap ng update tungkol sa order status"),
              value: notif,
              onChanged: (v) => setState(() => notif = v),
            ),
            const Divider(height: 1),
            const ListTile(
              leading: Icon(Icons.language, color: ArrozTheme.emerald),
              title: Text("Language / Wika"),
              subtitle: Text("Tagalog / English"),
            ),
          ],
        ),
      ),
    );
  }
}

class HelpGuidePage extends StatelessWidget {
  const HelpGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArrozTheme.bgGrey,
      appBar: AppBar(
        title: const Text("Help & Support Guide", style: TextStyle(color: ArrozTheme.textDark, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: ArrozTheme.textDark),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHelpCard("🛒 Paano Mag-order sa ArrozApp?", "Pumunta sa Home Tab, piliin ang gustong uri ng palay o bigas, at ilagay ang kilos/sacks bago mag-checkout."),
          _buildHelpCard("📍 Paano magdagdag ng Delivery Address?", "Pumunta sa 'Security & Addresses' menu at piliin ang 'Delivery Address Manager'."),
          _buildHelpCard("🔒 Safe ba ang aking account?", "Opo, protektado ng Google Firebase authentication ang iyong datos."),
        ],
      ),
    );
  }

  Widget _buildHelpCard(String q, String a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Text(a, style: const TextStyle(color: ArrozTheme.textSub, fontSize: 13)),
        ],
      ),
    );
  }
}