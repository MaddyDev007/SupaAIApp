import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:smartclass/models/login_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UpdatePage extends StatefulWidget {
  final Map<String, dynamic> profile;

  const UpdatePage({
    super.key,
    required this.profile,
  });

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _regController = TextEditingController();

  bool _saving = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();

    _nameController.text = widget.profile['name'] ?? "";
    _regController.text = widget.profile['reg_no'] ?? "";
  }

  @override
  void dispose() {
    _nameController.dispose();
    _regController.dispose();
    super.dispose();
  }

  // ---------------- UPDATE PROFILE ----------------
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMsg = null;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception("Session expired");
      }

      // ✅ UPDATE USERS TABLE
      await supabase
          .from('users')
          .update({
            'name': _nameController.text.trim(),
            'reg_no': _regController.text.trim(),
          })
          .eq('id', user.id)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () =>
                throw TimeoutException("Profile update timed out"),
          );

      // ✅ UPDATE HIVE (OFFLINE CACHE)
      final loginBox = Hive.box<LoginModel>('loginBox');

      loginBox.put(
        'profile',
        LoginModel(
          name: _nameController.text.trim(),
          email: widget.profile['email'],
          role: widget.profile['role'],
          reg_no: _regController.text.trim(),
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Expanded(child: Text("Profile updated successfully")),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      Navigator.pop(context, true);
    } on SocketException {
      setState(() => _errorMsg = "No internet connection");
    } on TimeoutException {
      setState(() => _errorMsg = "Request timed out. Try again");
    } on PostgrestException catch (e) {
      setState(() => _errorMsg = "Database error: ${e.message}");
    } catch (e) {
      setState(() => _errorMsg = "Unexpected error: $e");
    } finally {
      setState(() => _saving = false);
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Update Profile",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Full Name"),
                validator: (v) =>
                    v == null || v.isEmpty ? "Enter your name" : null,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _regController,
                decoration:
                    const InputDecoration(labelText: "Register Number"),
                validator: (v) =>
                    v == null || v.isEmpty ? "Enter register number" : null,
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                          "Save Changes",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              if (_errorMsg != null) ...[
                const SizedBox(height: 14),
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
