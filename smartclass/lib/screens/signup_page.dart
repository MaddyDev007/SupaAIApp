import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController(); // 👈 Added
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String _errorMsg = '';

  String? _selectedDept;
  String? _selectedYear;

  final List<String> _departments = ['CSE', 'EEE', 'ECE', 'Mech'];
  final List<String> _years = ['1st year', '2nd year', '3rd year', '4th year'];

  @override
  void dispose() {
    _nameController.dispose(); // 👈 Dispose properly
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });

    final name = _nameController.text.trim(); // 👈 Get name
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final res = await _supabase.auth.signUp(email: email, password: password);
      final user = res.user;

      if (user == null) {
        setState(() => _errorMsg = 'Signup failed. Try again.');
        return;
      }

      final role = email.endsWith('@myclg.edu') ? 'teacher' : 'student';

      await _supabase.from('profiles').insert({
        'id': user.id,
        'name': name, // 👈 Store in DB
        'email': email,
        'role': role,
        'department': _selectedDept,
        'year': _selectedYear,
      });

      if (!context.mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Signup Successful'),
          content: Text(
              'Welcome $name!\nYou are registered as a $role in $_selectedDept ($_selectedYear).'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            )
          ],
        ),
      );

      final route =
          role == 'teacher' ? '/teacher-dashboard' : '/student-dashboard';
      Navigator.pushReplacementNamed(context, route);
    } on AuthException catch (e) {
      setState(() => _errorMsg = e.message);
    } catch (e) {
      setState(() => _errorMsg = 'An error occurred: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTextFormField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    bool obscure = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(labelText: label),
      validator: validator,
    );
  }

  Widget _buildDropdownField({
    required String label,
    required List<String> items,
    required String? value,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: label),
      value: value,
      onChanged: onChanged,
      validator: (val) => val == null ? 'Please select $label' : null,
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item),
              ))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTextFormField(
                  label: 'Name',
                  controller: _nameController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                _buildTextFormField(
                  label: 'Email',
                  controller: _emailController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email is required';
                    }
                    if (!value.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                _buildTextFormField(
                  label: 'Password',
                  controller: _passwordController,
                  obscure: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 6) {
                      return 'Minimum 6 characters required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                _buildDropdownField(
                  label: 'Department',
                  items: _departments,
                  value: _selectedDept,
                  onChanged: (val) => setState(() => _selectedDept = val),
                ),
                const SizedBox(height: 10),
                _buildDropdownField(
                  label: 'Year',
                  items: _years,
                  value: _selectedYear,
                  onChanged: (val) => setState(() => _selectedYear = val),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign Up'),
                ),
                const SizedBox(height: 10),
                if (_errorMsg.isNotEmpty)
                  Text(_errorMsg, style: const TextStyle(color: Colors.red)),
                TextButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text('Back to login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
