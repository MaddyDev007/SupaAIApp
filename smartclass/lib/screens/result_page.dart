import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResultPage extends StatefulWidget {
  const ResultPage({super.key});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> results = [];
  bool loading = true;
  String? error;

  Future<void> loadResults() async {
    try {
      final response = await supabase.from('results').select('*');
      if (!mounted) return;
      setState(() {
        results = response;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Failed to load results: $e';
        loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadResults();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Results')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : results.isEmpty
                  ? const Center(child: Text('No results available.'))
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final r = results[i];
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            title: Text("Student email: ${r['student_name']}"),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Score: ${r['score']}"),
                                
                                if (r.containsKey('quiz_id'))
                                  Text("Quiz ID: ${r['quiz_id']}"),
                                  Text("subject: ${r['subject']}"),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
