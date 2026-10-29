import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final supabase = Supabase.instance.client;

  Future<bool> signUp(String email, String password) async {
    final res = await supabase.auth.signUp(email: email, password: password);
    // A trusted database trigger creates the profile and users rows.
    // Client-side inserts cannot assign roles and must not write columns that
    // are absent from the profiles schema.
    if (res.user != null) {
      return true;
    }
    return false;
  }

  Future<bool> signIn(String email, String password) async {
    final res = await supabase.auth.signInWithPassword(email: email, password: password);
    return res.user != null;
  }
}
