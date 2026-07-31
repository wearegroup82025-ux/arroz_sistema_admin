import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth.service.dart';
import 'homeuser_page.dart';
import 'create_phone_password_page.dart';

class ArrozTheme {
  static const Color primary = Color(0xFF0F5132); // Deep Emerald
  static const Color primaryLight = Color(0xFF2D8A56);
  static const Color accent = Color(0xFFD1E7DD); // Soft Mint
  static const Color bg = Color(0xFFFBFBF9); // Eye-friendly off-white
  static const Color cardBg = Colors.white;
  static const Color textMain = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);
  static const Color error = Color(0xFFDC2626);
}

class VerifyOtpPage extends StatefulWidget {
  final String phoneNumber; 
  final String verificationId;
  final bool isEmailMode;
  final String? passwordForEmail;
  final String? name;
  final String? phone;
  final String? address;
  final String initialLanguage;

  const VerifyOtpPage({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    this.isEmailMode = false,
    this.passwordForEmail,
    this.name,
    this.phone,
    this.address,
    this.initialLanguage = 'Tagalog',
  });

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> with WidgetsBindingObserver {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  
  bool _isLoading = false;
  int _secondsRemaining = 60;
  Timer? _timer;
  bool _canResend = false;
  late String _currentLanguage;

  final Map<String, Map<String, String>> _txt = {
    'English': {
      'title': 'Verify Your Account',
      'subEmail': 'Enter the 6-digit code sent to your email address:',
      'subPhone': 'Enter the 6-digit code sent to your phone number:',
      'resendWait': 'Resend code in ',
      'resendBtn': 'Resend OTP Code',
      'verifyBtn': 'VERIFY ACCOUNT',
      'invalidFormat': 'Invalid format. Only numbers are allowed.',
      'wrongEmailCode': 'Incorrect code. Please check the code sent to your email.',
      'wrongPhoneCode': 'Incorrect SMS code. Please check your text messages.',
      'errorVerify': 'Verification failed. Please try again.',
      'resendSuccessEmail': 'A new code has been sent to your email.',
      'resendSuccessPhone': 'A new SMS code has been sent to your phone.',
      'resendError': 'Unable to resend code at this time.',
    },
    'Tagalog': {
      'title': 'Kumpirmahin ang Account',
      'subEmail': 'Ilagay ang 6-digit code na ipinadala sa iyong email address:',
      'subPhone': 'Ilagay ang 6-digit code na ipinadala sa iyong cellphone number:',
      'resendWait': 'Maaaring magpadala muli sa loob ng ',
      'resendBtn': 'Ipadala Muli ang Code',
      'verifyBtn': 'I-VERIFY ANG ACCOUNT',
      'invalidFormat': 'Maling format. Numero lamang ang maaaring ilagay.',
      'wrongEmailCode': 'Maling code. Pakisuri ang email na pinadala.',
      'wrongPhoneCode': 'Maling SMS Code. Pakitingnan ang text message sa iyong phone.',
      'errorVerify': 'Nagkaroon ng problema sa pag-verify. Subukan muli.',
      'resendSuccessEmail': 'Bagong code ang ipinadala sa iyong email.',
      'resendSuccessPhone': 'Bagong text message ang ipinadala sa iyong phone.',
      'resendError': 'Hindi maipadala ang code sa ngayon.',
    }
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentLanguage = widget.initialLanguage;
    _startTimer();
    
    // WALANG _sendInitialOTP() DITO PARA HINDI MAGPADALA NG PANGDALAWANG OTP!
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkClipboardForCode();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboardForCode();
    }
  }

