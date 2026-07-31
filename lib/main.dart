import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/language_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'notification_service.dart';

import 'user/screens/login_page.dart';
import 'user/screens/homeuser_page.dart';

import 'admin/screens/login_page.dart' as admin;
import 'admin/screens/dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService().initialize();

  runApp(
    ChangeNotifierProvider(
      create: (_) => LanguageProvider(),
      child: const MyApp(),
    ),
  );
}

// ==============================`
// true  = Admin App
// false = User App
// ==============================
const bool isAdminApp = false;

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Binu-build ang observer para mabantayan kapag isinarado o inalis sa recent apps
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Kapag detatached (lubusang inalis sa recent apps / pinatay ang app)
    // O kapag hidden/paused (depende kung gusto mong mag-logout din pag-minimize)
    if (state == AppLifecycleState.detached) {
      _logoutOnExit();
    }
  }

  void _logoutOnExit() {
    if (isAdminApp && FirebaseAuth.instance.currentUser != null) {
      FirebaseAuth.instance.signOut();
    }
  }

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

          if (snapshot.hasData) {
            return isAdminApp
                ? const DashboardPage()
                : const HomeUserPage();
          }

          return isAdminApp
              ? const admin.LoginPage()
              : const LoginUserPage();
        },
      ),
    );
  }
}