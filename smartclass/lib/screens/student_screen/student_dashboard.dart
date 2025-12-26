import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:smartclass/models/login_model.dart';
import 'package:smartclass/screens/common_screen/profile_page.dart';
import 'package:smartclass/screens/student_screen/sem_result.dart';
import 'quiz_list_page.dart';
import '../common_screen/chatbot_page.dart';
import 'view_materials_page.dart';
import 'viewqnpdf.dart';
import 'notes_page.dart';
import 'analytics_dashboard.dart';

class StudentDashboard extends StatefulWidget {
  final Map<String, dynamic> cls; // ✅ selected class

  const StudentDashboard({super.key, required this.cls});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _selectedIndex = 0;

  late Box<LoginModel> loginBox;
  LoginModel? loginUser;

  // opacity helpers (unchanged)
  int a85 = (0.85 * 255).round();
  int a25 = (0.25 * 255).round();
  int a20 = (0.20 * 255).round();
  int a15 = (0.15 * 255).round();
  int a05 = (0.05 * 255).round();
  int a70 = (0.70 * 255).round();
  int a60 = (0.60 * 255).round();

  @override
  void initState() {
    super.initState();
    loginBox = Hive.box<LoginModel>('loginBox');
    loginUser = loginBox.get('login'); // ✅ correct & offline-safe
  }

  // ---------------- NAV ----------------
  void _onNavTapped(int index) {
    if (index == 4) {
      return pushWithAnimation(
        context,
        SemResultPage(),
      );
    }
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
    }
  }

  // ---------------- DASHBOARD CARDS ----------------
  List<Widget> _buildAllCards() {
    final classId = widget.cls['id'];

    return [
      _dashboardCard(
        title: 'Start Quiz',
        subtitle: 'Test your knowledge',
        icon: Icons.menu_book_rounded,
        color: Colors.orange,
        onTap: () => pushWithAnimation(context, QuizListPage(classId: classId)),
      ),
      _dashboardCard(
        title: 'Ask Chatbot',
        subtitle: 'Instant smart help',
        icon: Icons.smart_toy_outlined,
        color: Colors.green,
        onTap: () => pushWithAnimation(context, ChatbotPage(classId: classId)),
      ),
      _dashboardCard(
        title: 'View Materials',
        subtitle: 'Access study resources',
        icon: Icons.picture_as_pdf,
        color: Colors.blue,
        onTap: () =>
            pushWithAnimation(context, ViewMaterialsPage(classId: classId)),
      ),
      _dashboardCard(
        title: 'Question Banks',
        subtitle: 'Practice with QNs',
        icon: Icons.folder_copy_rounded,
        color: Colors.purple,
        onTap: () =>
            pushWithAnimation(context, ViewMaterialsQNPage(classId: classId)),
      ),
      _dashboardCard(
        title: 'Notes',
        subtitle: 'Personal study notes',
        icon: Icons.edit_note_rounded,
        color: const Color(0xFF3559C7),
        onTap: () => pushWithAnimation(context, NotesPage()),
      ),
      _dashboardCard(
        title: 'Analytics',
        subtitle: 'Track your progress',
        icon: Icons.bar_chart_rounded,
        color: Colors.red,
        onTap: () =>
            pushWithAnimation(context, AnalyticsDashboard(classId: classId)),
      ),
    ];
  }

  // ---------------- CARD UI (UNCHANGED) ----------------
  Widget _dashboardCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(a25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withAlpha(a20), width: 1.2),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withAlpha(a15),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- ANIMATION ----------------
  static const _curve = Cubic(0.22, 0.61, 0.36, 1.0);
  static final _slideTween = Tween<Offset>(
    begin: const Offset(1, 0),
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

  // ---------------- BOTTOM NAV FILTER ----------------
  List<Widget> _getVisibleCards(List<Widget> all) {
    switch (_selectedIndex) {
      case 1:
        return [all[2], all[3]];
      case 2:
        return [all[0]];
      case 3:
        return [all[1]];
      default:
        return all;
    }
  }

  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    final className = widget.cls['name'] ?? 'Class';
    final name = loginUser?.name ?? 'Student';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
          ),
          child: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              className, // ✅ class context
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.account_circle,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () {
                  pushWithAnimation(
                    context,
                    ProfilePage(
                      profile: {
                        "name": loginUser?.name,
                        "email": loginUser?.email,
                        "avatar_url": loginUser?.avatarUrl,
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            Text(
              "Welcome $name 👋",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final double cardWidth = 220;
                final double cardHeight = 200;
                final int crossAxisCount = (constraints.maxWidth ~/ 260).clamp(
                  1,
                  4,
                );

                final visibleCards = _getVisibleCards(_buildAllCards());

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    mainAxisExtent: cardHeight,
                  ),
                  itemCount: visibleCards.length,
                  itemBuilder: (context, index) {
                    return SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: visibleCards[index],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 70,
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavTapped,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: "Home"),
          NavigationDestination(
            icon: Icon(Icons.picture_as_pdf_outlined),
            label: "Materials",
          ),
          NavigationDestination(icon: Icon(Icons.quiz_outlined), label: "Quiz"),
          NavigationDestination(icon: Icon(Icons.chat_outlined), label: "Chat"),
          NavigationDestination(
            icon: Icon(Icons.web_outlined),
            label: "Sem Result",
          ),
        ],
      ),
    );
  }
}
