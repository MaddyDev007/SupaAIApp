import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:smartclass/models/login_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContinueWithGoogle extends StatefulWidget {
  const ContinueWithGoogle({super.key});

  @override
  State<ContinueWithGoogle> createState() => _ContinueWithGoogleState();
}

class _ContinueWithGoogleState extends State<ContinueWithGoogle> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String _error = '';

  late final StreamSubscription<AuthState> _authSub;

  @override
  void initState() {
    super.initState();

    _authSub = _supabase.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      final user = session?.user;

      if (user == null) return;

      final email = user.email ?? '';
      final name =
          (user.userMetadata?['name'] as String?) ?? email.split('@').first;
      final avatarUrl = user.userMetadata?['avatar_url'] as String?;

      try {
        await _supabase.from('users').upsert({
          'id': user.id,
          'email': email,
          'name': name,
          'avatar_url': avatarUrl,
        });

        final box = Hive.box<LoginModel>('loginBox');
        await box.put(
          'profile',
          LoginModel(name: name, email: email, avatarUrl: avatarUrl),
        );

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/commondashboard');
      } catch (e) {
        if (!mounted) return;
        setState(() => _error = e.toString());
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _continueWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutter://login-callback',
      );
    } on AuthException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.primaryColor.withOpacity(0.12),
              theme.scaffoldBackgroundColor,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                color: theme.cardColor,
                elevation: 10,
                shadowColor: theme.primaryColor.withOpacity(0.25),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: theme.primaryColor, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🔷 Logo
                      Container(
                        height: 72,
                        width: 72,
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/icon1.png',
                            height: 75,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Text(
                        'Welcome to SmartClass',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Smart learning • Smart assessment • Smart classroom',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // 🔷 Google Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _continueWithGoogle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),

                          label: _isLoading
                              ? Row(
                                spacing: 10,
                                mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(context).primaryColor,
                                        // color: Colors.red,
                                      ),
                                    ),
                                    const Text(
                                      "Loading...",
                                      style: TextStyle(
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  spacing: 10,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Image.asset(
                                        'assets/images/google.png',
                                        height: 20,
                                      ),
                                    ),
                                    const Text(
                                      'Continue with Google',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          _error,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
