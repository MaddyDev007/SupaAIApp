import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:smartclass/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UpdatePage extends StatefulWidget {
  final Map<String, dynamic> profile;

  const UpdatePage({required this.profile, super.key});

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

  bool _saving = false;
  String? _errorMsg;

  static const List<String> _departments = ['CSE', 'EEE', 'ECE', 'Mech'];
  static const List<String> _years = [
    '1st year',
    '2nd year',
    '3rd year',
    '4th year',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _regController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // ✅ Pre-fill form using passed profile map
    final data = widget.profile;

    _nameController.text = data['name'] ?? "";
    _regController.text = data['reg_no'] ?? "";
    _selectedDept = data['department'];
    _selectedYear = data['year'];
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMsg = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() => _errorMsg = 'User session expired.');
        return;
      }

      // ✅ Update in Supabase
      await _supabase
          .from('profiles')
          .update({
            'name': _nameController.text.trim(),
            'department': _selectedDept,
            'year': _selectedYear,
            'reg_no': _regController.text.trim(),
          })
          .eq('id', user.id).timeout(
          const Duration(seconds: 12),
          onTimeout: () => throw TimeoutException('Profile update timed out'),
        );

      // ✅ Update Hive offline storage
      final userBox = Hive.box<UserModel>('userBox');

      userBox.put(
        'profile',
        UserModel(
          name: _nameController.text.trim(),
          email: widget.profile["email"],
          department: _selectedDept!,
          year: _selectedYear!,
          role: widget.profile["role"],
          regNo: _regController.text.trim(),
        ),
      );

      // ✅ Show success toast
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text("Profile updated successfully 🎉")),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 6,
          duration: const Duration(seconds: 3),
        ),
      );

      // ✅ Redirect based on role
      final route = widget.profile["role"] == "teacher"
          ? '/teacher-dashboard'
          : '/student-dashboard';

      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
    } on SocketException {
      setState(
        () => _errorMsg = "No internet connection. Please check and try again.",
      );
    } on TimeoutException {
      setState(
        () => _errorMsg = "Connection timed out. Please try again later.",
      );
    } on http.ClientException {
      setState(() => _errorMsg = "Network error occurred. Try again shortly.");
    } on PostgrestException catch (e) {
      // 🔹 Supabase-specific error (invalid query or auth)
      setState(() => _errorMsg = "Supabase error: ${e.message}");
    } on HiveError catch (e) {
      // 🔹 Local storage issue
      setState(() => _errorMsg = "Local save error: ${e.message}");
    } catch (e) {
      // 🔹 Fallback for unknown errors
      setState(() => _errorMsg = "Unexpected error: $e");
    } finally {
      setState(() => _saving = false);
    }
  }

  Widget _dropdown({
    required String label,
    required List<String> items,
    required String? value,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      dropdownColor: Theme.of(context).cardColor,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontWeight: FontWeight.w500,
                  ),
      value: value,
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
      decoration: _inputDecoration(label),
      validator: (val) => val == null ? "Select $label" : null,
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Update Profile",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: Colors.white, // <-- change back arrow color here
        ),
      ),

      // ✅ Loading Screen
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration("Full Name"),
                validator: (v) => v == null || v.isEmpty ? "Enter name" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _regController,
                decoration: _inputDecoration("Register Number"),
                validator: (v) => v == null ? "Enter register number" : null,
              ),

              const SizedBox(height: 16),
              _dropdown(
                label: "Department",
                items: _departments,
                value: _selectedDept,
                onChanged: (v) => setState(() => _selectedDept = v),
              ),

              const SizedBox(height: 16),
              _dropdown(
                label: "Year",
                items: _years,
                value: _selectedYear,
                onChanged: (v) => setState(() => _selectedYear = v),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Update Profile",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              if (_errorMsg != null) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _errorMsg!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
