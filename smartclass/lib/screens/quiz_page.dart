import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuizPage extends StatefulWidget {
  final String department;
  final String year;

  const QuizPage({
    super.key,
    required this.department,
    required this.year,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> questions = [];
  int currentIndex = 0;
  int score = 0;
  int selected = -1;
  int seconds = 10;
  Timer? timer;
  bool loading = true;
  String subject = "";

  @override
  void initState() {
    super.initState();
    fetchQuiz();
  }

  Future<void> fetchQuiz() async {
    try {
      final response = await supabase
          .from('quizzes')
          .select('id, subject, questions')
          .eq('department', widget.department)
          .eq('year', widget.year)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        throw Exception("No quiz found for ${widget.department}, ${widget.year}");
      }

      subject = response['subject'];
      final raw = response['questions'];

      if (raw is String) {
        questions = List<Map<String, dynamic>>.from(jsonDecode(raw));
      } else if (raw is List) {
        questions = List<Map<String, dynamic>>.from(raw);
      } else {
        throw Exception("Invalid question format");
      }

      setState(() {
        loading = false;
        startTimer();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load quiz: $e")),
      );
      Navigator.pop(context);
    }
  }

  void startTimer() {
    timer?.cancel();
    seconds = 10;
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        seconds--;
        if (seconds == 0) {
          nextQuestion();
        }
      });
    });
  }

  void nextQuestion() {
    timer?.cancel();

    if (selected == questions[currentIndex]['answer']) {
      score++;
    }

    if (currentIndex < questions.length - 1) {
      setState(() {
        currentIndex++;
        selected = -1;
        startTimer();
      });
    } else {
      saveResultAndShowDialog();
    }
  }

  Future<void> saveResultAndShowDialog() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final quizRes = await supabase
          .from('quizzes')
          .select('id, subject')
          .eq('department', widget.department)
          .eq('year', widget.year)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (quizRes == null) return;
      final quizId = quizRes['id'];

      final profileRes = await supabase
          .from('profiles')
          .select('email')
          .eq('id', user.id)
          .single();

      final studentName = profileRes['email'];
      await supabase.from('results').insert({
        'quiz_id': quizId,
        'student_id': user.id,
        'student_name': studentName,
        'score': score,
        'subject': subject,
        'department': widget.department,
        'year': widget.year,
        'answers': jsonEncode(questions.map((q) => q['answer']).toList()),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving result: $e")),
      );
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Quiz Completed"),
        content: Text("Your score: $score/${questions.length}"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text("Close"),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final q = questions[currentIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text("$subject Quiz (${currentIndex + 1}/${questions.length})"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              q['question'],
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...List.generate(q['options'].length, (i) {
              return ListTile(
                title: Text(q['options'][i]),
                tileColor: selected == i ? Colors.blue[100] : null,
                onTap: () {
                  if (!mounted) return;
                  setState(() => selected = i);
                },
              );
            }),
            const Spacer(),
            Text("Time left: $seconds sec", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: selected != -1 ? nextQuestion : null,
              child: Text(currentIndex == questions.length - 1 ? "Finish" : "Next"),
            )
          ],
        ),
      ),
    );
  }
}
