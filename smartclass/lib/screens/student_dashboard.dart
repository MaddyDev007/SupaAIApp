import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:smartclass/screens/view_materials_page.dart';
import 'quiz_list_page.dart';
import 'chatbot_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'viewqnpdf.dart';
import 'analytics_dashboard.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

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

  Widget _dashboardCard({
  required String title,
  required IconData icon,
  required VoidCallback onTap,
  Color color = Colors.blue,
}) {
  return SizedBox(
    width: 150,
    height: 150,
    child: Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Material(
        color: Colors.transparent, // make material transparent
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: color.withAlpha(100),
          onTap: onTap,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: color),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  int _getCrossAxisCount(double width) {
    if (width > 1000) return 5;
    if (width > 820) return 4;
    if (width > 650) return 3;
    if (width < 400) return 1;
    return 2; // default
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = _getCrossAxisCount(screenWidth);

    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text(
          'Student Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white, size: 28),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _fetchStudentDetails(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final student = snapshot.data;
          if (student == null) return const Center(child: Text('Student details not found.'));

          final name = student['name'] as String? ?? 'Student';
          final department = student['department'] as String;
          final year = student['year'] as String;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(13),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Welcome, $name!',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 30),
                        GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1, // square cards
                          children: [
                            _dashboardCard(
                              title: 'Start Quiz',
                              icon: Icons.menu_book,
                              color: Colors.orange,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => QuizListPage(
                                    department: department,
                                    year: year,
                                  ),
                                ),
                              ),
                            ),
                            _dashboardCard(
                              title: 'Ask Chatbot',
                              icon: Icons.chat,
                              color: Colors.green,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ChatbotPage(),
                                ),
                              ),
                            ),
                            _dashboardCard(
                              title: 'View Materials',
                              icon: Icons.picture_as_pdf,
                              color: Colors.blue,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ViewMaterialsPage(
                                    department: department,
                                    year: year,
                                  ),
                                ),
                              ),
                            ),
                            _dashboardCard(
                              title: 'View Question Banks',
                              icon: Icons.folder,
                              color: Colors.purple,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ViewMaterialsQNPage(
                                    department: department,
                                    year: year,
                                  ),
                                ),
                              ),
                            ),
                            _dashboardCard(
                              title: 'Analytics',
                              icon: Icons.bar_chart,
                              color: Colors.red,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AnalyticsDashboard(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
