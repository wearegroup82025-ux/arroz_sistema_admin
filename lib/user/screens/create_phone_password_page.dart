import 'package:flutter/material.dart';
import '../../services/auth.service.dart';
import 'homeuser_page.dart';

class CreatePhonePasswordPage extends StatefulWidget {
  final String phoneNumber;

  const CreatePhonePasswordPage({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<CreatePhonePasswordPage> createState() =>
      _CreatePhonePasswordPageState();
}

class _CreatePhonePasswordPageState extends State<CreatePhonePasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  // State Notifiers para sa visibility toggles
  final ValueNotifier<bool> _hidePassword = ValueNotifier(true);
  final ValueNotifier<bool> _hideConfirm = ValueNotifier(true);

  // Validation States
  bool _hasMinLength = false;
  bool _hasNumber = false;
  bool _hasSpecial = false;

  bool get _isPasswordValid => _hasMinLength && _hasNumber && _hasSpecial;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);
  }

  void _validatePassword() {
    final pass = _passwordController.text;
    final minLength = pass.length >= 8;
    final hasNum = RegExp(r'[0-9]').hasMatch(pass);
    final hasSpec = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pass);

    if (_hasMinLength != minLength ||
        _hasNumber != hasNum ||
        _hasSpecial != hasSpec) {
      setState(() {
        _hasMinLength = minLength;
        _hasNumber = hasNum;
        _hasSpecial = hasSpec;
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _hidePassword.dispose();
    _hideConfirm.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_isPasswordValid) {
      _showSnackBar("Password does not meet requirements.");
      return;
    }

    if (_passwordController.text != _confirmController.text) {
      _showSnackBar("Passwords do not match.");
      return;
    }

    try {
      await AuthService.instance.registerWithPhone(
        phoneNumber: widget.phoneNumber,
        password: _passwordController.text,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const HomeUserPage(),
        ),
            (route) => false,
      );
    } catch (e) {
      _showSnackBar(e.toString());
    }
  }

  void _showSnackBar(String message) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: theme.colorScheme.error,
        content: Text(
          message,
          style: TextStyle(color: theme.colorScheme.onError),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        // Kukunin ang eksaktong kulay na ginagamit sa button ng theme
        backgroundColor: theme.colorScheme.primary,
        iconTheme: IconThemeData(
          color: theme.colorScheme.onPrimary, // Puti o angkop na kulay ng text/icon
        ),
        title: Text(
          "Create Password",
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dynamic Title/Subtitle
              Text(
                "Set up your security",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Creating a strong password for ${widget.phoneNumber}",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 32),

              // Password Input Field
              ValueListenableBuilder<bool>(
                valueListenable: _hidePassword,
                builder: (context, isHidden, _) {
                  return TextField(
                    controller: _passwordController,
                    obscureText: isHidden,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: "Password",
                      suffixIcon: IconButton(
                        icon: Icon(
                          isHidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => _hidePassword.value = !isHidden,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Dynamic Password Indicators
              _PasswordRuleItem(
                label: "At least 8 characters",
                isSatisfied: _hasMinLength,
              ),
              _PasswordRuleItem(
                label: "At least 1 number",
                isSatisfied: _hasNumber,
              ),
              _PasswordRuleItem(
                label: "At least 1 special character",
                isSatisfied: _hasSpecial,
              ),

              const SizedBox(height: 24),

              // Confirm Password Input Field
              ValueListenableBuilder<bool>(
                valueListenable: _hideConfirm,
                builder: (context, isHidden, _) {
                  return TextField(
                    controller: _confirmController,
                    obscureText: isHidden,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handleSubmit(),
                    decoration: InputDecoration(
                      labelText: "Confirm Password",
                      suffixIcon: IconButton(
                        icon: Icon(
                          isHidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => _hideConfirm.value = !isHidden,
                      ),
                    ),
                  );
                },
              ),

              const Spacer(),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _handleSubmit,
                  child: const Text(
                    "Continue",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
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

// Modular Widget para sa Rules/Checklist
class _PasswordRuleItem extends StatelessWidget {
  final String label;
  final bool isSatisfied;

  const _PasswordRuleItem({
    required this.label,
    required this.isSatisfied,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary; // Tumutugma rin sa primary color
    final inactiveColor = theme.colorScheme.onSurface.withOpacity(0.38);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isSatisfied
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              key: ValueKey<bool>(isSatisfied),
              color: isSatisfied ? activeColor : inactiveColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: theme.textTheme.bodyMedium!.copyWith(
              color: isSatisfied ? theme.colorScheme.onSurface : inactiveColor,
              fontWeight: isSatisfied ? FontWeight.w500 : FontWeight.normal,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}