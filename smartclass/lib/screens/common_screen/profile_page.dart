import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smartclass/models/login_model.dart';
import 'package:smartclass/screens/continueWithGoogle.dart';
import 'package:smartclass/screens/common_screen/update.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chatbot_page.dart' show chatHistory;

class ProfilePage extends StatelessWidget {
  final Map<String, dynamic> cls;

  const ProfilePage({super.key, required this.cls});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<LoginModel>('loginBox');
    final supabase = Supabase.instance.client;

    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (_, Box<LoginModel> box, __) {
        final profile = box.get('profile');

        if (profile == null) {
          return _buildNoProfile(context);
        }

        final isOwner = cls['created_by'] == supabase.auth.currentUser?.id;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              "My Profile",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          body: _buildProfile(context, profile, isOwner),
        );
      },
    );
  }

  // ---------------- PROFILE UI ----------------
  Widget _buildProfile(
    BuildContext context,
    LoginModel profile,
    bool isOwner,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(blurRadius: 15, offset: Offset(0, 8)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundImage: profile.avatarUrl != null
                      ? NetworkImage(profile.avatarUrl!)
                      : null,
                  child: profile.avatarUrl == null
                      ? const Icon(Icons.person, size: 48)
                      : null,
                ),

                const SizedBox(height: 18),

                Text(
                  profile.name, // ✅ ALWAYS UPDATED
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  profile.email,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),

                const Divider(height: 32),

                if (profile.reg_no != null && profile.reg_no!.isNotEmpty)
                  _infoTile(
                    context,
                    Icons.confirmation_number,
                    "Register Number",
                    profile.reg_no,
                  ),

                const SizedBox(height: 14),

                _infoTile(
                  context,
                  Icons.class_,
                  "Class",
                  cls['name'] ?? "Not Assigned",
                ),

                const SizedBox(height: 14),

                _infoTile(
                  context,
                  Icons.badge,
                  "Role",
                  isOwner ? "Teacher" : "Student",
                ),

                const SizedBox(height: 28),

                ElevatedButton.icon(
                  icon: const Icon(Icons.update, color: Colors.white),
                  label: const Text("Update Profile"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UpdatePage(profile: {
                          'name': profile.name,
                          'email': profile.email,
                          'reg_no': profile.reg_no,
                          'avatar_url': profile.avatarUrl,
                          'role': profile.role,
                        }),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- NO PROFILE ----------------
  static Widget _buildNoProfile(BuildContext context) {
    return const Center(child: Text("No profile found"));
  }

  // ---------------- LOGOUT ----------------
  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    await Hive.box<LoginModel>('loginBox').clear();
    chatHistory.clear();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ContinueWithGoogle()),
      (_) => false,
    );
  }

  // ---------------- INFO TILE ----------------
  Widget _infoTile(
    BuildContext context,
    IconData icon,
    String label,
    dynamic value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(child: Text("$label: $value")),
        ],
      ),
    );
  }
}
