import 'package:flutter/material.dart';
import '../../services/auth.service.dart';
import 'verify_otp_page.dart';

class ArrozTheme {
  static const Color primary = Color(0xFF0F5132);
  static const Color primaryLight = Color(0xFF2D8A56);
  static const Color accent = Color(0xFFD1E7DD);
  static const Color bg = Color(0xFFFBFBF9);
  static const Color cardBg = Colors.white;
  static const Color textMain = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);
  static const Color error = Color(0xFFDC2626);
}

class RegisterUserPage extends StatefulWidget {
  final String initialLanguage;

  const RegisterUserPage({super.key, this.initialLanguage = 'Tagalog'});

  @override
  State<RegisterUserPage> createState() => _RegisterUserPageState();
}

class _RegisterUserPageState extends State<RegisterUserPage> {
  int _selectedMethodIndex = 0; // 0 = Email, 1 = Phone
  final _formKey = GlobalKey<FormState>();
  late String _currentLanguage;

  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;

  bool _hasMinLength = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  final Map<String, Map<String, String>> _localizedText = {
    'English': {
      'langLabel': 'Language: ',
      'title': 'Create Account',
      'subtitle': 'Choose your preferred method to verify your account.',
      'modeEmail': 'Using Email',
      'modePhone': 'Using Phone',
      'email': 'Email Address',
      'password': 'Password',
      'confirmPassword': 'Repeat Password',
      'phone': 'Cellphone Number',
      'phoneHint': 'Example: 09123456789',
      'rule1': 'At least 8 characters or numbers',
      'rule2': 'At least one number (0-9)',
      'rule3': 'At least one symbol (e.g., @, #, \$)',
      'btnRegister': 'CREATE ACCOUNT',
      'termsText': 'I agree to the ',
      'termsLink': 'Terms & Privacy Policy',
      'termsModalTitle': 'Terms of Service & Privacy Policy',
      'termsModalBody': '''
WELCOME TO ARROZ AGRICULTURAL MANAGEMENT SYSTEM

1. DATA COLLECTION & PRIVACY
By registering, you consent to the collection and processing of your contact details in compliance with applicable Data Privacy laws. Your data is strictly used for account verification and system updates.

2. ACCOUNT SECURITY & RESPONSIBILITY
You are responsible for maintaining the confidentiality of your credentials. Any activity performed under your registered account shall be deemed your responsibility.

3. ACCEPTABLE USE
You agree not to submit false identification details, disrupt platform security, or attempt unauthorized access to Arroz system resources.
''',
      'termsAgreeBtn': 'I AGREE & CONTINUE',
      'termsDeclineBtn': 'CANCEL',
      'valEmail': 'Enter a valid email address',
      'valPassword': 'Do not leave password blank',
      'valConfirm': 'Passwords do not match',
      'valPhone': 'Enter a valid 11-digit cellphone number',
      'valTerms': 'You must accept the Terms & Privacy Policy to proceed.',
      'pwdAlert': 'Please follow all password security requirements.',
      'successEmail': 'Verification code sent to your email.',
      'successPhone': 'SMS verification code sent to your phone.',
      'errorConn': 'Unable to send OTP. Please check the email or phone number.',
    },
    'Tagalog': {
      'langLabel': 'Wika: ',
      'title': 'Gumawa ng Account',
      'subtitle': 'Pumili ng paraan upang mai-verify ang iyong account.',
      'modeEmail': 'Gamit ang Email',
      'modePhone': 'Gamit ang Numero',
      'email': 'Email Address',
      'password': 'Password',
      'confirmPassword': 'Ulitin ang Password',
      'phone': 'Numero ng Cellphone',
      'phoneHint': 'Halimbawa: 09123456789',
      'rule1': 'Hindi bababa sa 8 letra o numero',
      'rule2': 'May kahit isang numero (0-9)',
      'rule3': 'May special symbol (hal. @, #, \$)',
      'btnRegister': 'MAG-REGISTER NGAYON',
      'termsText': 'Sumasang-ayon ako sa ',
      'termsLink': 'Terms & Privacy Policy',
      'termsModalTitle': 'Mga Tuntunin at Privacy Policy',
      'termsModalBody': '''
MALIGAYANG DATANG SA ARROZ AGRICULTURAL MANAGEMENT SYSTEM

1. PANGONGOLEKTA NG DATOS AT PRIVACY
Sa pagrehistro, nagbibigay ka ng pahintulot sa pagproseso ng iyong contact details ayon sa umiiral na Data Privacy laws. Ang iyong datos ay gagamitin lamang para sa beripikasyon at mga mahalagang abiso.

2. SEGURIDAD NG ACCOUNT
Tungkulin mong ingatan ang pagiging kumpidensyal ng iyong password at credentials. Ang anumang aktibidad sa iyong account ay ituturing na iyong responsibilidad.

3. MGA HINDI PINAHIHINTULUTAN
Bawal ang paglalagay ng pekeng impormasyon, pagsubok na sirain ang seguridad ng system, o paggamit ng Arroz sa anumang ilegal na paraan.
''',
      'termsAgreeBtn': 'SUMASANG-AYON AKO',
      'termsDeclineBtn': 'KANSELAHIN',
      'valEmail': 'Gumamit ng tamang email format',
      'valPassword': 'Huwag iwanang blangko ang password',
      'valConfirm': 'Hindi magkatugma ang password',
      'valPhone': 'Ilagay ang tamang 11-digit cellphone number',
      'valTerms': 'Kailangan mong sumang-ayon sa Terms & Privacy Policy.',
      'pwdAlert': 'Mangyaring sundin ang password rules para sa iyong seguridad.',
      'successEmail': 'Napadala na ang verification code sa iyong email.',
      'successPhone': 'Napadala na ang SMS code sa iyong cellphone.',
      'errorConn': 'Hindi maipadala ang OTP. Pakisuri ang email o numero.',
    }
  };

