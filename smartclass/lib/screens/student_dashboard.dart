import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'quiz_list_page.dart';
import 'chatbot_page.dart';
import 'view_materials_page.dart';
import 'viewqnpdf.dart';
import 'notes_page.dart';
import 'analytics_dashboard.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _selectedIndex = 0;

  Future<Map<String, dynamic>?> _fetchStudentDetails() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    final response = await Supabase.instance.client
        .from('profiles')
        .select('name, department, year')
        .eq('id', user.id)
        .maybeSingle();

    return response;
  }

  void _onNavTapped(int index) {
    if (index == 4) {
      Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => NotesPage()),
              );
      return;
    }
    setState(() => _selectedIndex = index);
  }

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
          color: Colors.white.withAlpha((0.85 * 255).round()),
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
        child: Container(
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
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Student Dashboard',
              style: TextStyle(
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
                onPressed: () => Navigator.pushNamed(context, '/profile'),
              ),
            ],
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _fetchStudentDetails(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final student = snapshot.data;
          if (student == null) {
            return const Center(child: Text('Student details not found.'));
          }

          final name = student['name'] as String? ?? 'Student';
          final department = student['department'] as String;
          final year = student['year'] as String;

          final allCards = [
            _dashboardCard(
              title: 'Start Quiz',
              subtitle: 'Test your knowledge',
              icon: Icons.menu_book_rounded,
              color: Colors.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      QuizListPage(department: department, year: year),
                ),
              ),
            ),
            _dashboardCard(
              title: 'Ask Chatbot',
              subtitle: 'Instant smart help',
              icon: Icons.smart_toy_outlined,
              color: Colors.green,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatbotPage()),
              ),
            ),
            _dashboardCard(
              title: 'View Materials',
              subtitle: 'Access study resources',
              icon: Icons.picture_as_pdf,
              color: Colors.blue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ViewMaterialsPage(department: department, year: year),
                ),
              ),
            ),
            _dashboardCard(
              title: 'Question Banks',
              subtitle: 'Practice with QNs',
              icon: Icons.folder_copy_rounded,
              color: Colors.purple,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ViewMaterialsQNPage(department: department, year: year),
                ),
              ),
            ),
            _dashboardCard(
              title: 'Notes',
              subtitle: 'Personal study notes',
              icon: Icons.edit_note_rounded,
              color: const Color(0xFF3559C7),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => NotesPage()),
              ),
            ),
            _dashboardCard(
              title: 'Analytics',
              subtitle: 'Track your progress',
              icon: Icons.bar_chart_rounded,
              color: Colors.red,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnalyticsDashboard()),
              ),
            ),
          ];

          List<Widget> visibleCards;
          if (_selectedIndex == 1) {
            visibleCards = [allCards[2], allCards[3]];
          } else if (_selectedIndex == 2) {
            visibleCards = [allCards[0]];
          } else if (_selectedIndex == 3) {
            visibleCards = [allCards[1]];
          } else {
            visibleCards = allCards;
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(
              top: 16,
              left: 16,
              right: 16,
              bottom: 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Welcome $name 👋",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final double cardWidth = 220;
                    final double cardHeight = 200;
                    final int crossAxisCount =
                        (constraints.maxWidth / (cardWidth + 20)).floor();

                    return GridView.builder(
                      shrinkWrap: true, // ✅ makes grid take needed space
                      physics:
                          const NeverScrollableScrollPhysics(), // ✅ prevents double scroll
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
          );
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white.withAlpha((0.8 * 255).round()),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.05 * 255).round()),
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
            backgroundColor: Colors.white.withAlpha((0.7 * 255).round()),
            indicatorColor: Colors.blue.shade100.withAlpha((0.6 * 255).round()),
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onNavTapped,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(color: Colors.blue),
            ),
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                label: "Home",
                selectedIcon: Icon(Icons.home, color: Colors.blue),
              ),
              NavigationDestination(
                icon: Icon(Icons.picture_as_pdf_outlined),
                label: "Materials",
                selectedIcon: Icon(Icons.picture_as_pdf, color: Colors.blue),
              ),
              NavigationDestination(
                icon: Icon(Icons.quiz_outlined),
                label: "Quiz",
                selectedIcon: Icon(Icons.quiz, color: Colors.blue),
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_outlined),
                label: "Chat",
                selectedIcon: Icon(Icons.chat, color: Colors.blue),
              ),
              NavigationDestination(
                icon: Icon(Icons.edit_note_outlined),
                label: "Notes",
                selectedIcon: Icon(Icons.edit_note, color: Colors.blue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
