import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'notification_service.dart'; // IMPORT NG REALTIME NOTIFICATION SERVICE

import 'user/screens/login_page.dart';
import 'user/screens/homeuser_page.dart';

// IMPORT LANG ITO KUNG GUSTO MONG ADMIN
import 'admin/screens/login_page.dart' as admin;
import 'admin/screens/dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Initialize Realtime Notifications & Push Sound Listener
await NotificationService().initialize();

  runApp(const MyApp());
}

// ==============================
// CHANGE THIS ONLY
// true  = Admin App
// false = User App
// ==============================
const bool isAdminApp = true;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "ArrozSistema",
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0F5132),
        scaffoldBackgroundColor: const Color(0xFFFBFBF9),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFFFBFBF9),
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF0F5132),
                ),
              ),
            );
          }

          // Kapag may active session
          if (snapshot.hasData) {
            return isAdminApp
                ? const DashboardPage()
                : const HomeUserPage();
          }

          // Kapag wala pang login
          return isAdminApp
              ? const admin.LoginPage()
              : const LoginUserPage();
        },
      ),
    );
  }
} // 👈 INAYOS DITO (Tinanggal ang comma bago ang '}')