  @override
  void initState() {
    super.initState();
    _currentLanguage = widget.initialLanguage;
    _passwordController.addListener(_checkPasswordRules);
  }

  void _checkPasswordRules() {
    final pass = _passwordController.text;
    setState(() {
      _hasMinLength = pass.length >= 8;
      _hasNumber = pass.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = pass.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  String _cleanInput(String input) {
    return input.replaceAll(RegExp(r"[<>'{}\[\]\\;]"), "").trim();
  }

  void _showTermsDialog() {
    final txt = _localizedText[_currentLanguage]!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.80,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              txt['termsModalTitle']!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ArrozTheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  txt['termsModalBody']!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: ArrozTheme.textMain,
                    height: 1.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      txt['termsDeclineBtn']!,
                      style: const TextStyle(color: ArrozTheme.textMuted, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ArrozTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      setState(() => _acceptedTerms = true);
                      Navigator.pop(context);
                    },
                    child: Text(
                      txt['termsAgreeBtn']!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRegistration() async {
    final txt = _localizedText[_currentLanguage]!;

    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedTerms) {
      _showNotification(txt['valTerms']!, Colors.orange.shade800);
      return;
    }

    if (_selectedMethodIndex == 0 && (!_hasMinLength || !_hasNumber || !_hasSpecialChar)) {
      _showNotification(txt['pwdAlert']!, Colors.orange.shade800);
      return;
    }

    setState(() => _loading = true);

    final email = _cleanInput(_emailController.text);
    final phone = _cleanInput(_phoneController.text);
    final password = _passwordController.text;

    try {
      if (_selectedMethodIndex == 0) {
        // 1. Subukang i-validate at ipadala ang OTP gamit ang 10-second guard
        await AuthService.instance.generateAndSaveEmailOTP(
          email: email, 
          name: email,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception("Hindi maabot ang email address. Pakisuri ang internet o ang email.");
          },
        );

        if (!mounted) return;
        _showNotification(txt['successEmail']!, Colors.green.shade700);

        // 2. LILIPAT LAMANG DITO KAPAG WALANG ANUMANG ERROR
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyOtpPage(
              phoneNumber: email,
              verificationId: 'EMAIL_AUTH_MODE',
              isEmailMode: true,
              passwordForEmail: password,
              name: email,
              phone: "N/A",
              address: "N/A",
            ),
          ),
        );
      } else {
        String formattedPhone = phone;
        if (phone.startsWith('0')) {
          formattedPhone = '+63${phone.substring(1)}';
        } else if (!phone.startsWith('+')) {
          formattedPhone = '+63$phone';
        }

        await AuthService.instance.sendPhoneOTPWithSemaphore(phoneNumber: formattedPhone).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception("Hindi maipadala ang SMS. Pakisuri ang numero.");
          },
        );

        if (!mounted) return;
        _showNotification(txt['successPhone']!, Colors.green.shade700);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyOtpPage(
              phoneNumber: formattedPhone,
              verificationId: 'PHONE_TEXTBEE_MODE',
              isEmailMode: false,
              name: formattedPhone,
              phone: formattedPhone,
              address: "N/A",
            ),
          ),
        );
      }
    } catch (e) {
      // 3. KAPAG MAY ERROR (pekeng email, existing account, bounce), PAPASOK DITO AT HARANG AGAD!
      String errorMsg = e.toString().replaceAll("Exception: ", "").trim();
      if (errorMsg.isEmpty) {
        errorMsg = txt['errorConn']!;
      }
      
      _showNotification(errorMsg, ArrozTheme.error);
    } finally {
      // 4. Ibalik ang button sa active state
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showNotification(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message, 
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.removeListener(_checkPasswordRules);
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txt = _localizedText[_currentLanguage]!;

    return Scaffold(
      backgroundColor: ArrozTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ArrozTheme.textMain, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: ArrozTheme.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _currentLanguage,
                style: const TextStyle(color: ArrozTheme.textMain, fontWeight: FontWeight.bold, fontSize: 12),
                onChanged: (v) => setState(() => _currentLanguage = v!),
                items: ['Tagalog', 'English'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(txt['title']!, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: ArrozTheme.primary)),
                    const SizedBox(height: 4),
                    Text(txt['subtitle']!, style: const TextStyle(fontSize: 13, color: ArrozTheme.textMuted)),
                    const SizedBox(height: 24),

                    // Method Selector (Email or Phone)
                    Container(
                      height: 48,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: _buildTabButton(txt['modeEmail']!, 0)),
                          Expanded(child: _buildTabButton(txt['modePhone']!, 1)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_selectedMethodIndex == 0) ...[
                      _buildInputField(
                        controller: _emailController,
                        label: txt['email']!,
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return txt['valEmail'];
                          final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          return !emailRegExp.hasMatch(v.trim()) ? txt['valEmail'] : null;
                        },
                      ),
                      _buildInputField(
                        controller: _passwordController,
                        label: txt['password']!,
                        icon: Icons.lock_open_rounded,
                        obscure: _obscurePassword,
                        toggle: () => setState(() => _obscurePassword = !_obscurePassword),
                        validator: (v) => v!.isEmpty ? txt['valPassword'] : null,
                      ),

                      // Password Safety Rules Indicator
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16, left: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSecurityIndicator(txt['rule1']!, _hasMinLength),
                            _buildSecurityIndicator(txt['rule2']!, _hasNumber),
                            _buildSecurityIndicator(txt['rule3']!, _hasSpecialChar),
                          ],
                        ),
                      ),

                      _buildInputField(
                        controller: _confirmPasswordController,
                        label: txt['confirmPassword']!,
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscureConfirmPassword,
                        toggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        validator: (v) => v != _passwordController.text ? txt['valConfirm'] : null,
                      ),
                    ] else ...[
                      _buildInputField(
                        controller: _phoneController,
                        label: txt['phone']!,
                        icon: Icons.phone_android_rounded,
                        keyboardType: TextInputType.phone,
                        placeholder: txt['phoneHint']!,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return txt['valPhone'];
                          final cleaned = v.trim().replaceAll(RegExp(r'\D'), '');
                          return cleaned.length < 10 || cleaned.length > 11 ? txt['valPhone'] : null;
                        },
                      ),
                    ],

                    // Terms and Conditions Consent Row
                    Row(
                      children: [
                        Checkbox(
                          value: _acceptedTerms,
                          activeColor: ArrozTheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: _showTermsDialog,
                            child: RichText(
                              text: TextSpan(
                                text: txt['termsText'],
                                style: const TextStyle(color: ArrozTheme.textMuted, fontSize: 12),
                                children: [
                                  TextSpan(
                                    text: txt['termsLink'],
                                    style: const TextStyle(color: ArrozTheme.primary, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _handleRegistration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ArrozTheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(txt['btnRegister']!, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    bool isSelected = _selectedMethodIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedMethodIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected ? ArrozTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(color: isSelected ? Colors.white : ArrozTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildSecurityIndicator(String message, bool isValid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(isValid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: isValid ? ArrozTheme.primary : Colors.grey, size: 15),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(fontSize: 12, color: isValid ? ArrozTheme.textMain : ArrozTheme.textMuted))),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    VoidCallback? toggle,
    int? maxLength,
    String? placeholder,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        maxLength: maxLength,
        validator: validator,
        style: const TextStyle(color: ArrozTheme.textMain, fontWeight: FontWeight.w500, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: placeholder,
          counterText: "",
          labelStyle: const TextStyle(color: ArrozTheme.textMuted, fontSize: 13),
          prefixIcon: Icon(icon, color: ArrozTheme.primary, size: 20),
          suffixIcon: toggle != null
              ? IconButton(
                  icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: ArrozTheme.textMuted, size: 20),
                  onPressed: toggle,
                )
              : null,
          filled: true,
          fillColor: ArrozTheme.cardBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: ArrozTheme.primary, width: 1.5)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: ArrozTheme.error)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: ArrozTheme.error, width: 1.5)),
        ),
      ),
    );
  }
}