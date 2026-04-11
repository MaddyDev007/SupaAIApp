// // import 'dart:async';
// // import 'dart:io';

// // import 'package:flutter/material.dart';
// // import 'package:hive/hive.dart';
// // import 'package:smartclass/models/login_model.dart';
// // import 'package:supabase_flutter/supabase_flutter.dart';

// // class UpdatePage extends StatefulWidget {
// //   final Map<String, dynamic> profile;

// //   const UpdatePage({
// //     super.key,
// //     required this.profile,
// //   });

// //   @override
// //   State<UpdatePage> createState() => _UpdatePageState();
// // }

// // class _UpdatePageState extends State<UpdatePage> {
// //   final _formKey = GlobalKey<FormState>();
// //   final supabase = Supabase.instance.client;

// //   final TextEditingController _nameController = TextEditingController();
// //   final TextEditingController _regController = TextEditingController();

// //   bool _saving = false;
// //   String? _errorMsg;

// //   @override
// //   void initState() {
// //     super.initState();

// //     _nameController.text = widget.profile['name'] ?? "";
// //     _regController.text = widget.profile['reg_no'] ?? "";
// //   }

// //   @override
// //   void dispose() {
// //     _nameController.dispose();
// //     _regController.dispose();
// //     super.dispose();
// //   }

// //   // ---------------- UPDATE PROFILE ----------------
// //   Future<void> _updateProfile() async {
// //     if (!_formKey.currentState!.validate()) return;

// //     setState(() {
// //       _saving = true;
// //       _errorMsg = null;
// //     });

// //     try {
// //       final user = supabase.auth.currentUser;
// //       if (user == null) {
// //         throw Exception("Session expired");
// //       }

// //       // ✅ UPDATE USERS TABLE
// //       await supabase
// //           .from('users')
// //           .update({
// //             'name': _nameController.text.trim(),
// //             'reg_no': _regController.text.trim(),
// //           })
// //           .eq('id', user.id)
// //           .timeout(
// //             const Duration(seconds: 20),
// //             onTimeout: () =>
// //                 throw TimeoutException("Profile update timed out"),
// //           );

// //       // ✅ UPDATE HIVE (OFFLINE CACHE)
// //       final loginBox = Hive.box<LoginModel>('loginBox');

// //       loginBox.put(
// //         'profile',
// //         LoginModel(
// //           name: _nameController.text.trim(),
// //           email: widget.profile['email'],
// //           role: widget.profile['role'],
// //           reg_no: _regController.text.trim(),
// //         ),
// //       );

// //       if (!mounted) return;

// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(
// //           content: const Row(
// //             children: [
// //               Icon(Icons.check_circle, color: Colors.white),
// //               SizedBox(width: 10),
// //               Expanded(child: Text("Profile updated successfully")),
// //             ],
// //           ),
// //           backgroundColor: Colors.green,
// //           behavior: SnackBarBehavior.floating,
// //           shape: RoundedRectangleBorder(
// //             borderRadius: BorderRadius.circular(12),
// //           ),
// //         ),
// //       );

// //       Navigator.pop(context, true);
// //     } on SocketException {
// //       setState(() => _errorMsg = "No internet connection");
// //     } on TimeoutException {
// //       setState(() => _errorMsg = "Request timed out. Try again");
// //     } on PostgrestException catch (e) {
// //       setState(() => _errorMsg = "Database error: ${e.message}");
// //     } catch (e) {
// //       setState(() => _errorMsg = "Unexpected error: $e");
// //     } finally {
// //       setState(() => _saving = false);
// //     }
// //   }

// //   // ---------------- UI ----------------
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: Theme.of(context).scaffoldBackgroundColor,
// //       appBar: AppBar(
// //         centerTitle: true,
// //         iconTheme: const IconThemeData(color: Colors.white),
// //         title: const Text(
// //           "Update Profile",
// //           style: TextStyle(
// //             color: Colors.white,
// //             fontSize: 20,
// //             fontWeight: FontWeight.w600,
// //           ),
// //         ),
// //       ),
// //       body: Padding(
// //         padding: const EdgeInsets.all(20),
// //         child: Form(
// //           key: _formKey,
// //           child: ListView(
// //             children: [
// //               TextFormField(
// //                 controller: _nameController,
// //                 decoration: const InputDecoration(labelText: "First Name"),
// //                 validator: (v) =>
// //                     v == null || v.isEmpty ? "Enter your first name" : null,
// //               ),

// //               const SizedBox(height: 16),

// //               TextFormField(
// //                 controller: _regController,
// //                 decoration:
// //                     const InputDecoration(labelText: "Last Name"),
// //                 validator: (v) =>
// //                     v == null || v.isEmpty ? "Enter your last name" : null,
// //               ),

// //               const SizedBox(height: 30),

// //               SizedBox(
// //                 width: double.infinity,
// //                 child: ElevatedButton(
// //                   onPressed: _saving ? null : _updateProfile,
// //                   style: ElevatedButton.styleFrom(
// //                     backgroundColor: Theme.of(context).primaryColor,
// //                     padding: const EdgeInsets.symmetric(vertical: 16),
// //                     shape: RoundedRectangleBorder(
// //                       borderRadius: BorderRadius.circular(12),
// //                     ),
// //                   ),
// //                   child: _saving
// //                       ? const SizedBox(
// //                           height: 22,
// //                           width: 22,
// //                           child: CircularProgressIndicator(
// //                             color: Colors.white,
// //                             strokeWidth: 2,
// //                           ),
// //                         )
// //                       : const Text(
// //                           "Save Changes",
// //                           style: TextStyle(
// //                             color: Colors.white,
// //                             fontSize: 16,
// //                             fontWeight: FontWeight.w600,
// //                           ),
// //                         ),
// //                 ),
// //               ),

