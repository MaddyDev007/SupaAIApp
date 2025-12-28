import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:smartclass/models/login_model.dart';
import 'package:smartclass/screens/common_screen/new.dart';
import 'package:smartclass/screens/student_screen/sem_result.dart';
import 'package:smartclass/screens/student_screen/student_dashboard.dart';
import 'package:smartclass/screens/teacher_screen/teacher_dashboard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommonDashboard extends StatefulWidget {
  const CommonDashboard({super.key});

  @override
  State<CommonDashboard> createState() => _CommonDashboardState();
}

class _CommonDashboardState extends State<CommonDashboard>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  late TabController _tabController;

  late Box<LoginModel> loginBox;
  LoginModel? loginUser;

  List<Map<String, dynamic>> joinedClasses = [];
  List<Map<String, dynamic>> createdClasses = [];
  bool loading = true;
  late final AnimationController _listController;
  late final Animation<double> _listAnimation;

  // ================= INIT =================
  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _listAnimation = CurvedAnimation(
      parent: _listController,
      curve: Curves.easeOut,
    );

    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    loginBox = Hive.box<LoginModel>('loginBox');
    // Use the same key as other parts of the app (UpdatePage writes to 'profile')
    loginUser = loginBox.get('profile');

    fetchClasses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _listController.dispose();
    super.dispose();
  }

  // ================= NAV ANIMATION =================
  static const _curve = Cubic(0.22, 0.61, 0.36, 1.0);
  static final _slideTween = Tween<Offset>(
    begin: Offset(1, 0),
    end: Offset.zero,
  );

  Future<dynamic> pushWithAnimation(BuildContext context, Widget page) {
    return Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(parent: animation, curve: _curve);
          return SlideTransition(
            position: _slideTween.animate(curved),
            child: child,
          );
        },
      ),
    );
  }

  // ================= FETCH CLASSES =================
  Future<void> fetchClasses() async {
    setState(() => loading = true);
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final joinedRes = await supabase
        .from('class_members')
        .select('classes(*)')
        .eq('user_id', user.id)
        .timeout(
          const Duration(seconds: 12),
          onTimeout: () => throw TimeoutException('Class fetch timed out'),
        );

    final joined = joinedRes
        .map<Map<String, dynamic>>((e) => e['classes'])
        .toList();

    final createdRes = await supabase
        .from('classes')
        .select()
        .eq('created_by', user.id);

    setState(() {
      joinedClasses = joined.where((c) => c['created_by'] != user.id).toList();
      createdClasses = createdRes;
      loading = false;
    });
    _listController.forward(from: 0);
  }

  // ================= CLASS CODE =================
  String generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  // ================= CREATE CLASS =================
  Future<void> createClass() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Create Class'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Subject name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
            child: const Text('Create', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              final user = supabase.auth.currentUser!;
              final code = generateCode();
              final profile = await supabase
                  .from('users')
                  .select('name')
                  .eq('id', user.id)
                  .single();

              final classRes = await supabase
                  .from('classes')
                  .insert({
                    'name': controller.text.trim(),
                    'code': code,
                    'created_by': user.id,
                    'user_name': profile['name'],
                  })
                  .select()
                  .single();
              // 1️⃣ Fetch user profile

              await supabase.from('class_members').insert({
                'class_id': classRes['id'],
                'user_id': user.id,
                'student': false,
              });

              if (!mounted) return;
              Navigator.pop(ctx);
              fetchClasses();
            },
          ),
        ],
      ),
    );
  }

  // ================= JOIN CLASS =================
  Future<void> joinClass() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Join Class'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Class code'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
            child: const Text('Join', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              final user = supabase.auth.currentUser!;
              final code = controller.text.trim().toUpperCase();

              try {
                final cls = await supabase
                    .from('classes')
                    .select()
                    .eq('code', code)
                    .maybeSingle();

                if (cls == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid class code')),
                  );
                  return;
                }

                if (cls['created_by'] == user.id) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('You already created this class'),
                    ),
                  );
                  return;
                }

                await supabase.from('class_members').insert({
                  'class_id': cls['id'],
                  'user_id': user.id,
                  'student': true,
                });

                if (!mounted) return;
                Navigator.pop(ctx);
                fetchClasses();
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Already joined this class')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ================= CLASS LIST =================
  Widget buildClassList(List<Map<String, dynamic>> list) {
    if (loading) {
      return Center(
        child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
      );
    }

    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 200),
          Center(child: Text('No classes')),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        return _buildMaterialCard(list, i);
      },
    );
  }

  Widget _buildMaterialCard(List<Map<String, dynamic>> list, int index) {
    final cls = list[index];
    final teachername = cls['user_name'] ?? '';

    final currentUserId = supabase.auth.currentUser?.id;
    final isOwner = currentUserId != null && cls['created_by'] == currentUserId;

    final slideTween = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOut));

    return FadeTransition(
      opacity: _listAnimation,
      child: SlideTransition(
        position: _listAnimation.drive(slideTween),
        child: Card(
          color: Theme.of(context).cardColor,
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),

             splashColor: Theme.of(context).primaryColor.withOpacity(0.1),
            onTap: () {
              pushWithAnimation(
                context,
                isOwner
                    ? TeacherDashboard(cls: cls)
                    : StudentDashboard(cls: cls),
              ).then((_) {
                if (mounted) fetchClasses();
              });
            },

            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 20.0,
                horizontal: 23.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 5,
                    children: [
                      Text(cls['name']),
                      SelectableText('Code: ${cls['code']}'),
                      const SizedBox(height: 15),
                      Text(teachername),
                    ],
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final avatarUrl = loginUser?.avatarUrl;
    if (user == null) {
      Future.microtask(() {
        Navigator.pushReplacementNamed(context, '/loginGoogle');
      });
      return const SizedBox();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Classes'),
        bottom: TabBar(
          unselectedLabelColor: Colors.white60,
          labelColor: Colors.white,
          indicatorColor: Colors.white,
          physics: const BouncingScrollPhysics(),
          controller: _tabController,
          tabs: const [
            Tab(text: 'Joined'),
            Tab(text: 'Created'),
            Tab(text: 'semester'),
          ],
        ),
        actions: [
          IconButton(
            icon: CircleAvatar(
              radius: 15, // AppBar-friendly size
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? const Icon(Icons.person, size: 20)
                  : null,
            ),
            onPressed: () async {
              final res = await pushWithAnimation(context, ProfilePageNew());
              if (res == true) {
                setState(() {
                  loginUser = loginBox.get('profile');
                });
              }
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RefreshIndicator(
            onRefresh: fetchClasses,
            color: Theme.of(context).primaryColor,
            child: buildClassList(joinedClasses),
          ),
          RefreshIndicator(
            onRefresh: fetchClasses,
            color: Theme.of(context).primaryColor,
            child: buildClassList(createdClasses),
          ),
          SemResultPage(),
        ],
      ),

      floatingActionButton: _tabController.index == 2
          ? null
          : FloatingActionButton(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              onPressed: () {
                if (_tabController.index == 0) {
                  joinClass();
                } else {
                  createClass();
                }
              },
              child: const Icon(Icons.add),
            ),
    );
  }
}
