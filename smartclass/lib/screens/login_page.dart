import 'package:flutter/material.dart';
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
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String _errorMsg = '';
  bool _obscurePassword = true; 

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginUser() async {
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
        final route = role == 'teacher'
            ? '/teacher-dashboard'
            : '/student-dashboard';

        Navigator.pushReplacementNamed(context, route);
      } else {
        setState(() => _errorMsg = 'Invalid email or password.');
      }
    } catch (e) {
      setState(() => _errorMsg = 'Login failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.blueAccent, // Color when focused
            width: 2,
          ),
        ),
        prefixIcon: label == "Email"
            ? const Icon(Icons.email_outlined)
            : const Icon(Icons.lock_outline),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🔹 App Logo / Icon
              Icon(Icons.school, size: 80, color: Colors.blue),
              const SizedBox(height: 20),

              // 🔹 Title
              Text(
                "Welcome Back",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 40),

              // 🔹 Email Field
              _buildTextField(label: 'Email', controller: _emailController),
              const SizedBox(height: 16),

              // 🔹 Password Field with Eye Icon
              _buildTextField(
                label: 'Password',
                controller: _passwordController,
                obscure: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),

              // 🔹 Login Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _loginUser,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const Text(
                          'Login...',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
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

              // 🔹 Error Message
              if (_errorMsg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _errorMsg,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              const SizedBox(height: 16),

              // 🔹 Sign Up
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
    );
  }
}
