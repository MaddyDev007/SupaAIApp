import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:smartclass/models/login_model.dart';
import 'package:smartclass/screens/continueWithGoogle.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chatbot_page.dart' show chatHistory;

class ProfilePageNew extends StatelessWidget {
  final LoginModel? profile;

  const ProfilePageNew({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        centerTitle: true,
      ),
      body: profile == null
          ? _buildNoProfile(context)
          : _buildProfile(context),
    );
  }

  // ================= NO PROFILE =================
  Widget _buildNoProfile(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.logout),
        label: const Text('Logout'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
        onPressed: () => _logout(context),
      ),
    );
  }

  // ================= PROFILE =================
  Widget _buildProfile(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: profile!.avatarUrl != null
                  ? NetworkImage(profile!.avatarUrl!)
                  : null,
              child: profile!.avatarUrl == null
                  ? const Icon(Icons.person, size: 48)
                  : null,
            ),

            const SizedBox(height: 20),

            Text(
              profile!.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              profile!.email,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),

            const SizedBox(height: 30),

            ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }

  // ================= LOGOUT =================
  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 1️⃣ Supabase sign out
    await Supabase.instance.client.auth.signOut();

    // 2️⃣ Clear LoginModel cache
    await Hive.box<LoginModel>('loginBox').clear();

    // 3️⃣ Clear chatbot history
    chatHistory.clear();

    // 4️⃣ Go to login
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ContinueWithGoogle()),
      (_) => false,
    );
  }
}
