import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuizPage extends StatefulWidget {
  final String department;
  final String year;

  const QuizPage({super.key, required this.department, required this.year});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage>
    with SingleTickerProviderStateMixin {
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
        throw Exception(
          "No quiz found for ${widget.department}, ${widget.year}",
        );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to load quiz: $e")));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error saving result: $e")));
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("🎉 Quiz Completed"),
        content: Text("Your score: $score/${questions.length}"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text("Close"),
          ),
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final q = questions[currentIndex];
    final progress = (seconds / 10);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "$subject Quiz",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Colors.white, // <-- change back arrow color here
        ),
      ),
      body: Container(
        color: Colors.blue.shade50,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Circular Timer
                SizedBox(
                  height: 80,
                  width: 80,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        valueColor: const AlwaysStoppedAnimation(Colors.grey),
                        backgroundColor: const Color.fromARGB(117, 253, 253, 253),
                      ),
                      Center(
                        child: Text(
                          "$seconds",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Question Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Q${currentIndex + 1}/${questions.length}",
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        q['question'],
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Options
                Expanded(
                  child: ListView.builder(
                    itemCount: q['options'].length,
                    itemBuilder: (context, i) {
                      final isSelected = selected == i;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                                  colors: [
                                    Color.fromARGB(255, 48, 169, 88),
                                    Color.fromARGB(255, 41, 185, 159),
                                  ],
                                )
                              : const LinearGradient(
                                  colors: [Colors.white24, Colors.white10],
                                ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? Colors.greenAccent
                                : Colors.black26,
                            width: 2,
                          ),
                        ),
                        child: ListTile(
                          title: Text(
                            q['options'][i],
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          onTap: () {
                            if (!mounted) return;
                            setState(() => selected = i);
                          },
                        ),
                      );
                    },
                  ),
                ),

                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Score: $score",
                      style: const TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onPressed: selected != -1 ? nextQuestion : null,
                      child: Text(
                        currentIndex == questions.length - 1
                            ? "Finish"
                            : "Next →",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
    );
  }
}