  Future<void> _checkClipboardForCode() async {
    try {
      ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null) {
        String pasted = data.text!.trim().replaceAll(RegExp(r'\D'), '');
        if (pasted.length == 6) {
          _fillCode(pasted);
        }
      }
    } catch (_) {}
  }

  void _fillCode(String code) {
    if (code.length != 6) return;
    for (int i = 0; i < 6; i++) {
      _controllers[i].text = code[i];
    }
    setState(() {});
    _verifyOTP();
  }

  void _startTimer() {
    if (!mounted) return;
    setState(() { _secondsRemaining = 60; _canResend = false; });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining == 0) {
        setState(() { _canResend = true; _timer?.cancel(); });
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  String _getCombinedCode() => _controllers.map((c) => c.text.trim()).join();

  Future<void> _verifyOTP() async {
    final localized = _txt[_currentLanguage]!;
    final typedCode = _getCombinedCode();
    if (typedCode.length < 6) return;

    if (!RegExp(r'^\d{6}$').hasMatch(typedCode)) {
      _showSnackBar(localized['invalidFormat']!, ArrozTheme.error);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.isEmailMode) {
        bool isCorrect = await AuthService.instance.verifyEmailOTP(
          email: widget.phoneNumber, 
          typedOtp: typedCode
        );

        if (isCorrect && widget.passwordForEmail != null) {
          var userCredential = await AuthService.instance.registerWithEmail(
            email: widget.phoneNumber, 
            password: widget.passwordForEmail!
          );

          await FirebaseFirestore.instance.collection("users").doc(userCredential.user!.uid).set({
            "uid": userCredential.user!.uid,
            "name": widget.name ?? "",
            "phone": widget.phone ?? "",
            "address": widget.address ?? "",
            "email": widget.phoneNumber.trim().toLowerCase(),
            "role": "user",
            "createdAt": FieldValue.serverTimestamp(),
          });

          TextInput.finishAutofillContext();
          _navigateToHome();
        } else {
          _showSnackBar(localized['wrongEmailCode']!, ArrozTheme.error);
        }
      } else {
        bool isCorrect = await AuthService.instance.verifyPhoneOTP(
          phoneNumber: widget.phoneNumber, 
          typedOtp: typedCode
        );

        if (isCorrect) {

          final password = await Navigator.push<String>(
            context,
            MaterialPageRoute(
              builder: (_) => CreatePhonePasswordPage(
                phoneNumber: widget.phoneNumber,
              ),
            ),
          );

          if (password == null) {
            setState(() => _isLoading = false);
            return;
          }

          var userCredential =
          await AuthService.instance.registerWithPhone(
            phoneNumber: widget.phoneNumber,
            password: password,
          );

          await FirebaseFirestore.instance
              .collection("users")
              .doc(userCredential.user!.uid)
              .set({
            "uid": userCredential.user!.uid,
            "name": widget.name ?? "",
            "phone": widget.phoneNumber,
            "address": widget.address ?? "",
            "email": "Registered via Cellphone Number",
            "role": "user",
            "createdAt": FieldValue.serverTimestamp(),
          });

          TextInput.finishAutofillContext();
          _navigateToHome();
        } else {
          _showSnackBar(localized['wrongPhoneCode']!, ArrozTheme.error);
        }
      }
    } catch (e) {
      debugPrint("VERIFY EXCEPTION: $e");
      _showSnackBar(localized['errorVerify']!, ArrozTheme.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeUserPage()), (route) => false);
  }

  void _resendOTP() async {
    final localized = _txt[_currentLanguage]!;
    if (!_canResend) return;
    setState(() => _isLoading = true);
    
    try {
      if (widget.isEmailMode) {
        await AuthService.instance.generateAndSaveEmailOTP(
          email: widget.phoneNumber, 
          name: widget.name ?? "User"
        );
        _showSnackBar(localized['resendSuccessEmail']!, Colors.green.shade700);
      } else {
        await AuthService.instance.sendPhoneOTPWithSemaphore(phoneNumber: widget.phoneNumber);
        _showSnackBar(localized['resendSuccessPhone']!, Colors.green.shade700);
      }
      _startTimer();
    } catch (e) {
      _showSnackBar(localized['resendError']!, ArrozTheme.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    for (var c in _controllers) { c.dispose(); }
    for (var f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localized = _txt[_currentLanguage]!;

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
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: ArrozTheme.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: ArrozTheme.primary.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: const Icon(Icons.mark_email_read_rounded, size: 36, color: ArrozTheme.primary),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(localized['title']!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: ArrozTheme.primary)),
                  const SizedBox(height: 8),
                  
                  Text(
                    widget.isEmailMode ? localized['subEmail']! : localized['subPhone']!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: ArrozTheme.textMuted, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.phoneNumber,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: ArrozTheme.textMain, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 32),

                  AutofillGroup(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(6, (index) {
                              return SizedBox(
                                width: 44,
                                height: 56,
                                child: TextFormField(
                                  controller: _controllers[index],
                                  focusNode: _focusNodes[index],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  autofillHints: const [AutofillHints.oneTimeCode],
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ArrozTheme.primary),
                                  decoration: InputDecoration(
                                    counterText: "",
                                    filled: true,
                                    fillColor: ArrozTheme.bg,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: ArrozTheme.primary, width: 2),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onChanged: (value) {
                                    // Pagsalo kung nag-paste ng buong 6-digit code
                                    String cleanValue = value.replaceAll(RegExp(r'\D'), '');
                                    if (cleanValue.length >= 6) {
                                      _fillCode(cleanValue.substring(0, 6));
                                      return;
                                    }

                                    if (value.isNotEmpty && index < 5) {
                                      _focusNodes[index + 1].requestFocus();
                                    }
                                    if (value.isEmpty && index > 0) {
                                      _focusNodes[index - 1].requestFocus();
                                    }
                                    if (_getCombinedCode().length == 6) {
                                      _verifyOTP();
                                    }
                                  },
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 24),

                          _canResend
                              ? TextButton(
                                  onPressed: _resendOTP,
                                  child: Text(localized['resendBtn']!, style: const TextStyle(color: ArrozTheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                                )
                              : Text(
                                  "${localized['resendWait']!}$_secondsRemaining s",
                                  style: const TextStyle(color: ArrozTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ArrozTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(localized['verifyBtn']!, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}