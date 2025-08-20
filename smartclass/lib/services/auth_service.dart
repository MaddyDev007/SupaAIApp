import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final supabase = Supabase.instance.client;

  Future<bool> signUp(String email, String password) async {
    final res = await supabase.auth.signUp(email: email, password: password);
    if (res.user != null) {
      final isTeacher = email.endsWith('@myclg.edu');
      await supabase.from('profiles').insert({
        'id': res.user!.id,
        'email': email,
        'role': isTeacher ? 'teacher' : 'student',
        'name': email,
        'department': '',
        'class': '',
        'subjects': [],
      });
      return true;
    }
    return false;
  }

  Future<bool> signIn(String email, String password) async {
    final res = await supabase.auth.signInWithPassword(email: email, password: password);
    return res.user != null;
  }
}
