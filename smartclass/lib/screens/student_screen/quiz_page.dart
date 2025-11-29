import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuizPage extends StatefulWidget {
  final dynamic quizId; // ✅ pass this from the list page
  final String department;
  final String year;

  const QuizPage({
    super.key,
    required this.quizId,
    required this.department,
    required this.year,
  });
  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> questions = [];
  List<int> userAnswers = []; // ✅ store user selections
  int currentIndex = 0;
  int score = 0;
  int selected = -1;
  static const int _perQuestionSeconds = 10;
  int seconds = _perQuestionSeconds;
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
          .eq('id', widget.quizId) // ✅ fetch by quizId
          .maybeSingle();

      if (response == null) {
        throw Exception("Quiz not found.");
      }

      subject = (response['subject'] as String?) ?? 'Quiz';
      final raw = response['questions'];

      if (raw is String) {
        questions = List<Map<String, dynamic>>.from(jsonDecode(raw));
      } else if (raw is List) {
        questions = List<Map<String, dynamic>>.from(raw);
      } else {
        throw Exception("Invalid question format");
      }

      userAnswers = List<int>.filled(questions.length, -1);

      if (!mounted) return;
      setState(() {
        loading = false;
      });
      startTimer(); // start after setState
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Failed to load quiz"),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  void startTimer() {
    timer?.cancel();
    seconds = _perQuestionSeconds;
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return; // dispose will cancel anyway
      setState(() {
        seconds--;
        if (seconds <= 0) {
          nextQuestion(autoAdvance: true);
        }
      });
    });
  }

  void nextQuestion({bool autoAdvance = false}) {
    timer?.cancel();

    // If auto-advance due to timeout and user hasn't selected, keep -1
    // Score updates only when the selection matches the correct answer
    final correctIndex = (questions[currentIndex]['answer'] as num).toInt();
    if (selected != -1) {
      userAnswers[currentIndex] = selected;
      if (selected == correctIndex) score++;
    }

    if (currentIndex < questions.length - 1) {
      setState(() {
        currentIndex++;
        selected = -1;
      });
      startTimer();
    } else {
      saveResultAndShowDialog();
    }
  }

  Future<void> saveResultAndShowDialog() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        final profileRes = await supabase
            .from('profiles')
            .select('email')
            .eq('id', user.id)
            .maybeSingle();

        final studentName =
            (profileRes != null ? profileRes['email'] : null) ??
            user.email ??
            'Unknown';

        await supabase.from('results').insert({
          'quiz_id': widget.quizId, // ✅ no re-query
          'student_id': user.id,
          'student_name': studentName,
          'score': score,
          'subject': subject,
          'department': widget.department,
          'year': widget.year,
          // ✅ save the user's choices, not the correct answers
          'answers': jsonEncode(userAnswers),
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error saving result: $e"),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
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
    final options = List<String>.from(q['options']);
    final progress =
        seconds.clamp(0, _perQuestionSeconds) / _perQuestionSeconds;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "$subject Quiz",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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
                        valueColor: const AlwaysStoppedAnimation(Colors.blue),
                        backgroundColor: Colors.blue.shade100,
                      ),
                      Center(
                        child: Text(
                          "$seconds",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
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
                        color: Colors.black.withOpacity(0.1), // ✅
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
                        q['question'].toString(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(188, 0, 0, 0),
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
                    itemCount: options.length,
                    itemBuilder: (context, i) {
                      final isSelected = selected == i;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                                  colors: [Colors.blue, Colors.blue],
                                )
                              : const LinearGradient(
                                  colors: [Colors.white, Colors.white],
                                ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? Colors.blueAccent
                                : Colors.black26,
                            width: 2,
                          ),
                        ),
                        child: ListTile(
                          title: Text(
                            options[i],
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
                      style: const TextStyle(color: Colors.blue, fontSize: 16),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onPressed: selected != -1 ? () => nextQuestion() : null,
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
