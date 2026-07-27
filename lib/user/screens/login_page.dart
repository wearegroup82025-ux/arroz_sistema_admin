import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth.service.dart';
import 'homeuser_page.dart';
import 'registeruser_page.dart';

class ArrozTheme {
  static const Color primary = Color(0xFF0F5132); // Deep Emerald
  static const Color primaryLight = Color(0xFF2D8A56);
  static const Color accent = Color(0xFFD1E7DD); // Soft Mint
  static const Color bg = Color(0xFFFBFBF9); // Eye-friendly background
  static const Color cardBg = Colors.white;
  static const Color textMain = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706); // Warm Amber
}

class LoginUserPage extends StatefulWidget {
  const LoginUserPage({super.key});

  @override
  State<LoginUserPage> createState() => _LoginUserPageState();
}

class _LoginUserPageState extends State<LoginUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String _currentLanguage = 'Tagalog';

  int _failedAttempts = 0;
  DateTime? _lockoutTime;

  final Map<String, Map<String, String>> _txt = {
    'English': {
      'subtitle': 'Modern Agriculture Platform',
      'email': 'Email Address',
      'password': 'Password',
      'forgotPwd': 'Forgot Password?',
      'btnLogin': 'Sign In',
      'noAccount': 'New to Arroz? ',
      'joinHere': 'Create Account',
      'valEmail': 'Please enter a valid email address',
      'valPassword': 'Password is required',
      'forgotTitle': 'Reset Password',
      'forgotSub': 'Choose how you want to search and reset your account password:',
      'forgotSearch': 'SEARCH ACCOUNT',
      'lockoutMsg': 'Too many failed attempts. Try again in 2 minutes.',
      'errorAuth': 'Invalid email or password. Please check and try again.',
      'connErr': 'Unable to connect. Please check your internet.',
      'searchHintEmail': 'Enter registered Email Address',
      'searchHintPhone': 'Enter registered Mobile Number (e.g. 09123456789)',
      'accNotFoundTitle': 'Account Not Found',
      'accNotFoundSub': 'We couldn\'t find any Arroz account linked to that info.',
      'emptySearchWarn': 'Please enter your registered email or mobile number.',
      'chooseMethod': 'How do you want to receive your OTP verification code?',
      'sendEmailLink': 'Send OTP to Email',
      'sendSmsOtp': 'Send OTP via SMS',
      'continueBtn': 'SEND OTP CODE',
      'enterOtpTitle': 'Enter 6-Digit OTP',
      'enterOtpSub': 'Enter the verification code sent to ',
      'verifyOtpBtn': 'VERIFY OTP',
      'invalidOtpTitle': 'Invalid Verification Code',
      'invalidOtpSub': 'The OTP code you entered is incorrect or expired. Please check and try again.',
      'newPassTitle': 'Set New Password',
      'newPassSub': 'Create a strong new password for your account.',
      'newPassHint': 'New Password',
      'confirmPassHint': 'Confirm Password',
      'savePassBtn': 'UPDATE PASSWORD',
      'passNotMatchTitle': 'Passwords Do Not Match',
      'passNotMatchSub': 'Please ensure both password fields are identical.',
      'passSuccessTitle': 'Password Reset Successful!',
      'passSuccessSub': 'Your password has been updated. You can now login using your new credentials.',
      'ruleLength': 'At least 8 characters long',
      'ruleNumber': 'Contains at least 1 number (0-9)',
      'ruleSpecial': 'Contains at least 1 special character (!@#\$%^&*)',
      'btnUnderstand': 'I Understand',
      'btnTryAgain': 'Try Again',
      'btnOk': 'OK',
      'useEmailOption': 'Via Email Address',
      'usePhoneOption': 'Via Mobile Number',
    },
    'Tagalog': {
      'subtitle': 'Sistema para sa Modernong Magsasaka',
      'email': 'Email Address',
      'password': 'Password',
      'forgotPwd': 'Nakalimutan ang Password?',
      'btnLogin': 'Mag-login',
      'noAccount': 'Bago ka ba sa Arroz? ',
      'joinHere': 'Gumawa ng Account',
      'valEmail': 'Ilagay ang iyong tamang email address',
      'valPassword': 'Kailangan ang password',
      'forgotTitle': 'I-reset ang Password',
      'forgotSub': 'Pumili ng paraan kung paano mo gustong hanapin at i-reset ang iyong password:',
      'forgotSearch': 'HANAPIN ANG ACCOUNT',
      'lockoutMsg': 'Masyadong maraming subok. Maghintay muna ng 2 minuto.',
      'errorAuth': 'Maling email o password. Pakisuri at subukan ulit.',
      'connErr': 'Hindi makakonekta sa internet sa kasalukuyan.',
      'searchHintEmail': 'Ilagay ang nakarehistrong Email Address',
      'searchHintPhone': 'Ilagay ang nakarehistrong Mobile Number (hal. 09123456789)',
      'accNotFoundTitle': 'Walang Nahanap na Account',
      'accNotFoundSub': 'Walang nakatagong Arroz account na nakarehistro sa impormasyong ito.',
      'emptySearchWarn': 'Mangyaring maglagay ng email address o numero ng cellphone.',
      'chooseMethod': 'Paano mo gustong matanggap ang iyong OTP verification code?',
      'sendEmailLink': 'Ipadala ang OTP sa Email',
      'sendSmsOtp': 'Ipadala ang OTP sa SMS',
      'continueBtn': 'IPADALA ANG OTP',
      'enterOtpTitle': 'Ilagay ang 6-Digit OTP',
      'enterOtpSub': 'Ilagay ang code na ipinadala sa ',
      'verifyOtpBtn': 'I-VERIFY ANG OTP',
      'invalidOtpTitle': 'Maling OTP Code',
      'invalidOtpSub': 'Ang OTP code na inilagay mo ay mali o expired na. Pakisuri at subukang muli.',
      'newPassTitle': 'Gumawa ng Bagong Password',
      'newPassSub': 'Maglagay ng matatag na bagong password para sa iyong account.',
      'newPassHint': 'Bagong Password',
      'confirmPassHint': 'Kumpirmahin ang Password',
      'savePassBtn': 'I-UPDATE ANG PASSWORD',
      'passNotMatchTitle': 'Hindi Magkatugma ang Password',
      'passNotMatchSub': 'Siguraduhing pareho ang inilagay na password sa dalawang field.',
      'passSuccessTitle': 'Tagumpay ang Pag-reset!',
      'passSuccessSub': 'Na-update na ang iyong password. Maaari ka nang mag-login gamit ang bagong password.',
      'ruleLength': 'Hindi bababa sa 8 characters',
      'ruleNumber': 'Mayroong kahit 1 numero (0-9)',
      'ruleSpecial': 'Mayroong kahit 1 special character (!@#\$%^&*)',
      'btnUnderstand': 'Naintindihan Ko',
      'btnTryAgain': 'Subukang Muli',
      'btnOk': 'Sige',
      'useEmailOption': 'Gamit ang Email Address',
      'usePhoneOption': 'Gamit ang Mobile Number',
    }
  };

  void _showCustomWarningDialog({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String buttonText,
    VoidCallback? onPressed,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ArrozTheme.textMain),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: ArrozTheme.textMuted, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: onPressed ?? () => Navigator.pop(ctx),
                  child: Text(
                    buttonText,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _normalizePhoneNumber(String raw) {
    String cleaned = raw.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('09')) return '+63${cleaned.substring(1)}';
    if (cleaned.startsWith('9') && cleaned.length == 10) return '+63$cleaned';
    if (cleaned.startsWith('639')) return '+$cleaned';
    return raw;
  }

  String _maskEmail(String email) {
    if (!email.contains('@')) return email;
    final parts = email.split('@');
    final name = parts[0];
    if (name.length <= 2) return "${name[0]}***@${parts[1]}";
    return "${name[0]}***${name[name.length - 1]}@${parts[1]}";
  }

  String _maskPhone(String phone) {
    if (phone.length < 7) return phone;
    return "${phone.substring(0, 4)}****${phone.substring(phone.length - 3)}";
  }

  void _openForgotPasswordSheet() {
    final searchController = TextEditingController();
    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    int currentStep = 1;
    bool isProcessing = false;
    bool obscureNew = true;
    bool obscureConfirm = true;

    // Timer States
    Timer? resendTimer;
    int timerSeconds = 60;
    bool canResend = false;

    // Real-time password validations
    bool hasMin8 = false;
    bool hasDigit = false;
    bool hasSpecial = false;

    Map<String, dynamic>? foundUserData;
    String selectedMethod = 'email'; // 'email' o 'sms'
    String targetAddress = '';

    final localized = _txt[_currentLanguage]!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {

            void startResendTimer() {
              resendTimer?.cancel();
              setSheetState(() {
                timerSeconds = 60;
                canResend = false;
              });

              resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
                if (timerSeconds > 0) {
                  setSheetState(() {
                    timerSeconds--;
                  });
                } else {
                  setSheetState(() {
                    canResend = true;
                  });
                  timer.cancel();
                }
              });
            }

            Future<void> resendOtpCode() async {
              setSheetState(() => isProcessing = true);
              try {
                if (selectedMethod == 'email') {
                  await AuthService.instance.generateAndSaveEmailOTP(
                    email: targetAddress,
                    name: foundUserData!['name'] ?? 'User',
                    reason: "Password Reset",
                  );
                } else {
                  await AuthService.instance.sendPhoneOTPWithTextBee(phoneNumber: targetAddress);
                }
                _showSnackBar(_currentLanguage == 'Tagalog' ? "Naipadala nang muli ang OTP code!" : "OTP code resent successfully!", Colors.green.shade700);
                startResendTimer();
              } catch (e) {
                _showSnackBar(localized['connErr']!, ArrozTheme.error);
              } finally {
                setSheetState(() => isProcessing = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: ArrozTheme.cardBg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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

                      // STEP 1: MAMILI MUNA KUNG EMAIL O MOBILE NUMBER
                      if (currentStep == 1) ...[
                        Text(localized['forgotTitle']!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ArrozTheme.textMain)),
                        const SizedBox(height: 6),
                        Text(localized['forgotSub']!, style: const TextStyle(color: ArrozTheme.textMuted, fontSize: 13, height: 1.4)),
                        const SizedBox(height: 20),

                        // Selection Switcher (Email vs Mobile)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: ArrozTheme.bg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setSheetState(() {
                                      selectedMethod = 'email';
                                      searchController.clear();
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: selectedMethod == 'email' ? ArrozTheme.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.email_outlined, size: 18, color: selectedMethod == 'email' ? Colors.white : ArrozTheme.textMuted),
                                        const SizedBox(width: 6),
                                        Text(
                                          localized['useEmailOption']!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: selectedMethod == 'email' ? Colors.white : ArrozTheme.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setSheetState(() {
                                      selectedMethod = 'sms';
                                      searchController.clear();
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: selectedMethod == 'sms' ? ArrozTheme.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.phone_android_outlined, size: 18, color: selectedMethod == 'sms' ? Colors.white : ArrozTheme.textMuted),
                                        const SizedBox(width: 6),
                                        Text(
                                          localized['usePhoneOption']!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: selectedMethod == 'sms' ? Colors.white : ArrozTheme.textMuted,
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

                        const SizedBox(height: 16),

                        TextField(
                          controller: searchController,
                          keyboardType: selectedMethod == 'email' ? TextInputType.emailAddress : TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: selectedMethod == 'email' ? localized['searchHintEmail'] : localized['searchHintPhone'],
                            hintStyle: const TextStyle(fontSize: 13, color: ArrozTheme.textMuted),
                            prefixIcon: Icon(selectedMethod == 'email' ? Icons.email_outlined : Icons.phone_android_outlined, color: ArrozTheme.primary),
                            filled: true,
                            fillColor: ArrozTheme.bg,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: ArrozTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                            onPressed: isProcessing ? null : () async {
                              final query = searchController.text.trim();

                              if (query.isEmpty) {
                                _showCustomWarningDialog(
                                  context: context,
                                  title: _currentLanguage == 'Tagalog' ? "May Kulang" : "Missing Info",
                                  description: localized['emptySearchWarn']!,
                                  icon: Icons.error_outline_rounded,
                                  color: ArrozTheme.warning,
                                  buttonText: localized['btnUnderstand']!,
                                );
                                return;
                              }

                              setSheetState(() => isProcessing = true);

                              try {
                                DocumentSnapshot? userDoc;

                                if (selectedMethod == 'email') {
                                  final emailQuery = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: query).get();
                                  if (emailQuery.docs.isNotEmpty) userDoc = emailQuery.docs.first;
                                } else {
                                  final normalizedPhone = _normalizePhoneNumber(query);
                                  final phoneQuery = await FirebaseFirestore.instance.collection('users').where('phone', isEqualTo: query).get();
                                  final normPhoneQuery = await FirebaseFirestore.instance.collection('users').where('phone', isEqualTo: normalizedPhone).get();

                                  if (phoneQuery.docs.isNotEmpty) userDoc = phoneQuery.docs.first;
                                  else if (normPhoneQuery.docs.isNotEmpty) userDoc = normPhoneQuery.docs.first;
                                }

                                if (userDoc == null || !userDoc.exists) {
                                  if (context.mounted) {
                                    _showCustomWarningDialog(
                                      context: context,
                                      title: localized['accNotFoundTitle']!,
                                      description: localized['accNotFoundSub']!,
                                      icon: Icons.person_off_rounded,
                                      color: ArrozTheme.error,
                                      buttonText: localized['btnTryAgain']!,
                                    );
                                  }
                                } else {
                                  foundUserData = userDoc.data() as Map<String, dynamic>;

                                  if (selectedMethod == 'email') {
                                    targetAddress = foundUserData!['email'] ?? '';
                                    await AuthService.instance.generateAndSaveEmailOTP(
                                      email: targetAddress,
                                      name: foundUserData!['name'] ?? 'User',
                                      reason: "Password Reset",
                                    );
                                  } else {
                                    targetAddress = _normalizePhoneNumber(foundUserData!['phone'] ?? '');
                                    await AuthService.instance.sendPhoneOTPWithTextBee(phoneNumber: targetAddress);
                                  }

                                  setSheetState(() {
                                    currentStep = 3; // Diretso agad sa OTP Verification
                                  });
                                  startResendTimer();
                                }
                              } catch (e) {
                                if (context.mounted) _showSnackBar(localized['connErr']!, ArrozTheme.error);
                              } finally {
                                setSheetState(() => isProcessing = false);
                              }
                            },
                            child: isProcessing
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(localized['forgotSearch']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ),
                      ]

                      // STEP 3: VERIFY OTP CODE (WITH TIMER & RESEND CODE)
                      else if (currentStep == 3) ...[
                        Text(localized['enterOtpTitle']!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ArrozTheme.textMain)),
                        const SizedBox(height: 6),
                        Text("${localized['enterOtpSub']!}${selectedMethod == 'email' ? _maskEmail(targetAddress) : _maskPhone(targetAddress)}", style: const TextStyle(color: ArrozTheme.textMuted, fontSize: 13, height: 1.4)),
                        const SizedBox(height: 20),
                        TextField(
                          controller: otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold, color: ArrozTheme.primary),
                          decoration: InputDecoration(
                            counterText: "",
                            filled: true, fillColor: ArrozTheme.bg,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // COUNTDOWN TIMER & RESEND CODE SECTION
                        Center(
                          child: Column(
                            children: [
                              if (!canResend)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.timer_outlined, size: 16, color: ArrozTheme.textMuted),
                                    const SizedBox(width: 6),
                                    Text(
                                      _currentLanguage == 'Tagalog'
                                          ? "Maaaring mag-resend sa ${timerSeconds}s"
                                          : "Resend available in ${timerSeconds}s",
                                      style: const TextStyle(fontSize: 13, color: ArrozTheme.textMuted, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                )
                              else
                                TextButton(
                                  onPressed: isProcessing ? null : resendOtpCode,
                                  child: Text(
                                    _currentLanguage == 'Tagalog'
                                        ? "Ipadala Muli ang Code (Resend OTP)"
                                        : "Resend OTP Code",
                                    style: const TextStyle(
                                      color: ArrozTheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity, height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: ArrozTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                            onPressed: isProcessing ? null : () async {
                              final typedOtp = otpController.text.trim();
                              if (typedOtp.length < 6) return;

                              setSheetState(() => isProcessing = true);
                              try {
                                bool isValid = false;
                                if (selectedMethod == 'email') {
                                  isValid = await AuthService.instance.verifyEmailOTP(email: targetAddress, typedOtp: typedOtp);
                                } else {
                                  isValid = await AuthService.instance.verifyPhoneOTP(phoneNumber: targetAddress, typedOtp: typedOtp);
                                }

                                if (isValid) {
                                  resendTimer?.cancel();
                                  setSheetState(() => currentStep = 4);
                                } else {
                                  if (context.mounted) {
                                    _showCustomWarningDialog(
                                      context: context,
                                      title: localized['invalidOtpTitle']!,
                                      description: localized['invalidOtpSub']!,
                                      icon: Icons.shield_outlined,
                                      color: ArrozTheme.error,
                                      buttonText: localized['btnTryAgain']!,
                                    );
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) _showSnackBar(localized['connErr']!, ArrozTheme.error);
                              } finally {
                                setSheetState(() => isProcessing = false);
                              }
                            },
                            child: isProcessing
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(localized['verifyOtpBtn']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ),
                      ]

                      // STEP 4: SET NEW PASSWORD
                      else if (currentStep == 4) ...[
                          Text(localized['newPassTitle']!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ArrozTheme.textMain)),
                          const SizedBox(height: 6),
                          Text(localized['newPassSub']!, style: const TextStyle(color: ArrozTheme.textMuted, fontSize: 13, height: 1.4)),
                          const SizedBox(height: 20),

                          TextField(
                            controller: newPasswordController,
                            obscureText: obscureNew,
                            onChanged: (val) {
                              setSheetState(() {
                                hasMin8 = val.length >= 8;
                                hasDigit = val.contains(RegExp(r'\d'));
                                hasSpecial = val.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>\-_=+]'));
                              });
                            },
                            decoration: InputDecoration(
                              labelText: localized['newPassHint'],
                              prefixIcon: const Icon(Icons.lock_outline_rounded, color: ArrozTheme.primary),
                              suffixIcon: IconButton(
                                icon: Icon(obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: ArrozTheme.textMuted),
                                onPressed: () => setSheetState(() => obscureNew = !obscureNew),
                              ),
                              filled: true, fillColor: ArrozTheme.bg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 12),

                          TextField(
                            controller: confirmPasswordController,
                            obscureText: obscureConfirm,
                            decoration: InputDecoration(
                              labelText: localized['confirmPassHint'],
                              prefixIcon: const Icon(Icons.lock_reset_rounded, color: ArrozTheme.primary),
                              suffixIcon: IconButton(
                                icon: Icon(obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: ArrozTheme.textMuted),
                                onPressed: () => setSheetState(() => obscureConfirm = !obscureConfirm),
                              ),
                              filled: true, fillColor: ArrozTheme.bg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 16),

                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: ArrozTheme.bg, borderRadius: BorderRadius.circular(14)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildRuleItem(localized['ruleLength']!, hasMin8),
                                const SizedBox(height: 6),
                                _buildRuleItem(localized['ruleNumber']!, hasDigit),
                                const SizedBox(height: 6),
                                _buildRuleItem(localized['ruleSpecial']!, hasSpecial),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity, height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: ArrozTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                              onPressed: isProcessing ? null : () async {
                                final pass = newPasswordController.text.trim();
                                final confirmPass = confirmPasswordController.text.trim();

                                if (pass != confirmPass) {
                                  _showCustomWarningDialog(
                                    context: context,
                                    title: localized['passNotMatchTitle']!,
                                    description: localized['passNotMatchSub']!,
                                    icon: Icons.password_rounded,
                                    color: ArrozTheme.warning,
                                    buttonText: localized['btnUnderstand']!,
                                  );
                                  return;
                                }

                                if (!hasMin8 || !hasDigit || !hasSpecial) {
                                  _showCustomWarningDialog(
                                    context: context,
                                    title: _currentLanguage == 'Tagalog' ? "Babalala sa Password Rules" : "Password Rules Warning",
                                    description: _currentLanguage == 'Tagalog'
                                        ? "Mangyaring sundin ang lahat ng patakaran sa password bago magpatuloy."
                                        : "Please make sure your password satisfies all requirements.",
                                    icon: Icons.security_rounded,
                                    color: ArrozTheme.warning,
                                    buttonText: localized['btnUnderstand']!,
                                  );
                                  return;
                                }

                                setSheetState(() => isProcessing = true);
                                try {
                                  final uid = foundUserData!['uid'];
                                  await FirebaseFirestore.instance.collection('users').doc(uid).update({
                                    'passwordUpdated': FieldValue.serverTimestamp(),
                                  });

                                  if (context.mounted) {
                                    Navigator.pop(context);

                                    _showCustomWarningDialog(
                                      context: context,
                                      title: localized['passSuccessTitle']!,
                                      description: localized['passSuccessSub']!,
                                      icon: Icons.check_circle_rounded,
                                      color: Colors.green.shade700,
                                      buttonText: localized['btnOk']!,
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) _showSnackBar(localized['connErr']!, ArrozTheme.error);
                                } finally {
                                  setSheetState(() => isProcessing = false);
                                }
                              },
                              child: isProcessing
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Text(localized['savePassBtn']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ),
                        ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      resendTimer?.cancel();
    });
  }

  Widget _buildRuleItem(String text, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle_rounded : Icons.cancel_rounded,
          size: 18,
          color: isMet ? Colors.green.shade700 : Colors.grey.shade400,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isMet ? FontWeight.bold : FontWeight.normal,
              color: isMet ? ArrozTheme.textMain : ArrozTheme.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogin() async {
    final localized = _txt[_currentLanguage]!;

    if (_lockoutTime != null && DateTime.now().difference(_lockoutTime!).inMinutes < 2) {
      _showCustomWarningDialog(
        context: context,
        title: "Account Locked Temporarily",
        description: localized['lockoutMsg']!,
        icon: Icons.lock_clock_rounded,
        color: ArrozTheme.error,
        buttonText: localized['btnUnderstand']!,
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      _failedAttempts = 0;
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeUserPage()));
    } on FirebaseAuthException catch (_) {
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        _lockoutTime = DateTime.now();
        _showCustomWarningDialog(
          context: context,
          title: "Account Locked Temporarily",
          description: localized['lockoutMsg']!,
          icon: Icons.lock_clock_rounded,
          color: ArrozTheme.error,
          buttonText: localized['btnUnderstand']!,
        );
      } else {
        _showCustomWarningDialog(
          context: context,
          title: "Maling Credentials",
          description: localized['errorAuth']!,
          icon: Icons.no_accounts_rounded,
          color: ArrozTheme.error,
          buttonText: localized['btnTryAgain']!,
        );
      }
    } catch (e) {
      _showSnackBar(localized['connErr']!, ArrozTheme.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localized = _txt[_currentLanguage]!;

    return Scaffold(
      backgroundColor: ArrozTheme.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: ArrozTheme.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _currentLanguage,
                            style: const TextStyle(color: ArrozTheme.textMain, fontWeight: FontWeight.w600, fontSize: 13),
                            onChanged: (v) => setState(() => _currentLanguage = v!),
                            items: ['Tagalog', 'English'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: ArrozTheme.primary,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(color: ArrozTheme.primary.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: const Icon(Icons.eco_rounded, size: 38, color: ArrozTheme.accent),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text("ARROZ", textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: ArrozTheme.primary, letterSpacing: 2)),
                    Text(localized['subtitle']!, textAlign: TextAlign.center, style: const TextStyle(color: ArrozTheme.textMuted, fontSize: 13)),
                    const SizedBox(height: 32),

                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: ArrozTheme.cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: ArrozTheme.textMain, fontWeight: FontWeight.w500),
                            decoration: _inputDecoration(localized['email']!, Icons.mail_outline_rounded),
                            validator: (v) => (v == null || !v.contains('@')) ? localized['valEmail'] : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: ArrozTheme.textMain, fontWeight: FontWeight.w500),
                            decoration: _inputDecoration(localized['password']!, Icons.lock_outline_rounded).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: ArrozTheme.textMuted, size: 20),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? localized['valPassword'] : null,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _openForgotPasswordSheet,
                              child: Text(localized['forgotPwd']!, style: const TextStyle(color: ArrozTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ArrozTheme.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Text(localized['btnLogin']!, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(localized['noAccount']!, style: const TextStyle(color: ArrozTheme.textMuted, fontSize: 13)),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RegisterUserPage(initialLanguage: _currentLanguage),
                              ),
                            );
                          },
                          child: Text(localized['joinHere']!, style: const TextStyle(color: ArrozTheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: ArrozTheme.textMuted, fontSize: 13),
      prefixIcon: Icon(icon, color: ArrozTheme.primary, size: 20),
      filled: true,
      fillColor: ArrozTheme.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: ArrozTheme.primary, width: 1.5)),
    );
  }
}