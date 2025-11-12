import 'package:flutter/material.dart';
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
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMsg = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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
    if (!context.mounted) return;

    if (success) {
      final session = Supabase.instance.client.auth.currentSession;
      final userId = session?.user.id;

      if (userId == null) {
        setState(() => _errorMsg = 'User ID not found.');
        return;
      }

      final user = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      final role = user['role'] as String;
      final route =
          role == 'teacher' ? '/teacher-dashboard' : '/student-dashboard';

      final userBox = Hive.box<UserModel>('userBox');

      await userBox.put(
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

      Navigator.pushNamedAndRemoveUntil(
        context,
        route,
        (Route<dynamic> route) => false,
      );
    } else {
      setState(() => _errorMsg = 'Invalid email or password.');
    }
  } on PostgrestException catch (e) {
    // 🔹 Specific handling for Supabase query-related errors
    if (e.code == 'PGRST100') {
      setState(() => _errorMsg = 'Invalid request to the database.');
    } else {
      setState(() => _errorMsg = 'Server error: ${e.message}');
    }
  } on AuthException catch (e) {
    // 🔹 Handle Supabase Auth API errors (like invalid credentials)
    if (e.message.contains('Invalid login credentials')) {
      setState(() => _errorMsg = 'Invalid email or password.');
    } else {
      setState(() => _errorMsg = 'Authentication failed: check your Internet.');
    }
  } catch (e) {
    // 🔹 Fallback for any other unexpected error
    setState(() => _errorMsg = 'Login failed. Error: $e');
  } finally {
    setState(() => _isLoading = false);
  }
}


  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      cursorColor: Colors.blue,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelText: label,
        floatingLabelStyle: const TextStyle(color: Colors.blueAccent),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade100, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade300, width: 2),
        ),
        prefixIcon: label == "Email"
            ? const Icon(Icons.email_outlined, color: Colors.grey)
            : const Icon(Icons.lock_outline, color: Colors.grey),
        suffixIcon: suffixIcon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey, // ✅ Added form validation wrapper
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school, size: 80, color: Colors.blue),
                const SizedBox(height: 20),
                Text(
                  "Welcome Back",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                ),
                const SizedBox(height: 40),

                // Email Field
                _buildTextField(
                  label: 'Email',
                  controller: _emailController,
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Enter your email';
                    }
                    final emailRegex =
                        RegExp(r'^[^@]+@[^@]+\.[^@]+'); // simple check
                    if (!emailRegex.hasMatch(val)) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password Field
                _buildTextField(
                  label: 'Password',
                  controller: _passwordController,
                  obscure: _obscurePassword,
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
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Enter your password';
                    }
                    if (val.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _loginUser,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
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
                  Text(
                    _errorMsg,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],

                const SizedBox(height: 16),

                // Signup option
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don’t have an account?"),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/signup'),
                      child: const Text(
                        "Sign up",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
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
