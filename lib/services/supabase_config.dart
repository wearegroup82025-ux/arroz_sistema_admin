import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase is used ONLY for product image storage. Firebase remains the main database/auth.
class SupabaseConfig {
  static const String url = 'https://fgkxatamapalhuvwuzpw.supabase.co';
  static const String publishableKey = 'sb_publishable_BqNhtKDoaksy-_fMOwVhUw_OzpoEXSP';

  static Future<void> initialize() async {
    if (url.contains('PASTE_YOUR') || publishableKey.contains('PASTE_YOUR')) {
      throw StateError(
        'Supabase is not configured. Add the Project URL and publishable key in lib/supabase_config.dart.',
      );
    }

    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
    );

    // Storage uploads are protected by Supabase RLS using the authenticated role.
    // This anonymous session is NOT your Firebase login and does not replace Firebase Auth.
    final supabase = Supabase.instance.client;
    if (supabase.auth.currentSession == null) {
      await supabase.auth.signInAnonymously();
    }
  }
}
