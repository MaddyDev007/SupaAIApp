import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:smartclass/models/login_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:hive/hive.dart';
// import 'package:smartclass/models/user_model.dart';

class ContinueWithGoogle extends StatefulWidget {
  const ContinueWithGoogle({super.key});

  @override
  State<ContinueWithGoogle> createState() => _ContinueWithGoogleState();
}

class _ContinueWithGoogleState extends State<ContinueWithGoogle> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String _error = '';

  Future<void> _continueWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // Start Google OAuth
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutter://login-callback',
      );

      // 👇 WAIT for session restoration
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw 'Waiting for Google sign-in to complete...';
      }

      final email = user.email ?? '';
      final name =
          (user.userMetadata?['name'] as String?) ?? email.split('@').first;
      final avatarUrl = user.userMetadata?['avatar_url'] as String?;

      await _supabase.from('users').upsert({
        'id': user.id,
        'email': email,
        'name': name,
        'avatar_url': avatarUrl,
      });

      final box = Hive.box<LoginModel>('loginBox');
      await box.put(
        'login',
        LoginModel(name: name, email: email, avatarUrl: avatarUrl),
      );

      if (!mounted) return;

      Navigator.pushReplacementNamed(context, '/commondashboard');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Continue with Google'),
        elevation: 0,
        centerTitle: true,
      ),
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : _continueWithGoogle,
                icon: Image.asset(
                  'assets/images/icon1.png',
                  height: 22,
                  width: 22,
                ),
                label: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue with Google'),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
