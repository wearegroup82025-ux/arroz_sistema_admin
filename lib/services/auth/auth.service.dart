import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class AuthService {
  AuthService._privateConstructor();
  static final AuthService instance = AuthService._privateConstructor();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  http.Client _getHttpClient() {
    if (kIsWeb) {
      return http.Client();
    }
    final ioClient = HttpClient();
    ioClient.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    ioClient.connectionTimeout = const Duration(seconds: 15);
    return IOClient(ioClient);
  }

  Future<bool> _isEmailDomainValid(String email) async {
    try {
      final parts = email.split('@');
      if (parts.length != 2) return false;
      final domain = parts[1].trim();
      final result = await InternetAddress.lookup(domain);
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // --- PHONE OTP FUNCTIONS ---
  Future<String> sendPhoneOTPWithTextBee({
    required String phoneNumber,
  }) async {
    try {
      // I-convert lagi sa 09XXXXXXXXX
      String cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');

      if (cleanPhone.startsWith('63')) {
        cleanPhone = '0${cleanPhone.substring(2)}';
      }

      if (!cleanPhone.startsWith('09') || cleanPhone.length != 11) {
        throw Exception("Invalid cellphone number.");
      }

      final existingUser = await _firestore
          .collection('users')
          .where('phone', isEqualTo: cleanPhone)
          .limit(1)
          .get();

      if (existingUser.docs.isNotEmpty) {
        throw Exception("May umiiral nang account gamit ang numerong ito.");
      }

      final otp = List.generate(
        6,
            (_) => Random().nextInt(10).toString(),
      ).join();

      await _firestore.collection('phone_otps').doc(cleanPhone).set({
        'otp': otp,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(minutes: 1)),
        ),
      });

      const apiKey = '3976128d-92db-428f-8e94-8ac21cb5b1b4';
      const deviceId = '6a6c26d3cd8a35b23c02a931';

      final response = await _getHttpClient().post(
        Uri.parse(
          'https://api.textbee.dev/api/v1/gateway/devices/$deviceId/send-sms',
        ),
        headers: {
          'x-api-key': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "recipients": [cleanPhone],
          "message":
          "Your Arroz OTP code is: $otp. Valid for 1 minute only.",
        }),
      );

      if (response.statusCode != 200 &&
          response.statusCode != 201) {
        throw Exception("Hindi maipadala ang SMS.");
      }

      return otp;
    } catch (e) {
      rethrow;
    }
  }

  Future<String> sendPhoneOTPWithSemaphore({required String phoneNumber}) async {
    return await sendPhoneOTPWithTextBee(phoneNumber: phoneNumber);
  }

  Future<bool> verifyPhoneOTP({required String phoneNumber, required String typedOtp}) async {
    try {
      final doc = await _firestore.collection('phone_otps').doc(phoneNumber.trim()).get();
      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      final String savedOtp = data['otp'] ?? '';
      final Timestamp? expiresAtTimestamp = data['expiresAt'] as Timestamp?;

      if (expiresAtTimestamp == null) return false;

      DateTime expiresAt = expiresAtTimestamp.toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        await _firestore.collection('phone_otps').doc(phoneNumber.trim()).delete();
        return false; 
      }

      if (savedOtp == typedOtp.trim()) {
        await _firestore.collection('phone_otps').doc(phoneNumber.trim()).delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<UserCredential> registerWithPhone({
    required String phoneNumber,
    required String password,
  }) async {
    String cleanPhone = normalizePhone(phoneNumber);

    String fakeEmail =
        "$cleanPhone@carrotcarper.internal";
    final methods =
    await _auth.fetchSignInMethodsForEmail(fakeEmail);

    if (methods.isNotEmpty) {
      throw Exception("May account na gamit ang numerong ito.");
    }

    return await _auth.createUserWithEmailAndPassword(
      email: fakeEmail,
      password: password,
    );
  }

  Future<UserCredential> loginWithPhone({
    required String phoneNumber,
    required String password,
  }) async {

    String cleanPhone = normalizePhone(phoneNumber);

    final fakeEmail =
        "$cleanPhone@carrotcarper.internal";

    return await _auth.signInWithEmailAndPassword(
      email: fakeEmail,
      password: password,
    );
  }

  String normalizePhone(String phone) {
    String clean = phone.replaceAll(RegExp(r'\D'), '');

    if (clean.startsWith('09')) {
      clean = '63${clean.substring(1)}';
    } else if (clean.startsWith('9') && clean.length == 10) {
      clean = '63$clean';
    } else if (clean.startsWith('639')) {
      // already normalized
    } else {
      throw Exception("Invalid phone number.");
    }

    return clean;
  }

  // --- EMAIL OTP GENERATOR WITH DIRECT FIRESTORE EXISTENCE CHECK ---
  Future<String> generateAndSaveEmailOTP({
    required String email, 
    required String name,
    String reason = "Registration",
  }) async {
    String cleanEmail = email.trim().toLowerCase();

    // 1. Valid Format Check
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(cleanEmail)) {
      throw Exception("Maling format ng email address.");
    }

    // 2. Domain Check
    bool isDomainExist = await _isEmailDomainValid(cleanEmail);
    if (!isDomainExist) {
      throw Exception("Hindi umiiral ang email domain na ito.");
    }

    // 3. DIRECT FIRESTORE CHECK: Titingnan sa 'users' collection kung may kaparehong email
    if (reason == "Registration") {
      final existingEmailDoc = await _firestore
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      if (existingEmailDoc.docs.isNotEmpty) {
        throw Exception("May nakarehistro nang account gamit ang email na ito.");
      }
    }

    final random = Random();
    String otp = List.generate(6, (_) => random.nextInt(10).toString()).join();

    String senderEmail = 'wearegroup82025@gmail.com'; 
    String appPassword = 'ygyziuokfrdxqrfd'; 

    final smtpServer = gmail(senderEmail, appPassword);
    
    String emailSubject = '[Arroz] OTP Code para sa Pagrehistro ng Account';
    String badgeTitle = 'ACCOUNT REGISTRATION';
    String emailDescription = 'Malugod ka naming tinatanggap sa Arroz! Gamitin ang OTP code sa ibaba upang makumpleto ang pagrehistro:';

    final message = Message()
      ..from = Address(senderEmail, 'Arroz Platform Support')
      ..recipients.add(cleanEmail)
      ..subject = emailSubject
      ..text = 'Magandang araw $name,\n\nAng iyong verification code ay: $otp.\n\nExpire sa loob ng 1 minuto.'
      ..html = """
      <!DOCTYPE html>
      <html>
      <body style="font-family: Arial, sans-serif; background-color: #f4f6f8; padding: 20px;">
        <div style="max-width: 500px; margin: 0 auto; background: #ffffff; padding: 20px; border-radius: 10px;">
          <h2 style="color: #0F5132;">🌱 ARROZ Support</h2>
          <p>$emailDescription</p>
          <div style="background: #e8f5e9; padding: 15px; text-align: center; font-size: 28px; font-weight: bold; color: #0F5132; letter-spacing: 5px;">
            $otp
          </div>
          <p style="font-size: 12px; color: #666; margin-top: 15px;">Valid for 1 minute only. Do not share.</p>
        </div>
      </body>
      </html>
      """;

    try {
      // Subukang magpadala via SMTP. Kapag mali ang mailbox, papasok ito sa Catch Block
      await send(message, smtpServer);

      DateTime now = DateTime.now();
      DateTime expirationTime = now.add(const Duration(minutes: 1));

      await _firestore.collection('email_otps').doc(cleanEmail).set({
        'otp': otp,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expirationTime),
      });

      return otp;
    } on MailerException catch (e) {
      debugPrint("Mailer Error: $e");
      throw Exception("Hindi maipadala ang email. Siguraduhing umiiral ang mailbox.");
    } catch (e) {
      debugPrint("Sending Exception: $e");
      rethrow;
    }
  }

  Future<bool> verifyEmailOTP({required String email, required String typedOtp}) async {
    try {
      final doc = await _firestore.collection('email_otps').doc(email.trim().toLowerCase()).get();
      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      final String savedOtp = data['otp'] ?? '';
      final Timestamp? expiresAtTimestamp = data['expiresAt'] as Timestamp?;

      if (expiresAtTimestamp == null) return false;

      DateTime expiresAt = expiresAtTimestamp.toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        await _firestore.collection('email_otps').doc(email.trim().toLowerCase()).delete();
        return false; 
      }

      if (savedOtp == typedOtp.trim()) {
        await _firestore.collection('email_otps').doc(email.trim().toLowerCase()).delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<UserCredential> registerWithEmail({required String email, required String password}) async {
    return await _auth.createUserWithEmailAndPassword(email: email.trim().toLowerCase(), password: password.trim());
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}