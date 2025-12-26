import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:smartclass/models/login_model.dart';
import 'package:smartclass/screens/common_screen/new.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommonDashboard extends StatefulWidget {
  const CommonDashboard({super.key});

  @override
  State<CommonDashboard> createState() => _CommonDashboardState();
}

class _CommonDashboardState extends State<CommonDashboard>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  late TabController _tabController;

  late Box<LoginModel> loginBox;
  LoginModel? loginUser;

  List<Map<String, dynamic>> joinedClasses = [];
  List<Map<String, dynamic>> createdClasses = [];
  bool loading = true;

  // ================= INIT =================
  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    loginBox = Hive.box<LoginModel>('loginBox');
    loginUser = loginBox.get('login');

    fetchClasses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ================= NAV ANIMATION =================
  static const _curve = Cubic(0.22, 0.61, 0.36, 1.0);
  static final _slideTween = Tween<Offset>(
    begin: Offset(1, 0),
    end: Offset.zero,
  );

  void pushWithAnimation(BuildContext context, Widget page) {
    Navigator.push(
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
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final joinedRes = await supabase
        .from('class_members')
        .select('classes(*)')
        .eq('user_id', user.id);

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
        title: const Text('Create Class'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Subject name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            child: const Text('Create'),
            onPressed: () async {
              final user = supabase.auth.currentUser!;
              final code = generateCode();

              final classRes = await supabase
                  .from('classes')
                  .insert({
                    'name': controller.text.trim(),
                    'code': code,
                    'created_by': user.id,
                  })
                  .select()
                  .single();

              await supabase.from('class_members').insert({
                'class_id': classRes['id'],
                'user_id': user.id,
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
        title: const Text('Join Class'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Class code'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            child: const Text('Join'),
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
      return const Center(child: CircularProgressIndicator());
    }

    if (list.isEmpty) {
      return const Center(child: Text('No classes'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final cls = list[i];
        final isOwner = cls['created_by'] == supabase.auth.currentUser!.id;

        return Card(
          child: ListTile(
            title: Text(cls['name']),
            subtitle: Text('Code: ${cls['code']}'),
            onTap: () {
              Navigator.pushNamed(
                context,
                isOwner ? '/teacher-dashboard' : '/student-dashboard',
                arguments: cls,
              );
            },
          ),
        );
      },
    );
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
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
          controller: _tabController,
          tabs: const [
            Tab(text: 'Joined'),
            Tab(text: 'Created'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, size: 28),
            onPressed: () {
              pushWithAnimation(context, ProfilePageNew(profile: loginUser));
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          buildClassList(joinedClasses),
          buildClassList(createdClasses),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _tabController.index == 0 ? joinClass() : createClass();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
