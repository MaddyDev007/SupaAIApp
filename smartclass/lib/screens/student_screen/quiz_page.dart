import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuizPage extends StatefulWidget {
  final dynamic quizId;
  final String classId; // ✅ NEW

  const QuizPage({
    super.key,
    required this.quizId,
    required this.classId,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final supabase = Supabase.instance.client;

  // Data
  List<Map<String, dynamic>> questions = [];
  List<int> userAnswers = [];
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
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _fetchQuiz();
  }

  @override
  void dispose() {
    _timer?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // ---------- Fetch Quiz ----------
  Future<void> _fetchQuiz() async {
    try {
      final res = await supabase
          .from('quizzes')
          .select('id, subject, questions')
          .eq('id', widget.quizId)
          .maybeSingle()
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () => throw TimeoutException('Quiz fetch timed out'),
          );

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
      setState(() => loading = false);
      _startTimer();
    } catch (_) {
      if (!mounted) return;
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
        if (seconds <= 0) _submitQuiz();
      });
    });
  }

  // ---------- Navigation ----------
  void _onNext() {
    userAnswers[currentIndex] = selected;

    if (currentIndex < questions.length - 1) {
      setState(() {
        currentIndex++;
        selected = userAnswers[currentIndex];
      });
    } else {
      _submitQuiz();
    }
  }

  void _onPrevious() {
    userAnswers[currentIndex] = selected;

    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
        selected = userAnswers[currentIndex];
      });
    }
  }

  // ---------- Submit ----------
  int _computeScore() {
    int s = 0;
    for (int i = 0; i < questions.length; i++) {
      if (userAnswers[i] ==
          (questions[i]['answer'] as num).toInt()) {
        s++;
      }
    }
    return s;
  }

  Future<void> _submitQuiz() async {
    _timer?.cancel();
    userAnswers[currentIndex] = selected;

    final score = _computeScore();
    final user = supabase.auth.currentUser;

    if (user != null) {
      try {
        await supabase.from('results').insert({
          'quiz_id': widget.quizId,
          'class_id': widget.classId, // ✅ NEW
          'student_id': user.id,
          'student_name': user.email ?? 'Unknown',
          'subject': subject,
          'score': score,
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.white),
            ),
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
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).primaryColor,
          ),
        ),
      );
    }

    final q = questions[currentIndex];
    final options = List<String>.from(q['options']);
    final timeProgress =
        seconds.clamp(0, _totalQuizSeconds) / _totalQuizSeconds;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "$subject Quiz",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ---------- HEADER ----------
            Padding(
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
                            value: timeProgress.clamp(0, 1),
                            minHeight: 6,
                            backgroundColor:
                                Colors.blue.shade100.withAlpha(220),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _formatMMSS(seconds),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    q['question'].toString(),
                    style: TextStyle(
                      fontSize: 22,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color,
                    ),
                  ),
                ],
              ),
            ),

            // ---------- OPTIONS ----------
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: options.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  return _OptionCard(
                    label: options[i],
                    selected: selected == i,
                    onTap: () => setState(() => selected = i),
                  );
                },
              ),
            ),

            // ---------- FOOTER ----------
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value:
                            (currentIndex + 1) / questions.length,
                        minHeight: 6,
                        backgroundColor:
                            Colors.blue.shade100.withAlpha(220),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Q ${currentIndex + 1} of ${questions.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color,
                          ),
                        ),
                        const Spacer(),
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
                            side: BorderSide(color: Colors.grey),
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
                        ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: Theme.of(context).primaryColor,
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
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- OPTION CARD ----------
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
      color: selected ? Theme.of(context).splashColor.withAlpha((0.25 * 255).toInt()) : Theme.of(context).cardColor,
      elevation: 2,
      shadowColor: Colors.black.withAlpha((0.06 * 255).toInt()),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? Theme.of(context).primaryColor : Colors.transparent,
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
                activeColor: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
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

