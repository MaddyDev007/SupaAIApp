import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key});

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _regController = TextEditingController();

  String? _selectedDept;
  String? _selectedYear;
  bool _isLoading = true;
  bool _updating = false;
  String? _errorMsg;

  final List<String> _departments = ['CSE', 'EEE', 'ECE', 'Mech'];
  final List<String> _years = ['1st year', '2nd year', '3rd year', '4th year'];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() => _errorMsg = 'User not logged in');
        return;
      }

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _nameController.text = response['name'] ?? '';
          _selectedDept = response['department'];
          _selectedYear = response['year'];
          _regController.text = response['reg_no'];
        });
      }
    } catch (e) {
      setState(() => _errorMsg = 'Error loading profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _updating = true;
      _errorMsg = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() => _errorMsg = 'No user session found');
        return;
      }

      // ✅ Update profile in Supabase
      await _supabase
          .from('profiles')
          .update({
            'name': _nameController.text.trim(),
            'department': _selectedDept,
            'year': _selectedYear,
            'reg_no': _regController.text.trim(),
          })
          .eq('id', user.id);

      // ✅ Fetch updated role for correct redirection
      final profile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully 🎉'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // ✅ Reload app with updated data by navigating to the correct dashboard
      final role = profile?['role'];
      final route = role == 'teacher'
          ? '/teacher-dashboard'
          : '/student-dashboard';

      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
    } catch (e) {
      setState(() => _errorMsg = 'Error updating profile: $e');
    } finally {
      setState(() => _updating = false);
    }
  }

  Widget _buildDropdownField({
    required String label,
    required List<String> items,
    required String? value,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        floatingLabelStyle: const TextStyle(color: Colors.blueAccent),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade300, width: 2),
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
          'Update Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 26,
          ),
        ),
        backgroundColor: Colors.blue,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      cursorColor: Colors.blue,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        floatingLabelStyle: TextStyle(
                          color: Colors
                              .blueAccent, // 👈 Change label text color here
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(
                          Icons.person_outline,
                          color: Colors.grey,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.blue.shade100,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.blue.shade300,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Enter name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _regController,
                      cursorColor: Colors.blue,
                      decoration: InputDecoration(
                        labelText: 'Register Number',
                        floatingLabelStyle: TextStyle(
                          color: Colors
                              .blueAccent, // 👈 Change label text color here
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(
                          Icons.confirmation_number_outlined,
                          color: Colors.grey,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.blue.shade100,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.blue.shade300,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) =>
                          value == null ? 'Enter name' : null,
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
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _updating ? null : _updateProfile,
                        child: _updating
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 1.5,
                                ),
                              )
                            : const Text(
                                'Update Profile',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_errorMsg != null)
                      Center(
                        child: Text(
                          _errorMsg!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
