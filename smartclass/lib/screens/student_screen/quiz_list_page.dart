import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smartclass/screens/common_screen/error_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'quiz_page.dart';

class QuizListPage extends StatefulWidget {
  final String department;
  final String year;

  const QuizListPage({super.key, required this.department, required this.year});

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

    // 1) Create animation controller first
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _listAnimation = CurvedAnimation(
      parent: _listController,
      curve: Curves.easeOut,
    );

    // 2) Then kick off the fetch and start the animation afterwards
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

  Future<List<Map<String, dynamic>>> _fetchQuizzes() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return [];

      // quizzes for dept + year
      final quizzes = await supabase
          .from('quizzes')
          .select('id, subject, created_at, department, year')
          .eq('department', widget.department)
          .eq('year', widget.year)
          .order('created_at', ascending: false)
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () => throw TimeoutException('Quiz fetch timed out'),
          );

      // attempts for this user (keep latest by created_at if multiple)
      final attempts = await supabase
          .from('results')
          .select('quiz_id, score, created_at')
          .eq('student_id', user.id)
          .order('created_at', ascending: false)
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () => throw TimeoutException('Quiz fetch timed out'),
          );

      // Build latest-attempt map
      final Map<dynamic, Map<String, dynamic>> latestAttemptByQuiz = {};
      for (final a in attempts) {
        final qid = a['quiz_id'];
        latestAttemptByQuiz.putIfAbsent(qid, () => a);
      }

      final quizList = List<Map<String, dynamic>>.from(quizzes);
      for (final quiz in quizList) {
        final quizId = quiz['id'];
        final attempt = latestAttemptByQuiz[quizId];
        quiz['attempted'] = attempt != null;
        quiz['score'] = attempt?['score'];
      }

      return quizList;
    } catch (e) {
      rethrow;
    }
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> quizzes) {
    bool attemptedOf(Map q) => (q['attempted'] as bool?) ?? false;

    if (_filterOption == 'Finished') {
      return quizzes.where((q) => attemptedOf(q)).toList();
    } else if (_filterOption == 'Unfinished') {
      return quizzes.where((q) => !attemptedOf(q)).toList();
    }
    return quizzes; // All
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return 'Unknown';
    final dt = raw is DateTime ? raw : DateTime.tryParse(raw.toString());
    if (dt == null) return 'Unknown';
    final local = dt.toLocal();
    // yyyy-mm-dd hh:mm (no milliseconds)
    final date =
        "${local.year.toString().padLeft(4, '0')}-"
        "${local.month.toString().padLeft(2, '0')}-"
        "${local.day.toString().padLeft(2, '0')}";
    final time =
        "${local.hour.toString().padLeft(2, '0')}:"
        "${local.minute.toString().padLeft(2, '0')}";
    return "$date $time";
  }

  Widget _buildQuizCard(Map<String, dynamic> quiz, int index) {
    final subject = (quiz['subject'] as String?) ?? 'Unknown Subject';
    final createdAt = quiz['created_at'];
    final attempted = (quiz['attempted'] as bool?) ?? false;
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
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
              "Created: ${_formatDate(createdAt)}"
              "${attempted && score != null ? "\nScore: $score" : ""}",
              style: const TextStyle(color: Colors.grey),
            ),
            trailing: attempted
                ? const Icon(Icons.check_circle, color: Colors.green)
                :  Icon(Icons.arrow_forward_ios, color: Theme.of(context).primaryColor,),
            onTap: attempted
                ? null
                : () {
                    pushWithAnimation(
                      context,
                      QuizPage(
                        // ✅ Pass the quiz id
                        quizId: quiz['id'],
                        department: widget.department,
                        year: widget.year,
                      ),
                    ).then((_) {
                      // re-fetch and replay the list animation
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
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter dropdown
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Text(
                  "Filter: ",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  borderRadius: BorderRadius.circular(12),
                  dropdownColor: Theme.of(context).cardColor,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontWeight: FontWeight.w500,
                  ),
                  
                  elevation: 1,
                  focusColor: Colors.blue.shade50,
                  value: _filterOption,
                  items: _filterOptions
                      .map(
                        (opt) => DropdownMenuItem(value: opt, child: Text(opt)),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _filterOption = val);
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _quizzesFuture,
              builder: (context, snapshot) {
                // Loading
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                    ),
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

                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                // Apply filter
                final quizzes = _applyFilter(snapshot.data!);

                if (quizzes.isEmpty) {
                  return Center(
                    child: Text(
                      "No quizzes available for this filter.",
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
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
                    itemBuilder: (context, index) =>
                        _buildQuizCard(quizzes[index], index),
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
