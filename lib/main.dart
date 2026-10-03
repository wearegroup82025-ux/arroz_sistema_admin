import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import 'providers/language_provider.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'services/notification/notification_service.dart';

import 'user/screens/login_page.dart';
import 'user/screens/homeuser_page.dart';

import 'admin/screens/login_page.dart' as admin;
import 'admin/screens/dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==========================================
  // 1. INITIALIZE FIREBASE
  // ==========================================
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ==========================================
  // 2. INITIALIZE SUPABASE
  // ==========================================
  await Supabase.initialize(
    url: 'https://fgkxatamapalhuvwuzpw.supabase.co', 
    publishableKey: 'sb_publishable_BqNhtKDoaksy-_fMOwVhUw_OzpoEXSP', 
  ); 
 
  // ========================================== 
  // 3. NOTIFICATIONS 
  // ========================================== 
  if (!kIsWeb) { 
    await NotificationService.initNotification(); 
    await NotificationService.setupPeriodicWeatherCheck(); 
  } else { 
    debugPrint( 
      'Naka-Web platform: Nilampasan ang mobile notification initialization.', 
    ); 
  } 
 
  runApp( 
    ChangeNotifierProvider( 
      create: (_) => LanguageProvider(), 
      child: const MyApp(), 
    ), 
  ); 
} 
 
// ============================== 
// true  = Admin App 
// false = User App 
// ============================== 
const bool isAdminApp = true; 
 
class MyApp extends StatefulWidget { 
  const MyApp({super.key}); 
 
  @override 
  State<MyApp> createState() => _MyAppState(); 
} 
 
class _MyAppState extends State<MyApp> with WidgetsBindingObserver { 
  @override 
  void initState() { 
    super.initState(); 
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
 
    if (state == AppLifecycleState.detached) { 
      _logoutOnExit(); 
    } 
  } 
 
  void _logoutOnExit() { 
    if (isAdminApp && 
        firebase_auth.FirebaseAuth.instance.currentUser != null) { 
      firebase_auth.FirebaseAuth.instance.signOut(); 
    } 
  } 
 
  @override 
  Widget build(BuildContext context) { 
    return MaterialApp( 
      debugShowCheckedModeBanner: false, 
      title: 'ArrozSistema', 
      theme: ThemeData( 
        useMaterial3: true, 
        colorSchemeSeed: const Color(0xFF0F5132), 
        scaffoldBackgroundColor: const Color(0xFFFBFBF9), 
      ), 
      home: StreamBuilder<firebase_auth.User?>( 
        stream: firebase_auth.FirebaseAuth.instance.authStateChanges(), 
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