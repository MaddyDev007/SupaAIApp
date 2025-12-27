/* import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:smartclass/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMsg = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // -------------------- Login Function --------------------
  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final success = await _authService.signIn(email, password);
      if (!mounted) return;

      if (!success) {
        setState(() => _errorMsg = 'Invalid email or password.');
        return;
      }

      final session = Supabase.instance.client.auth.currentSession;
      final userId = session?.user.id;

      if (userId == null) {
        setState(() => _errorMsg = 'User ID not found.');
        return;
      }

      // Fetch profile
      final user = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single()
          .timeout(const Duration(seconds: 10));

      // Save offline profile
      final box = Hive.box<UserModel>('userBox');
      await box.put(
        'profile',
        UserModel(
          name: user['name'] ?? "",
          email: user['email'] ?? "",
          department: user['department'] ?? "",
          year: user['year'] ?? "",
          role: user['role'] ?? "",
          regNo: user['reg_no'] ?? "",
        ),
      );

      if (!mounted) return;

      final role = user['role'] as String;
      final route =
          role == 'teacher' ? '/teacher-dashboard' : '/student-dashboard';

      Navigator.pushNamedAndRemoveUntil(
        context,
        route,
        (route) => false,
      );
    } on PostgrestException catch (e) {
      setState(() {
        _errorMsg = e.code == 'PGRST100'
            ? 'Invalid request to the database.'
            : 'Server error: ${e.message}';
      });
    } on AuthException catch (e) {
      setState(() {
        _errorMsg = e.message.contains('Invalid login credentials')
            ? 'Invalid email or password.'
            : 'Authentication failed: check your Internet.';
      });
    } catch (e) {
      setState(() => _errorMsg = 'Login failed. Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // -------------------- Input Builder --------------------
  Widget _inputField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
       
        prefixIcon: Icon(
          label == "Email" ? Icons.email_outlined : Icons.lock_outline,
          color: Colors.grey,
        ),
        suffixIcon: suffixIcon,
        
      ),
    );
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                 Icon(Icons.school, size: 80, color: Theme.of(context).primaryColor),
                const SizedBox(height: 20),

                Text(
                  "Welcome Back",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                ),

                const SizedBox(height: 40),

                // ---------------- Email ----------------
                _inputField(
                  label: 'Email',
                  controller: _emailController,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Enter your email';
                    final reg = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                    return reg.hasMatch(val) ? null : 'Enter a valid email';
                  },
                ),

                const SizedBox(height: 16),

                // ---------------- Password ----------------
                _inputField(
                  label: 'Password',
                  controller: _passwordController,
                  obscure: _obscurePassword,
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Enter your password';
                    }
                    return val.length < 6
                        ? 'Password must be at least 6 characters'
                        : null;
                  },
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),

                const SizedBox(height: 20),

                // ---------------- Login Button ----------------
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _loginUser,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Logging in...',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                if (_errorMsg.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(_errorMsg, style: const TextStyle(color: Colors.red)),
                ],

                const SizedBox(height: 16),

                // ---------------- Signup link ----------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don’t have an account?"),
                    TextButton(
                      onPressed: () => Navigator.pushReplacementNamed(
                        context,
                        '/signup',
                      ),
                      child: Text(
                        "Sign up",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
 */