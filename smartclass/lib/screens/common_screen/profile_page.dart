import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:smartclass/models/user_model.dart';
import 'package:smartclass/screens/login_page.dart';
import 'package:smartclass/screens/common_screen/update.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chatbot_page.dart' show chatHistory;

class ProfilePage extends StatelessWidget {
  final Map<String, dynamic>? profile;

  const ProfilePage({required this.profile, super.key});

  @override
  Widget build(BuildContext context) {
    final student = profile;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "My Profile",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            letterSpacing: 1.1,
          ),
        ),
        centerTitle: true,
      ),

      body: student == null
          ? _buildNoProfile(context)
          : _buildProfile(context, student),
    );
  }

  Widget _buildNoProfile(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'No profile found.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500,
            color: Theme.of(context).textTheme.bodySmall?.color,),
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text(
              "Logout",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
            onPressed: () => _logout(context),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile(BuildContext context, Map<String, dynamic> student) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 450),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withAlpha((0.95 * 255).toInt()),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).primaryColor.withAlpha((0.15 * 255).toInt()),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Theme.of(context).splashColor,
                  child:Icon(Icons.person, size: 55, color: Theme.of(context).primaryColor),
                ),

                const SizedBox(height: 18),
                Text(
                  student['name'] ?? "Unknown",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),
                Text(
                  student['email'] ?? "No Email",
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),

                const Divider(height: 30),

                if (student['reg_no'] != null && student['reg_no'] != "")
                  _infoTile(context, Icons.confirmation_number, "Register Number",
                      student['reg_no']),

                const SizedBox(height: 14),
                _infoTile(context, Icons.school, "Department", student['department']),
                const SizedBox(height: 14),
                _infoTile(context, Icons.calendar_today, "Year", student['year']),

                const SizedBox(height: 14),
                _infoTile(context,
                  Icons.badge,
                  "Role",
                  student['role'].toString().contains("teacher")
                      ? "Teacher"
                      : "Student",
                ),

                const SizedBox(height: 28),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  spacing: 10,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.update, color: Colors.white),
                      label: const Text("Update Profile", style: TextStyle(color: Colors.white),),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                      ),
                      onPressed: () => _pushAnimation(context, UpdatePage(
                        profile: student,
                      )),
                    ),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text("Logout", style: TextStyle(color: Colors.white),),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      onPressed: () => _logout(context),
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

  Future<void> _logout(BuildContext context) async {
    // ✅ Show confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.logout_rounded, color: Color(0xFFFF5252)),
            SizedBox(width: 10),
            Text('Confirm Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.grey),),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFF5252)),
            child: const Text('Yes, Logout', style: TextStyle(color: Colors.white),),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // ✅ 1. Clear Supabase session
    await Supabase.instance.client.auth.signOut();

    // ✅ 2. Clear Hive offline profile
    final userBox = Hive.box<UserModel>('userBox');
    await userBox.clear();

    // ✅ 3. Clear chatbot history
    chatHistory.clear();

    // ✅ 4. Navigate to login
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }
  static const _curve = Cubic(0.22, 0.61, 0.36, 1.0);

  void _pushAnimation(BuildContext context, Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: _curve,
          );

          return SlideTransition(
            position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                .animate(curved),
            child: child,
          );
        },
      ),
    );
  }

  Widget _infoTile(BuildContext context,IconData icon, String label, dynamic value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "$label: ${value ?? "-"}",
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
