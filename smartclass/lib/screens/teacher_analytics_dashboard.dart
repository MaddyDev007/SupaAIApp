import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class TeacherAnalyticsPage extends StatefulWidget {
  const TeacherAnalyticsPage({super.key});

  @override
  State<TeacherAnalyticsPage> createState() => _TeacherAnalyticsPageState();
}

class _TeacherAnalyticsPageState extends State<TeacherAnalyticsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> studentPerformance = [];

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    final teacherId = supabase.auth.currentUser!.id;

    final data = await supabase
        .from('results')
        .select(
          'score, student_id, subject, quiz_id, created_at, quizzes!inner(created_by), profiles!inner(name)',
        )
        .eq('quizzes.created_by', teacherId);

    setState(() {
      studentPerformance = List<Map<String, dynamic>>.from(data);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Teacher Analytics Dashboard")),
      body: studentPerformance.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Summary Cards
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _summaryCard(
                        "Total Students",
                        studentPerformance
                            .map((e) => e['student_id'])
                            .toSet()
                            .length
                            .toString(),
                        Colors.blue,
                      ),
                      _summaryCard(
                        "Quizzes Taken",
                        studentPerformance
                            .map((e) => e['quiz_id'])
                            .toSet()
                            .length
                            .toString(),
                        Colors.green,
                      ),
                      _summaryCard(
                        "Avg Score",
                        _calculateAverageScore().toStringAsFixed(1),
                        Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Performance Chart
                  SizedBox(
                    height: 250,
                    child: BarChart(
                      BarChartData(
                        barGroups: List.generate(studentPerformance.length, (
                          index,
                        ) {
                          final e = studentPerformance[index];
                          final score = e['score'] ?? 0;
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: (score / 10) * 100, // fixed 10 questions
                                color: Colors.blue,
                                width: 16,
                              ),
                            ],
                          );
                        }).toList(),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final student = studentPerformance.firstWhere(
                                  (e) =>
                                      e['profiles']['name'].hashCode ==
                                      value.toInt(),
                                  orElse: () => {},
                                );
                                return Text(
                                  student['profiles']?['name'] ?? '',
                                  style: const TextStyle(fontSize: 10),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Detailed Table
                  DataTable(
                    columns: const [
                      DataColumn(label: Text("Student")),
                      DataColumn(label: Text("Subject")),
                      DataColumn(label: Text("Score")),
                      DataColumn(label: Text("Date")),
                    ],
                    rows: studentPerformance.map((e) {
                      return DataRow(
                        cells: [
                          DataCell(Text(e['profiles']?['name'] ?? "")),
                          DataCell(Text(e['subject'] ?? "")),
                          DataCell(Text("${e['score']}/10")),
                          DataCell(
                            Text(
                              e['created_at'] != null
                                  ? DateFormat(
                                      'yyyy-MM-dd',
                                    ).format(DateTime.parse(e['created_at']))
                                  : "",
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _summaryCard(String title, String value, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, color: color)),
          ],
        ),
      ),
    );
  }

  double _calculateAverageScore() {
    if (studentPerformance.isEmpty) return 0;
    final total = studentPerformance.fold(
      0,
      (int sum, e) => sum + ((e['score'] ?? 0) as int),
    );
    return total / studentPerformance.length;
  }
}
