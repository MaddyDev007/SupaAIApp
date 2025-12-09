// quiz_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuizPage extends StatefulWidget {
  final dynamic quizId; // pass from list page
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

class _QuizPageState extends State<QuizPage> {
  final supabase = Supabase.instance.client;

  // Data
  List<Map<String, dynamic>> questions = [];
  List<int> userAnswers = []; // -1 = unanswered
  String subject = "Quiz";

  // State
  int currentIndex = 0;
  int selected = -1;

  // Timer
  static const int _totalQuizSeconds = 150;
  int seconds = _totalQuizSeconds;
  Timer? _timer;

  bool loading = true;

  // ---------- Lifecycle ----------
  @override
  void initState() {

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.initState();
    _fetchQuiz();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _timer?.cancel();
    super.dispose();
  }

  // ---------- Data ----------
  Future<void> _fetchQuiz() async {
    try {
      final res = await supabase
          .from('quizzes')
          .select('id, subject, questions')
          .eq('id', widget.quizId)
          .maybeSingle()
          .timeout(const Duration(seconds: 12),
          onTimeout: () => throw TimeoutException('Quiz fetch timed out'));

      if (res == null) throw Exception('Quiz not found');

      subject = (res['subject'] as String?)?.trim().isNotEmpty == true
          ? res['subject']
          : 'Quiz';

      final raw = res['questions'];
      if (raw is String) {
        questions = List<Map<String, dynamic>>.from(jsonDecode(raw));
      } else if (raw is List) {
        questions = List<Map<String, dynamic>>.from(raw);
      } else {
        throw Exception('Invalid question format');
      }

      userAnswers = List<int>.filled(questions.length, -1);

      if (!mounted) return;
      setState(() {
        loading = false;
      });
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to load quiz'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  // ---------- Timer ----------
  void _startTimer() {
    _timer?.cancel();
    seconds = _totalQuizSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        seconds--;
        if (seconds <= 0) {
          _submitQuiz(); // finish quiz automatically
        }
      });
    });
  }

  // ---------- Navigation ----------
  void _onNext() {
    // Save the current selection
    userAnswers[currentIndex] = selected;

    if (currentIndex < questions.length - 1) {
      setState(() {
        currentIndex++;
        selected = userAnswers[currentIndex]; // restore if previously answered
      });
      // _startTimer();
    } else {
      _submitQuiz();
    }
  }

  void _onPrevious() {
    // Save current before moving
    userAnswers[currentIndex] = selected;

    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
        selected = userAnswers[currentIndex];
      });
      // _startTimer();
    }
  }

  // ---------- Submit ----------
  int _computeScore() {
    int s = 0;
    for (int i = 0; i < questions.length; i++) {
      final correctIndex = (questions[i]['answer'] as num).toInt();
      if (userAnswers[i] == correctIndex) s++;
    }
    return s;
  }

  Future<void> _submitQuiz() async {
    _timer?.cancel();

    // Ensure last selection saved
    userAnswers[currentIndex] = selected;

    final score = _computeScore();
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
          'quiz_id': widget.quizId,
          'student_id': user.id,
          'student_name': studentName,
          'score': score,
          'subject': subject,
          'department': widget.department,
          'year': widget.year,
          'answers': jsonEncode(userAnswers),
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving result: $e'),
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
        title: const Text('🎉 Quiz Completed'),
        content: Text('Your score: $score/${questions.length}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              Navigator.of(context).pop(); // go back
            },
            child: const Text('Close', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  // ---------- Helpers ----------
  String _formatMMSS(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final q = questions[currentIndex];
    final options = List<String>.from(q['options'] as List);
    final timeProgress =
        seconds.clamp(0, _totalQuizSeconds) / _totalQuizSeconds;

    return Scaffold(
      backgroundColor: Colors.blue.shade50,
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
      body: SafeArea(
        child: Column(
          children: [
            // Header with linear timer + chip
            Container(
              // color: const Color(0xFFF3F7FF),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 70),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: timeProgress.clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: Colors.blue.shade100,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          ),
                        ),
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _formatMMSS(seconds),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    q['question'].toString(),
                    style: const TextStyle(
                      fontSize: 22,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // Options list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                itemCount: options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final isSelected = selected == i;
                  return _OptionCard(
                    label: options[i],
                    selected: isSelected,
                    onTap: () {
                      setState(() => selected = i);
                    },
                  );
                },
              ),
            ),

            // Bottom bar
            Container(
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                // border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (currentIndex + 1) / questions.length,
                      minHeight: 6,
                      backgroundColor: Colors.blue.shade100,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Q ${currentIndex + 1} of ${questions.length}',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      // Previous
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: currentIndex == 0
                              ? Colors.grey.shade200
                              : Colors.white,
                          foregroundColor: currentIndex == 0
                              ? Colors.grey
                              : Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onPressed: currentIndex == 0 ? null : _onPrevious,
                        child: const Text('Previous'),
                      ),
                      const SizedBox(width: 10),
                      // Next / Submit
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                        onPressed: selected != -1 ? _onNext : null,
                        child: Text(
                          currentIndex == questions.length - 1
                              ? 'Submit'
                              : 'Next',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Widgets ----------
class _OptionCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.blue.shade100 : Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withAlpha((0.06 * 255).toInt()),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? Colors.blue : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Radio<bool>(
                value: true,
                groupValue: selected,
                onChanged: (_) => onTap(),
                activeColor: Colors.blue,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
