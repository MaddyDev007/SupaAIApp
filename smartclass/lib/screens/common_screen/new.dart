import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smartclass/main.dart';
import 'package:smartclass/models/login_model.dart';
import 'package:smartclass/screens/common_screen/update.dart';
import 'package:smartclass/screens/continueWithGoogle.dart';
import 'package:smartclass/screens/theme/theme_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chatbot_page.dart' show chatHistory;

class ProfilePageNew extends StatelessWidget {
  const ProfilePageNew({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<LoginModel>('loginBox');

    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, Box<LoginModel> box, _) {
        final profile = box.get('profile');

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
      letterSpacing: 1.1,
    ),
  ),
  actions: [
    PopupMenuButton<ThemeMode>(
      color: Theme.of(context).cardColor,
      icon: const Icon(Icons.brightness_6, color: Colors.white),
      onSelected: (mode) {
        themeModeNotifier.value = mode;
        ThemeService.saveTheme(mode);
      },
      itemBuilder: (_) =>  [
        PopupMenuItem(
          value: ThemeMode.system,
          child: Row(
            spacing: 10,
            children: [
              Icon(Icons.computer,color: Theme.of(context).dividerColor,),
              Text("System default"),
            ],
          ),
        ),
        PopupMenuItem(
          value: ThemeMode.light,
          child: Row(
            spacing: 10,
            children: [
              Icon(Icons.sunny,color: Theme.of(context).dividerColor,),
              Text("Light mode"),
            ],
          ),
        ),
        PopupMenuItem(
          value: ThemeMode.dark,
          child:  Row(
            spacing: 10,
            children: [
              Icon(Icons.nights_stay,color: Theme.of(context).dividerColor,),
              Text("Dark mode"),
            ],
          ),
        ),
      ],
    ),
  ],
),

          body: profile == null
              ? _buildNoProfile(context)
              : _buildProfile(context, profile),
        );
      },
    );
  }

  // ================= PROFILE =================
  Widget _buildProfile(BuildContext context, LoginModel profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      
      child: Column(
        children: [
          const SizedBox(height: 160,),
          Center(
            
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 450),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(context).primaryColor,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context)
                        .primaryColor
                        .withAlpha((0.15 * 255).toInt()),
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
                      backgroundColor: Colors.blueAccent,
                      radius: 50,
                      backgroundImage: profile.avatarUrl != null
                          ? NetworkImage(profile.avatarUrl!)
                          : null,
                      child: profile.avatarUrl == null
                          ? const Icon(Icons.person, size: 48,color: Colors.white,)
                          : null,
                    ),
          
                    const SizedBox(height: 20),
          
                    Text(
                      profile.name, // ✅ AUTO-UPDATES
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
          
                    const SizedBox(height: 30),
          
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                        ElevatedButton.icon(
                          icon: const Icon(Icons.logout, color: Colors.white),
                          label: const Text("Logout", style: TextStyle(color: Colors.white)),
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
        ],
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

  // ================= NO PROFILE =================
  Widget _buildNoProfile(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () => _logout(context),
        child: const Text("Logout"),
      ),
    );
  }

  // ================= LOGOUT =================
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
}
