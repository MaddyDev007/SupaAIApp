import 'package:flutter/material.dart';
import 'package:smartclass/screens/view_materials_page.dart';
import 'quiz_list_page.dart';
import 'chatbot_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'viewqnpdf.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  Future<Map<String, dynamic>?> _fetchStudentDetails() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    final response = await Supabase.instance.client
        .from('profiles')
        .select('department, year')
        .eq('id', user.id)
        .maybeSingle();

    return response;
  }
  


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Supabase.instance.client.auth.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
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

          final department = student['department'] as String;
          final year = student['year'] as String;
          
          
          
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, Student!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),

                ElevatedButton.icon(
                  icon: const Icon(Icons.menu_book),
                  label: const Text('Start Quiz'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            QuizListPage(department: department, year: year , /* subject: subject, */), //1
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  icon: const Icon(Icons.chat),
                  label: const Text('Ask Chatbot'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChatbotPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('View Materials'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ViewMaterialsPage(
                          department: department,
                          year: year,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('View qn Materials'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ViewMaterialsQNPage(
                          department: department,
                          year: year,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
