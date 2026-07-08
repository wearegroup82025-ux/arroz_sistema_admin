import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

// Inalis ang getStarted sa AuthState enum
enum AuthState { login, register }

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController(); 

  // Ginawang default screen ang Login Screen
  AuthState _currentScreen = AuthState.login;
  bool _isLoading = false;

  // Global Design Identity
  static const Color _background = Color(0xffF8FAFC); 
  static const Color _surface = Color(0xffFFFFFF);
  static const Color _primary = Color(0xff16A34A); // Vibrant Emerald Green
  static const Color _textPrimary = Color(0xff0F172A); 
  static const Color _textSecondary = Color(0xff475569); 
  static const Color _border = Color(0xffE2E8F0);

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackbar("Please fill in all fields.");
      return;
    }

    if (_currentScreen == AuthState.register) {
      if (password != confirmPasswordController.text.trim()) {
        _showSnackbar("Passwords do not match.");
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (_currentScreen == AuthState.login) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else if (_currentScreen == AuthState.register) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } on FirebaseAuthException catch (e) {
      _showSnackbar(e.message ?? "Authentication Error");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      _showSnackbar("Please enter your email first to receive the reset link.");
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnackbar("Password reset link sent to your email!");
    } on FirebaseAuthException catch (e) {
      _showSnackbar(e.message ?? "Error sending reset link.");
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: _textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildCurrentInterface(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentInterface() {
    switch (_currentScreen) {
      case AuthState.login:
        return _buildLoginScreen();
      case AuthState.register:
        return _buildRegisterScreen();
    }
  }

  /// --- 1. MINIMALIST LOGIN SCREEN ---
  Widget _buildLoginScreen() {
    return Column(
      key: const ValueKey('login'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Inalis ang back button dito dahil ito na ang landing screen
        const Text("Welcome Back", style: TextStyle(color: _textPrimary, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        const SizedBox(height: 8),
        const Text("Log in to secure your agronomic dashboard data.", style: TextStyle(color: _textSecondary, fontSize: 14)),
        const SizedBox(height: 32),
        
        _buildTextField(controller: emailController, label: "Email Address", icon: Icons.mail_outline_rounded),
        const SizedBox(height: 16),
        _buildTextField(controller: passwordController, label: "Password", icon: Icons.lock_outline_rounded, obscureText: true),
        
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _resetPassword,
            child: const Text("Forgot Password?", style: TextStyle(color: _primary, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
        const SizedBox(height: 16),
        
        _buildPrimaryButton(label: "Log In", onPressed: submit),
        const SizedBox(height: 16),
        
        _buildNavigationFooter(
          question: "New to the platform?",
          actionLabel: "Create an Account",
          onTap: () => setState(() => _currentScreen = AuthState.register),
        ),
      ],
    );
  }

  /// --- 2. MAAYOS NA SIGNUP SCREEN ---
  Widget _buildRegisterScreen() {
    return Column(
      key: const ValueKey('register'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textSecondary, size: 20),
          onPressed: () => setState(() => _currentScreen = AuthState.login),
        ),
        const SizedBox(height: 20),
        const Text("Create Account", style: TextStyle(color: _textPrimary, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        const SizedBox(height: 8),
        const Text("Join ArrozSistema to fully automate your warehouse logs.", style: TextStyle(color: _textSecondary, fontSize: 14)),
        const SizedBox(height: 32),
        
        _buildTextField(controller: emailController, label: "Email Address", icon: Icons.mail_outline_rounded),
        const SizedBox(height: 16),
        _buildTextField(controller: passwordController, label: "Password", icon: Icons.lock_outline_rounded, obscureText: true),
        const SizedBox(height: 16),
        _buildTextField(controller: confirmPasswordController, label: "Confirm Password", icon: Icons.lock_outline_rounded, obscureText: true),
        const SizedBox(height: 32),
        
        _buildPrimaryButton(label: "Register Account", onPressed: submit),
        const SizedBox(height: 16),
        
        _buildNavigationFooter(
          question: "Already have an account?",
          actionLabel: "Log In here",
          onTap: () => setState(() => _currentScreen = AuthState.login),
        ),
      ],
    );
  }

  /// --- REUSABLE UI COMPONENTS ---

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: const Color(0xff0F172A).withOpacity(0.015), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: _textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
          prefixIcon: Icon(icon, color: _textSecondary.withOpacity(0.7), size: 22),
          floatingLabelStyle: const TextStyle(color: _primary, fontWeight: FontWeight.w700),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border, width: 1.2)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary, width: 1.8)),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({required String label, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _isLoading ? null : onPressed,
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: .2)),
      ),
    );
  }

  Widget _buildNavigationFooter({required String question, required String actionLabel, required VoidCallback onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(question, style: const TextStyle(color: _textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
        TextButton(
          onPressed: onTap,
          child: Text(actionLabel, style: const TextStyle(color: _primary, fontWeight: FontWeight.w800, fontSize: 14)),
        ),
      ],
    );
  }
}