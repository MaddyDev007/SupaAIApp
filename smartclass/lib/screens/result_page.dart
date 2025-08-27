import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResultPage extends StatefulWidget {
  const ResultPage({super.key});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> results = [];
  bool isLoading = true;

  late final AnimationController _listController;
  late final Animation<double> _listAnimation;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _listAnimation =
        CurvedAnimation(parent: _listController, curve: Curves.easeOut);
    fetchResults();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<void> fetchResults() async {
    final teacherId = supabase.auth.currentUser!.id;

    setState(() => isLoading = true);
    try {
      // Use PostgrestFilterBuilder first, then await after eq()
      final query = supabase
          .from('results')
          .select(
            'id, score, quiz_id, subject, student_id, profiles(name, email), quizzes!inner(created_by)',
          )
          .eq('quizzes.created_by', teacherId)
          .order('created_at', ascending: false);

      final response = await query;

      results = List<Map<String, dynamic>>.from(response);
      _listController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to load results: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _buildResultCard(Map<String, dynamic> result, int index) {
    final profile = result['profiles'] ?? {};
    final studentName = profile['name'] ?? "Unknown";
    final studentEmail = profile['email'] ?? "No email";

    final slideTween =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOut));

    return FadeTransition(
      opacity: _listAnimation,
      child: SlideTransition(
        position: _listAnimation.drive(slideTween),
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: const CircleAvatar(
              backgroundColor: Colors.blue,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text(
              studentName,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              "Email: $studentEmail\nSubject: ${result['subject']}",
              style: const TextStyle(color: Colors.grey),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Score: ${result['score']}",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blue = Colors.blue;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Quiz Results", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: blue,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [blue.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : results.isEmpty
                ? const Center(
                    child: Text(
                      "No results found",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: fetchResults,
                    color: blue,
                    child: ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) =>
                          _buildResultCard(results[index], index),
                    ),
                  ),
      ),
    );
  }
}
