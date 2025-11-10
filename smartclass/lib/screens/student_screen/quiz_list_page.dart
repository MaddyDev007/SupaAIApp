import 'package:flutter/material.dart';
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

  String _filterOption = 'All'; // New filter option
  final List<String> _filterOptions = ['All', 'Finished', 'Unfinished'];

  @override
  void initState() {
    super.initState();
    _quizzesFuture = _fetchQuizzes();

    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _listAnimation = CurvedAnimation(
      parent: _listController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchQuizzes() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final quizzes = await supabase
        .from('quizzes')
        .select('id, subject, created_at')
        .eq('department', widget.department)
        .eq('year', widget.year)
        .order('created_at', ascending: false);

    final attempts = await supabase
        .from('results')
        .select('quiz_id, score')
        .eq('student_id', user.id);

    final attemptsMap = {for (var a in attempts) a['quiz_id']: a['score']};

    final quizList = List<Map<String, dynamic>>.from(quizzes);
    for (var quiz in quizList) {
      final quizId = quiz['id'];
      quiz['attempted'] = attemptsMap.containsKey(quizId);
      quiz['score'] = attemptsMap[quizId];
    }

    _listController.forward(from: 0);
    return quizList;
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> quizzes) {
    if (_filterOption == 'Finished') {
      return quizzes.where((q) => q['attempted'] == true).toList();
    } else if (_filterOption == 'Unfinished') {
      return quizzes.where((q) => q['attempted'] == false).toList();
    }
    return quizzes; // All
  }

  Widget _buildQuizCard(Map<String, dynamic> quiz, int index) {
    final subject = quiz['subject'] ?? 'Unknown Subject';
    final createdAt = DateTime.tryParse(quiz['created_at'] ?? '');
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
          ),
          elevation: 3,
          color: attempted ? Colors.grey[100] : Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            title: Text(
              subject,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: attempted ? Colors.grey.shade700 : Colors.black,
              ),
            ),
            subtitle: Text(
              "Created: ${createdAt != null ? createdAt.toLocal().toString().split('.')[0] : 'Unknown'}"
              "${attempted && score != null ? "\nScore: $score" : ""}",
              style: const TextStyle(color: Colors.grey),
            ),
            trailing: attempted
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.arrow_forward_ios, color: Colors.blue),
            onTap: attempted
                ? null
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
                      setState(() {
                        _quizzesFuture = _fetchQuizzes();
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
    final blue = Colors.blue;

    return Scaffold(
      backgroundColor: blue.shade50,
      appBar: AppBar(
        title: const Text(
          "Available Quizzes",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        backgroundColor: blue,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter dropdown always visible
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
                  borderRadius: BorderRadius.circular(12),
                  dropdownColor: Colors.white,
                  focusColor: Colors.blue.shade50,
                  value: _filterOption,
                  items: _filterOptions
                      .map(
                        (opt) => DropdownMenuItem(value: opt, child: Text(opt)),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _filterOption = val;
                      });
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
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Apply filter
                List<Map<String, dynamic>> quizzes = _applyFilter(
                  snapshot.data!,
                );

                if (quizzes.isEmpty) {
                  return const Center(
                    child: Text(
                      "No quizzes available for this filter.",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    final refreshed = await _fetchQuizzes();
                    setState(() => _quizzesFuture = Future.value(refreshed));
                  },
                  color: blue,
                  child: ListView.builder(
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
