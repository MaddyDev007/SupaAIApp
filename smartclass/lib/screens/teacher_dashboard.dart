import 'package:flutter/material.dart';
import 'upload_material_page.dart';
import 'result_page.dart';
import 'teacher_analytics_dashboard.dart';
import 'chatbot_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'view_material_teacher.dart';
import 'view_qnbank_teacher.dart';
class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  Future<Map<String, dynamic>?> _fetchTeacherDetails() async {
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
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      splashColor: color.withAlpha(100),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getCrossAxisCount(double width) {
    if (width > 820) return 4;
    if (width > 650) return 3;
    if (width < 400) return 1;
    return 2; // larger tablets / desktops
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text(
          'Teacher Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.account_circle,
              color: Colors.white,
              size: 28,
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _fetchTeacherDetails(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final teacher = snapshot.data;
            if (teacher == null) {
              return const Center(child: Text('Student details not found.'));
            }

            final name = teacher['name'] as String? ?? 'Teacher';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome, $name!",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    crossAxisCount: _getCrossAxisCount(screenWidth),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    children: [
                      _dashboardCard(
                        title: 'Upload Material',
                        icon: Icons.upload_file,
                        color: Colors.orange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UploadMaterialPage(),
                            ),
                          );
                        },
                      ),
                      _dashboardCard(
                        title: 'Chatbot',
                        icon: Icons.chat,
                        color: Colors.green,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ChatbotPage(),
                            ),
                          );
                        },
                      ),
                      _dashboardCard(
                        title: 'Quiz Results',
                        icon: Icons.assignment,
                        color: Colors.pink,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ResultPage(),
                            ),
                          );
                        },
                      ),
                      _dashboardCard(
                        title: 'View Materials',
                        icon: Icons.picture_as_pdf,
                        color: Colors.blue,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ViewMaterialsTeacherPage(),
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
                            builder: (context) => ViewQNBankTeacherPage(),
                          ),
                        ),
                      ),
                      _dashboardCard(
                        title: 'Analytics',
                        icon: Icons.bar_chart,
                        color: Colors.red,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const TeacherAnalyticsPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
