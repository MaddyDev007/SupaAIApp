import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smartclass/models/login_model.dart';
import 'package:smartclass/screens/continueWithGoogle.dart';
import 'package:smartclass/screens/common_screen/update.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chatbot_page.dart' show chatHistory;
import 'package:http/http.dart' as http;

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
            color: Theme.of(context).cardColor.withAlpha((0.95 * 255).toInt()),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).primaryColor,
              width: 1.5,
            ),
            boxShadow:  [
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
                  Icons.code,
                  "Code",
                  cls['code'] ?? "Not Assigned",
                ),

                const SizedBox(height: 14),

                _infoTile(
                  context,
                  Icons.badge,
                  "Role",
                  isOwner ? "Teacher" : "Student",
                ),

                const SizedBox(height: 28),

                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 10,
                 
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.update, color: Colors.white),
                      label: const Text("Update Profile", style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                      ),
                      onPressed: () {
                        _pushAnimation(
                          context,
                          UpdatePage(profile: {
                              'name': profile.name,
                              'email': profile.email,
                              'reg_no': profile.reg_no,
                              'avatar_url': profile.avatarUrl,
                              'role': profile.role,
                            }),
                          
                        );
                      },
                    ),
                    isOwner ?
                    ElevatedButton.icon(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text("Delete Classroom", style: TextStyle(color: Colors.white),),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      onPressed: () => _deleteClass(context, cls['id']),
                    ) : 
                    const SizedBox.shrink(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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


  // ---------------- NO PROFILE ----------------
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

  // ---------------- LOGOUT ----------------
  Future<void> _logout(BuildContext context) async {
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

    await Supabase.instance.client.auth.signOut();
    await Hive.box<LoginModel>('loginBox').clear();
    chatHistory.clear();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ContinueWithGoogle()),
      (_) => false,
    );
  }
  /* Future<void> _deleteClass(BuildContext context, String classId) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.delete_forever, color: Color(0xFFFF5252)),
          SizedBox(width: 10),
          Text('Delete Classroom'),
        ],
      ),
      content: const Text(
        'Are you sure you want to delete this classroom?\n\n'
        'This action cannot be undone.',
      ),
      actions: [
        TextButton(
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey),
          ),
          onPressed: () => Navigator.pop(ctx, false),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFFFF5252),
          ),
          child: const Text(
            'Delete',
            style: TextStyle(color: Colors.white),
          ),
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  try {
    // 🧨 Delete class (cascade will handle related tables)
    await Supabase.instance.client
        .from('classes')
        .delete()
        .eq('id', classId);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Classroom deleted successfully')),
    );

    // 🔙 Go back to class list
    Navigator.popUntil(context, (route) => route.isFirst);

  } catch (e) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to delete classroom: $e')),
    );
  }
}
 */
 
 Future<void> _deleteClass(BuildContext context, String classId) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.delete_forever, color: Color(0xFFFF5252)),
          SizedBox(width: 10),
          Text('Delete Classroom'),
        ],
      ),
      content: const Text(
        'This will permanently delete:\n'
        '• All lesson materials\n'
        '• All quizzes & question files\n'
        '• All student notes of this class\n'
        '• All results\n'
        '• All students from this class\n\n'
        'This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFFFF5252),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  try {
    // 🔄 Show loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // ✅ CALL FASTAPI BACKEND
    final response = await http.delete(
      Uri.parse(
        'https://supaaiapp-1.onrender.com/delete/class?class_id=$classId',
      ),
      // Uri.parse('http://10.0.2.2:8000/delete/class?class_id=$classId'),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (!context.mounted) return;

    Navigator.pop(context); // close loader

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Classroom deleted successfully'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.popUntil(context, (route) => route.isFirst);
  } catch (e) {
    if (!context.mounted) return;

    Navigator.pop(context); // close loader if open

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ Failed to delete classroom: $e'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

  // ---------------- INFO TILE ----------------
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
            child: SelectableText(
              
                "$label: ${value ?? "-"}",
                style: const TextStyle(fontSize: 15),
              
            ),
          ),
        ],
      ),
    );
  }
}
