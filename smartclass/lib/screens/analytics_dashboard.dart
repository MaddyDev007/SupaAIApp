import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AnalyticsDashboard extends StatefulWidget {
  const AnalyticsDashboard({super.key});

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _fetchResults();
  }

  Future<void> _fetchResults() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    final response = await supabase
        .from('results')
        .select('score, created_at, subject')
        .eq('student_id', user.id)
        .order('created_at', ascending: true);

    setState(() {
      _results = List<Map<String, dynamic>>.from(response);
      _isLoading = false;
    });
  }

  double get averageScore => _results.isEmpty
      ? 0
      : _results.map((r) => r['score'] as int).reduce((a, b) => a + b) / _results.length;

  int get highestScore =>
      _results.isEmpty ? 0 : _results.map((r) => r['score'] as int).reduce((a, b) => a > b ? a : b);

  int get lowestScore =>
      _results.isEmpty ? 0 : _results.map((r) => r['score'] as int).reduce((a, b) => a < b ? a : b);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Performance Analytics",
          style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.grey[100],
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Stats Cards
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatCard("Avg Score", averageScore.toStringAsFixed(1), Colors.blue),
                        _buildStatCard("High Score", "$highestScore", Colors.green),
                        _buildStatCard("Low Score", "$lowestScore", Colors.red),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Bar Chart
                    const Text("Quiz Scores", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  int index = value.toInt();
                                  if (index < 0 || index >= _results.length) return const SizedBox();
                                  return Text((index + 1).toString()); // quiz index
                                },
                              ),
                            ),
                          ),
                          barGroups: _results.asMap().entries.map((entry) {
                            int index = entry.key;
                            final data = entry.value;
                            return BarChartGroupData(
                              x: index ,
                              barRods: [
                                BarChartRodData(
                                  toY: (data['score'] as num).toDouble(),
                                  color: Colors.deepPurple,
                                  width: 16,
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Detailed Table
                    const Text("Detailed Results", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        border: TableBorder.all(color: Colors.grey.shade300),
                        columns: const [
                          DataColumn(label: Text("S.No")),
                          DataColumn(label: Text("Subject")),
                          DataColumn(label: Text("Score")),
                          DataColumn(label: Text("Date")),
                        ],
                        rows: _results.asMap().entries.map((entry) {
                          int index = entry.key;
                          final data = entry.value;
                          String formattedDate = DateFormat('dd-MM-yyyy')
                              .format(DateTime.parse(data['created_at']));
                          return DataRow(
                            cells: [
                              DataCell(Text("${index + 1}")),
                              DataCell(Text(data['subject'] ?? "-")),
                              DataCell(Text("${data['score']}/10")),
                              DataCell(Text(formattedDate)),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
