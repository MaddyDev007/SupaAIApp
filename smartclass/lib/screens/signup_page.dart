import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smartclass/models/user_model.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _regController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String _errorMsg = '';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? _selectedDept;
  String? _selectedYear;

  final List<String> _departments = ['CSE', 'EEE', 'ECE', 'Mech'];
  final List<String> _years = ['1st year', '2nd year', '3rd year', '4th year'];

  @override
  void dispose() {
    _regController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      setState(() => _errorMsg = "Passwords do not match");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });

    final name = _nameController.text.trim();
    final regNo = _regController.text.trim();
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
        'name': name,
        'email': email,
        'role': role,
        'department': _selectedDept,
        'year': _selectedYear,
        'reg_no': regNo,
      });

      final box = Hive.box<UserModel>('userBox');
      await box.put(
        'profile',
        UserModel(
          name: name,
          email: email,
          department: _selectedDept ?? "",
          year: _selectedYear ?? "",
          role: role,
          regNo: regNo,
        ),
      );

      if (!context.mounted) return;

      final route = role == 'teacher'
          ? '/teacher-dashboard'
          : '/student-dashboard';

      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
    } on AuthException {
      setState(() => _errorMsg = "Authentication failed: check your Internet.");
    } catch (e) {
      setState(() => _errorMsg = 'An error occurred: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTextFormField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String? Function(String?) validator,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      cursorColor: Colors.blue,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelText: label,
        floatingLabelStyle: TextStyle(
          color: Colors.blueAccent, // 👈 Change label text color here
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade100, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.blue.shade300, // Color when focused
            width: 2,
          ),
        ),
        prefixIcon: Icon(icon, color: Colors.grey),
        suffixIcon: suffixIcon,
        suffixIconColor: Colors.grey,
      ),
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
      decoration: InputDecoration(
        floatingLabelStyle: TextStyle(
          color: Colors.blueAccent, // 👈 Change label text color here
        ),
        suffixIconColor: Colors.grey,
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.blue.shade300, // Color when focused
            width: 2,
          ),
        ),
      ),
      value: value,
      onChanged: onChanged,
      validator: (val) => val == null ? 'Please select $label' : null,
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text(
          'Create Account',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 30,
          ),
        ),
        backgroundColor: Colors.blue,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: Colors.white, // <-- change back arrow color here
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                _buildTextFormField(
                  label: 'Full Name',
                  icon: Icons.person_outline,
                  controller: _nameController,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 20),
                _buildTextFormField(
                  label: 'Register Number',
                  icon: Icons.confirmation_number,
                  controller: _regController,
                  validator: (value) =>
                      value == null ? 'Register Number is required' : null,
                ),
                const SizedBox(height: 16),
                _buildTextFormField(
                  label: 'Email',
                  icon: Icons.email_outlined,
                  controller: _emailController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email is required';
                    }
                    if (!value.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextFormField(
                  label: 'Password',
                  icon: Icons.lock_outline,
                  controller: _passwordController,
                  obscure: _obscurePassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 6) {
                      return 'Minimum 6 characters required';
                    }
                    return null;
                  },
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _buildTextFormField(
                  label: 'Confirm Password',
                  icon: Icons.lock_reset_outlined,
                  controller: _confirmPasswordController,
                  obscure: _obscureConfirmPassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _buildDropdownField(
                  label: 'Department',
                  items: _departments,
                  value: _selectedDept,
                  onChanged: (val) => setState(() => _selectedDept = val),
                ),
                const SizedBox(height: 16),
                _buildDropdownField(
                  label: 'Year',
                  items: _years,
                  value: _selectedYear,

                  onChanged: (val) => setState(() => _selectedYear = val),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isLoading ? null : _signUp,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 1,
                            ),
                          )
                        : const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_errorMsg.isNotEmpty)
                  Center(
                    child: Text(
                      _errorMsg,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                TextButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text(
                    "Already have an account? Login",
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
