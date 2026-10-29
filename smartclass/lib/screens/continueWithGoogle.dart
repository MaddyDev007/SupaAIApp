import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
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

  late final StreamSubscription<AuthState> _authSubscription;

  bool _isLoading = false;
  bool _isHandlingSession = false;
  bool _hasNavigated = false;
  String? _errorMessage;

  bool get _isAndroid => Platform.isAndroid;
  bool get _isWindows => Platform.isWindows;

  static const _callbackScheme = 'smartclass';
  static const _callbackHost = 'login-callback';
  static const _callbackUrl = 'smartclass://login-callback';

  @override
  void initState() {
    super.initState();

    _authSubscription = _supabase.auth.onAuthStateChange.listen(
      (authState) async {
        debugPrint('Supabase auth event: ${authState.event}');
        debugPrint('Supabase session from listener: ${authState.session}');

        if (authState.session != null) {
          await _handleSignedInSession(authState.session!);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Supabase auth listener error: $error');
        debugPrint(stackTrace.toString());
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Authentication listener failed: $error';
        });
      },
    );
  }

  Future<void> _handleSignedInSession(Session session) async {
    if (_hasNavigated || _isHandlingSession) return;

    _isHandlingSession = true;

    try {
      final user = session.user;
      final metadata = user.userMetadata ?? <String, dynamic>{};

      final email = user.email?.trim() ?? '';
      final name = _resolveDisplayName(metadata, email);
      final avatarUrl = _resolveAvatarUrl(metadata);

      // The auth.users trigger creates and maintains the users row.
      // Update only user-editable fields; email is controlled by Supabase Auth.
      await _supabase
          .from('users')
          .update({
            'name': name,
            'avatar_url': avatarUrl,
          })
          .eq('id', user.id);

      final box = Hive.box<LoginModel>('loginBox');
      await box.put(
        'profile',
        LoginModel(name: name, email: email, avatarUrl: avatarUrl),
      );

      if (!mounted) return;

      _hasNavigated = true;
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });

      Navigator.pushReplacementNamed(context, '/commondashboard');
    } on PostgrestException catch (error, stackTrace) {
      debugPrint('Failed to upsert Google user: ${error.message}');
      debugPrint(stackTrace.toString());
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to complete Google login: $error');
      debugPrint(stackTrace.toString());
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    } finally {
      _isHandlingSession = false;
    }
  }

  String _resolveDisplayName(Map<String, dynamic> metadata, String email) {
    final fullName = (metadata['full_name'] as String?)?.trim();
    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }

    final name = (metadata['name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    if (email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'User';
  }

  String? _resolveAvatarUrl(Map<String, dynamic> metadata) {
    final avatarUrl = (metadata['avatar_url'] as String?)?.trim();
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return null;
    }
    return avatarUrl;
  }

  Future<void> _continueWithGoogle() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isAndroid) {
        await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: _callbackUrl,
        );
        return;
      }

      if (_isWindows) {
        await _signInWithGoogleOnWindows();
        return;
      }

      throw UnsupportedError(
        'Google OAuth is configured only for Android and Windows.',
      );
    } on UnsupportedError catch (error, stackTrace) {
      debugPrint('Unsupported platform: $error');
      debugPrint(stackTrace.toString());
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } on AuthException catch (error, stackTrace) {
      debugPrint('Supabase AuthException: ${error.message}');
      debugPrint(stackTrace.toString());
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (error, stackTrace) {
      debugPrint('Google OAuth error: $error');
      debugPrint(stackTrace.toString());
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _signInWithGoogleOnWindows() async {
    // Desktop apps do not receive OAuth redirects automatically the way mobile
    // deep links do. flutter_web_auth_2 opens the auth page and captures the
    // callback URL so we can manually exchange the authorization code for a
    // Supabase session.
    final oauth = await _supabase.auth.getOAuthSignInUrl(
      provider: OAuthProvider.google,
      redirectTo: _callbackUrl,
    );

    final result = await FlutterWebAuth2.authenticate(
      url: oauth.url,
      callbackUrlScheme: _callbackScheme,
    );

    debugPrint('flutter_web_auth_2 callback result: $result');

    final uri = Uri.parse(result);
    final returnedHost = uri.host;
    final code = uri.queryParameters['code'];
    final error = uri.queryParameters['error'];
    final errorDescription = uri.queryParameters['error_description'];

    if (returnedHost.isNotEmpty && returnedHost != _callbackHost) {
      throw AuthException('Unexpected callback host: $returnedHost');
    }

    if (error != null) {
      throw AuthException(errorDescription ?? error);
    }

    if (code == null || code.isEmpty) {
      throw AuthException('No authorization code returned from Google OAuth.');
    }

    final sessionResponse = await _supabase.auth.exchangeCodeForSession(code);
    debugPrint('Supabase exchanged session: ${sessionResponse.session}');

    final session = sessionResponse.session;
    if (session == null) {
      throw AuthException('No session returned after code exchange.');
    }

    await _handleSignedInSession(session);
  }

  @override
  void dispose() {
    _authSubscription.cancel();
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
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
                        Container(
                          height: 72,
                          width: 72,
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.20),
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
                          'Sign in with Google to continue to your dashboard.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _continueWithGoogle,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primaryColor,
                              disabledBackgroundColor: theme.primaryColor
                                  .withOpacity(0.65),
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isLoading
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Signing in...',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Image.asset(
                                          'assets/images/google.png',
                                          height: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
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
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.colorScheme.onErrorContainer,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          'Android uses Supabase deep-link OAuth. Windows captures the callback manually with flutter_web_auth_2, then exchanges the returned code for a real Supabase session.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
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
