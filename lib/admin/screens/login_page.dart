import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // Global Design Identity
  static const Color _background = Color(0xffF8FAFC);
  static const Color _surface = Color(0xffFFFFFF);
  static const Color _appIconBg = Color(0xff0F5132); // Deep Emerald from pubspec launcher config
  static const Color _primary = Color(0xff16A34A);
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

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

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
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: IntrinsicHeight(
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: _buildLoginScreen(),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// --- ADMIN LOGIN SCREEN ---
  Widget _buildLoginScreen() {
    return Column(
      key: const ValueKey('admin_login'),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // App Icon Container
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: _appIconBg,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: _appIconBg.withOpacity(0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset(
              'assets/images/app_icon.png',
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.eco_rounded,
                  size: 48,
                  color: Colors.white,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Header Section
        const Text(
          "Admin Portal",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Log in to access and manage your agronomic system and dashboard data.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 36),

        // Text Fields
        _buildTextField(
          controller: emailController,
          label: "Admin Email",
          icon: Icons.admin_panel_settings_outlined,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: passwordController,
          label: "Password",
          icon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: _textSecondary.withOpacity(0.7),
              size: 20,
            ),
            onPressed: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
          ),
        ),

        // Forgot Password
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _resetPassword,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: const Text(
              "Forgot Password?",
              style: TextStyle(
                color: _primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Primary Action Button
        _buildPrimaryButton(label: "Log In as Admin", onPressed: submit),

        const SizedBox(height: 36),

        // Security Tagline
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.verified_user_outlined, size: 15, color: _textSecondary),
            SizedBox(width: 6),
            Text(
              "ARROZ System Secured Portal",
              style: TextStyle(
                color: _textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
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
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff0F172A).withOpacity(0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(
          color: _textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: _textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            icon,
            color: _textSecondary.withOpacity(0.7),
            size: 22,
          ),
          suffixIcon: suffixIcon,
          floatingLabelStyle: const TextStyle(
            color: _primary,
            fontWeight: FontWeight.w700,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _border, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primary, width: 1.8),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _isLoading ? null : onPressed,
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .2,
                ),
              ),
      ),
    );
  }
}