// //               if (_errorMsg != null) ...[
// //                 const SizedBox(height: 14),
// //                 Center(
// //                   child: Text(
// //                     _errorMsg!,
// //                     style: const TextStyle(color: Colors.red),
// //                   ),
// //                 ),
// //               ],
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }

// import 'dart:async';
// import 'dart:io';

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:hive/hive.dart';
// import 'package:smartclass/models/login_model.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// class UpdatePage extends StatefulWidget {
//   final Map<String, dynamic> profile;

//   const UpdatePage({
//     super.key,
//     required this.profile,
//   });

//   @override
//   State<UpdatePage> createState() => _UpdatePageState();
// }

// class _UpdatePageState extends State<UpdatePage> {
//   final _formKey = GlobalKey<FormState>();
//   final supabase = Supabase.instance.client;

//   final TextEditingController _firstNameController = TextEditingController();
//   final TextEditingController _lastNameController = TextEditingController();

//   bool _saving = false;
//   String? _errorMsg;

//   // ✅ Strict regex
//   final RegExp nameRegex = RegExp(r'^[A-Za-z]+( [A-Za-z]+)*$');

//   @override
//   void initState() {
//     super.initState();

//     final fullName = widget.profile['name'] ?? "";
//     final parts = fullName.split(" ");

//     _firstNameController.text = parts.isNotEmpty ? parts[0] : "";
//     _lastNameController.text =
//         parts.length > 1 ? parts.sublist(1).join(" ") : "";
//   }

//   @override
//   void dispose() {
//     _firstNameController.dispose();
//     _lastNameController.dispose();
//     super.dispose();
//   }

//   // ---------------- UPDATE PROFILE ----------------
//   Future<void> _updateProfile() async {
//     if (!_formKey.currentState!.validate()) return;

//     setState(() {
//       _saving = true;
//       _errorMsg = null;
//     });

//     try {
//       final user = supabase.auth.currentUser;
//       if (user == null) {
//         throw Exception("Session expired");
//       }

//       final fullName =
//           "${_firstNameController.text} ${_lastNameController.text}";

//       // ✅ UPDATE DB (only name)
//       await supabase
//           .from('users')
//           .update({
//             'name': fullName,
//           })
//           .eq('id', user.id)
//           .timeout(
//             const Duration(seconds: 20),
//             onTimeout: () =>
//                 throw TimeoutException("Profile update timed out"),
//           );

//       // ✅ UPDATE LOCAL CACHE
//       final loginBox = Hive.box<LoginModel>('loginBox');

//       loginBox.put(
//         'profile',
//         LoginModel(
//           name: fullName,
//           email: widget.profile['email'],
//           role: widget.profile['role'],
//           reg_no: null, // removed
//         ),
//       );

//       if (!mounted) return;

//       // ✅ SUCCESS MESSAGE
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: const Row(
//             children: [
//               Icon(Icons.check_circle, color: Colors.white),
//               SizedBox(width: 10),
//               Expanded(
//                 child: Text(
//                   "Profile updated successfully 🎉",
//                   style: TextStyle(fontWeight: FontWeight.w500),
//                 ),
//               ),
//             ],
//           ),
//           backgroundColor: Colors.green,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );

//       Navigator.pop(context, true);
//     } on SocketException {
//       setState(() => _errorMsg = "No internet connection");
//     } on TimeoutException {
//       setState(() => _errorMsg = "Request timed out. Try again");
//     } on PostgrestException catch (e) {
//       setState(() => _errorMsg = "Database error: ${e.message}");
//     } catch (e) {
//       setState(() => _errorMsg = "Unexpected error: $e");
//     } finally {
//       setState(() => _saving = false);
//     }
//   }

//   // ---------------- VALIDATOR ----------------
//   String? validateName(String? v, String field) {
//     if (v == null || v.isEmpty) {
//       return "Enter your $field";
//     }

//     if (v != v.trim()) {
//       return "No leading or trailing spaces allowed";
//     }

//     if (!nameRegex.hasMatch(v)) {
//       return "Only alphabets allowed";
//     }

//     return null;
//   }

//   // ---------------- UI ----------------
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Update Profile"),
//         centerTitle: true,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Form(
//           key: _formKey,
//           child: ListView(
//             children: [
//               // 🔹 FIRST NAME
//               TextFormField(
//                 controller: _firstNameController,
//                 decoration: const InputDecoration(labelText: "First Name"),
//                 inputFormatters: [
//                   FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z ]')),
//                 ],
//                 validator: (v) => validateName(v, "first name"),
//               ),

//               const SizedBox(height: 16),

//               // 🔹 LAST NAME
//               TextFormField(
//                 controller: _lastNameController,
//                 decoration: const InputDecoration(labelText: "Last Name"),
//                 inputFormatters: [
//                   FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z ]')),
//                 ],
//                 validator: (v) => validateName(v, "last name"),
//               ),

//               const SizedBox(height: 30),

//               ElevatedButton(
//                 onPressed: _saving ? null : _updateProfile,
//                 child: _saving
//                     ? const CircularProgressIndicator(color: Colors.white)
//                     : const Text("Save Changes"),
//               ),

//               if (_errorMsg != null) ...[
//                 const SizedBox(height: 14),
//                 Center(
//                   child: Text(
//                     _errorMsg!,
//                     style: const TextStyle(color: Colors.red),
//                   ),
//                 ),
//               ],
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }