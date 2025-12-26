import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smartclass/screens/common_screen/error_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'quiz_page.dart';

class QuizListPage extends StatefulWidget {
  final String classId; // ✅ NEW

  const QuizListPage({
    super.key,
    required this.classId,
  });

  @override
  State<QuizListPage> createState() => _QuizListPageState();
}

class _QuizListPageState extends State<QuizListPage>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  late Future<List<Map<String, dynamic>>> _quizzesFuture;

  late final AnimationController _listController;
  late final Animation<double> _listAnimation;

  String _filterOption = 'All';
  final List<String> _filterOptions = ['All', 'Finished', 'Unfinished'];

  @override
  void initState() {
    super.initState();

    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _listAnimation = CurvedAnimation(
      parent: _listController,
      curve: Curves.easeOut,
    );

    _quizzesFuture = _fetchQuizzes().then((list) {
      if (mounted) _listController.forward(from: 0);
      return list;
    });
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  // ---------------- NAV ANIMATION ----------------
  static const _curve = Cubic(0.22, 0.61, 0.36, 1.0);
  static final _slideTween = Tween<Offset>(
    begin: const Offset(1, 0),
    end: Offset.zero,
  );

  Future<void> pushWithAnimation(BuildContext context, Widget page) {
    return Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(parent: animation, curve: _curve);
          return SlideTransition(
            position: _slideTween.animate(curved),
            child: child,
          );
        },
      ),
    );
  }

  // ---------------- FETCH QUIZZES (CLASS-BASED) ----------------
  Future<List<Map<String, dynamic>>> _fetchQuizzes() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return [];

      // ✅ quizzes for this class only
      final quizzes = await supabase
          .from('quizzes')
          .select('id, subject, created_at')
          .eq('class_id', widget.classId)
          .order('created_at', ascending: false)
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () => throw TimeoutException('Quiz fetch timed out'),
          );

      // attempts by this student
      final attempts = await supabase
          .from('results')
          .select('quiz_id, score, created_at')
          .eq('student_id', user.id)
          .order('created_at', ascending: false)
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () => throw TimeoutException('Result fetch timed out'),
          );

      // latest attempt per quiz
      final Map<dynamic, Map<String, dynamic>> latestAttemptByQuiz = {};
      for (final a in attempts) {
        latestAttemptByQuiz.putIfAbsent(a['quiz_id'], () => a);
      }

      final quizList = List<Map<String, dynamic>>.from(quizzes);
      for (final quiz in quizList) {
        final attempt = latestAttemptByQuiz[quiz['id']];
        quiz['attempted'] = attempt != null;
        quiz['score'] = attempt?['score'];
      }

      return quizList;
    } catch (e) {
      rethrow;
    }
  }

  // ---------------- FILTER ----------------
  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> quizzes) {
    bool attemptedOf(Map q) => (q['attempted'] as bool?) ?? false;

    if (_filterOption == 'Finished') {
      return quizzes.where((q) => attemptedOf(q)).toList();
    } else if (_filterOption == 'Unfinished') {
      return quizzes.where((q) => !attemptedOf(q)).toList();
    }
    return quizzes;
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return 'Unknown';
    final dt = raw is DateTime ? raw : DateTime.tryParse(raw.toString());
    if (dt == null) return 'Unknown';
    final local = dt.toLocal();
    return
        "${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} "
        "${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}";
  }

  // ---------------- CARD ----------------
  Widget _buildQuizCard(Map<String, dynamic> quiz) {
    final subject = quiz['subject'] ?? 'Unknown Subject';
    final attempted = quiz['attempted'] ?? false;
    final score = quiz['score'];

    final slideTween = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOut));

    return FadeTransition(
      opacity: _listAnimation,
      child: SlideTransition(
        position: _listAnimation.drive(slideTween),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: attempted ? Colors.green : Colors.transparent,
              width: 1.5,
            ),
          ),
          color: attempted
              ? Theme.of(context).disabledColor
              : Theme.of(context).cardColor,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            title: Text(
              subject,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: attempted
                    ? Theme.of(context).textTheme.bodySmall?.color
                    : Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            subtitle: Text(
              "Created: ${_formatDate(quiz['created_at'])}"
              "${attempted && score != null ? "\nScore: $score" : ""}",
              style: const TextStyle(color: Colors.grey),
            ),
            trailing: attempted
                ? const Icon(Icons.check_circle, color: Colors.green)
                : Icon(Icons.arrow_forward_ios,
                    color: Theme.of(context).primaryColor),
            onTap: attempted
                ? null
                : () {
                    pushWithAnimation(
                      context,
                      QuizPage(
                        quizId: quiz['id'],   // ✅ only quizId needed
                        classId: widget.classId,
                      ),
                    ).then((_) {
                      setState(() {
                        _quizzesFuture = _fetchQuizzes().then((list) {
                          if (mounted) _listController.forward(from: 0);
                          return list;
                        });
                      });
                    });
                  },
          ),
        ),
      ),
    );
  }

  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Available Quizzes",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Filter
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text("Filter: ",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _filterOption,
                  items: _filterOptions
                      .map((opt) =>
                          DropdownMenuItem(value: opt, child: Text(opt)))
                      .toList(),
                  onChanged: (val) =>
                      setState(() => _filterOption = val!),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _quizzesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                        color: Theme.of(context).primaryColor),
                  );
                }

                if (snapshot.hasError) {
                  return SmartClassErrorPage(
                    type: SmartClassErrorPage.mapToType(snapshot.error),
                    error: snapshot.error,
                    stackTrace: snapshot.stackTrace,
                    onRetry: () {
                      setState(() {
                        _quizzesFuture = _fetchQuizzes().then((list) {
                          if (mounted) _listController.forward(from: 0);
                          return list;
                        });
                      });
                    },
                  );
                }

                final quizzes = _applyFilter(snapshot.data ?? []);

                if (quizzes.isEmpty) {
                  return const Center(
                    child: Text("No quizzes available."),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    final refreshed = await _fetchQuizzes();
                    if (!mounted) return;
                    setState(() {
                      _quizzesFuture = Future.value(refreshed);
                      _listController.forward(from: 0);
                    });
                  },
                  color: Theme.of(context).primaryColor,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: quizzes.length,
                    itemBuilder: (_, i) => _buildQuizCard(quizzes[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
