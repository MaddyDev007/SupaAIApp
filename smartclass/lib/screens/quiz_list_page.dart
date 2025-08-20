import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'quiz_page.dart';

class QuizListPage extends StatefulWidget {
  final String department;
  final String year;

  const QuizListPage({
    super.key,
    required this.department,
    required this.year,
  });

  @override
  State<QuizListPage> createState() => _QuizListPageState();
}

class _QuizListPageState extends State<QuizListPage> {
  final supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _quizzesFuture;

  @override
  void initState() {
    super.initState();
    _quizzesFuture = _fetchQuizzes();
  }

  Future<List<Map<String, dynamic>>> _fetchQuizzes() async {
    final response = await supabase
        .from('quizzes')
        .select('id, subject, created_at')
        .eq('department', widget.department)
        .eq('year', widget.year)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Available Quizzes")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _quizzesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final quizzes = snapshot.data!;
          if (quizzes.isEmpty) {
            return const Center(child: Text("No quizzes available."));
          }

          return ListView.builder(
            itemCount: quizzes.length,
            itemBuilder: (context, index) {
              final quiz = quizzes[index];
              final subject = quiz['subject'] ?? 'Unknown Subject';
              final createdAt = DateTime.tryParse(quiz['created_at'] ?? '');

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(subject,
                      style:
                          const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      "Created: ${createdAt != null ? createdAt.toLocal().toString().split('.')[0] : 'Unknown'}"),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QuizPage(
                          department: widget.department,
                          year: widget.year,
                          //subject: subject,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
