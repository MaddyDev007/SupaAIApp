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
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    // Fetch all quizzes for department + year
    final quizzes = await supabase
        .from('quizzes')
        .select('id, subject, created_at')
        .eq('department', widget.department)
        .eq('year', widget.year)
        .order('created_at', ascending: false);

    // Fetch attempts + score for this student
    final attempts = await supabase
        .from('results')
        .select('quiz_id, score')
        .eq('student_id', user.id);

    final attemptsMap = {
      for (var a in attempts) a['quiz_id']: a['score']
    };

    // Add attempt + score info to each quiz
    final quizList = List<Map<String, dynamic>>.from(quizzes);
    for (var quiz in quizList) {
      final quizId = quiz['id'];
      quiz['attempted'] = attemptsMap.containsKey(quizId);
      quiz['score'] = attemptsMap[quizId]; // null if not attempted
    }

    return quizList;
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
              final attempted = quiz['attempted'] ?? false;
              final score = quiz['score'];

              return Card(
                color: attempted ? Colors.grey[200] : null, // greyed if attempted
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(
                    subject,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: attempted ? Colors.grey[700] : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    "Created: ${createdAt != null ? createdAt.toLocal().toString().split('.')[0] : 'Unknown'}"
                    "${attempted && score != null ? "\nScore: $score" : ""}",
                  ),
                  trailing: attempted
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.arrow_forward_ios),
                  onTap: attempted
                      ? null // disable if already attempted
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QuizPage(
                                department: widget.department,
                                year: widget.year,
                              ),
                            ),
                          ).then((_) {
                            // refresh quiz list after returning
                            setState(() {
                              _quizzesFuture = _fetchQuizzes();
                            });
                          });
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
