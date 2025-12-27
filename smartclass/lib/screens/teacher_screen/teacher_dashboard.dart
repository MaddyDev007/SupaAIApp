import 'package:flutter/material.dart';
import 'package:smartclass/screens/common_screen/profile_page.dart';
import 'upload_material_page.dart';
import 'result_page.dart';
import 'teacher_analytics_dashboard.dart';
import '../common_screen/chatbot_page.dart';
import 'view_material_teacher.dart';
import 'view_qnbank_teacher.dart';
import 'package:hive/hive.dart';
import 'package:smartclass/models/login_model.dart';

class TeacherDashboard extends StatefulWidget {
  final Map<String, dynamic> cls; // ✅ selected class

  const TeacherDashboard({super.key, required this.cls});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;

  // ✅ OFFLINE LOGIN MODEL
  late final Box<LoginModel> loginBox;
  LoginModel? loginUser;

  @override
  void initState() {
    super.initState();
    loginBox = Hive.box<LoginModel>('loginBox');
    // Use the same key as UpdatePage and other readers
    loginUser = loginBox.get('profile'); // ✅ offline-safe
  }

  void _onNavTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  // ---------------- DASHBOARD CARDS ----------------
  List<Widget> _buildAllCards() {
    final classId = widget.cls['id'];

    return [
      _dashboardCard(
        title: 'Upload Material',
        subtitle: 'Share resources with students',
        icon: Icons.upload_file,
        color: Colors.orange,
        onTap: () =>
            pushWithAnimation(context, UploadMaterialPage(classId: classId)),
      ),
      _dashboardCard(
        title: 'Chatbot Assistant',
        subtitle: 'Get instant help and support',
        icon: Icons.smart_toy_outlined,
        color: Colors.green,
        onTap: () => pushWithAnimation(context, ChatbotPage(classId: classId)),
      ),
      _dashboardCard(
        title: 'Quiz Results',
        subtitle: 'View and manage student results',
        icon: Icons.assignment_turned_in,
        color: Colors.pink,
        onTap: () => pushWithAnimation(context, ResultPage(classId: classId)),
      ),
      _dashboardCard(
        title: 'View Materials',
        subtitle: 'Manage uploaded resources',
        icon: Icons.picture_as_pdf,
        color: Colors.blue,
        onTap: () => pushWithAnimation(
          context,
          ViewMaterialsTeacherPage(classId: classId),
        ),
      ),
      _dashboardCard(
        title: 'Question Banks',
        subtitle: 'Manage question banks',
        icon: Icons.folder_copy_rounded,
        color: Colors.purple,
        onTap: () =>
            pushWithAnimation(context, ViewQNBankTeacherPage(classId: classId)),
      ),
      _dashboardCard(
        title: 'Analytics Dashboard',
        subtitle: 'View teaching analytics',
        icon: Icons.bar_chart_rounded,
        color: Colors.red,
        onTap: () =>
            pushWithAnimation(context, TeacherAnalyticsPage(classId: classId)),
      ),
    ];
  }

  // ---------------- ANIMATION ----------------
  static const _curve = Cubic(0.22, 0.61, 0.36, 1.0);
  static final _slideTween = Tween<Offset>(
    begin: const Offset(1, 0),
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

  // ---------------- CARD FILTER ----------------
  List<Widget> _getVisibleCards(List<Widget> all) {
    switch (_selectedIndex) {
      case 1:
        return [all[3], all[4]];
      case 2:
        return [all[2]];
      case 3:
        return [all[1]];
      case 4:
        return [all[5]];
      default:
        return all;
    }
  }

  // ---------------- CARD UI (UNCHANGED) ----------------
  Widget _dashboardCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String subtitle,
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
              color: color.withAlpha((0.25 * 255).round()),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: color.withAlpha((0.2 * 255).round()),
            width: 1.2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withAlpha((0.15 * 255).round()),
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

  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    final className = widget.cls['name'] ?? 'Class';
    final name = loginUser?.name ?? 'Teacher';

    final allCards = _buildAllCards();
    final visibleCards = _getVisibleCards(allCards);

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
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
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
                onPressed: () async {
                  final res = await pushWithAnimation(
                    context,
                    ProfilePage(
                      
                      cls: widget.cls,
                    ),
                  );
                  if (res == true) {
                    setState(() {
                      loginUser = loginBox.get('profile');
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 0),
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

                return GridView.builder(
                  shrinkWrap: true, // ✅ allows it to fit within scroll view
                  physics:
                      const NeverScrollableScrollPhysics(), // ✅ disables inner scroll
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount.clamp(1, 4),
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    mainAxisExtent: cardHeight,
                  ),
                  itemCount: visibleCards.length,
                  itemBuilder: (context, index) {
                    return Center(
                      child: SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: visibleCards[index],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).scaffoldBackgroundColor.withAlpha((0.8 * 255).round()),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).shadowColor.withAlpha((0.05 * 255).round()),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
          child: NavigationBar(
            height: 70,
            backgroundColor: Theme.of(
              context,
            ).cardColor.withAlpha((0.7 * 255).round()),
            indicatorColor: Theme.of(
              context,
            ).primaryColor.withAlpha((0.6 * 255).round()),
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onNavTapped,
            labelTextStyle: WidgetStateProperty.all(
              TextStyle(color: Theme.of(context).primaryColor),
            ),
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                label: "Home",
                selectedIcon: Icon(
                  Icons.home,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              NavigationDestination(
                icon: Icon(Icons.picture_as_pdf_outlined),
                label: "Materials",
                selectedIcon: Icon(
                  Icons.picture_as_pdf,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              NavigationDestination(
                icon: Icon(Icons.quiz_outlined),
                label: "Quiz",
                selectedIcon: Icon(
                  Icons.quiz,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_outlined),
                label: "Chat",
                selectedIcon: Icon(
                  Icons.chat,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_rounded),
                label: "Analytics",
                selectedIcon: Icon(
                  Icons.bar_chart_rounded,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
