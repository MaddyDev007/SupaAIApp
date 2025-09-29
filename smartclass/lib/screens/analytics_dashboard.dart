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
      : _results.map((r) => r['score'] as int).reduce((a, b) => a + b) /
          _results.length;

  int get highestScore => _results.isEmpty
      ? 0
      : _results.map((r) => r['score'] as int).reduce((a, b) => a > b ? a : b);

  int get lowestScore => _results.isEmpty
      ? 0
      : _results.map((r) => r['score'] as int).reduce((a, b) => a < b ? a : b);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text(
          "Performance Analytics",
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Stat Cards
                    Row(
                      children: [
                        _buildStatCard(
                          "Avg Score",
                          averageScore.toStringAsFixed(1),
                          Colors.blue,
                          Icons.bar_chart,
                        ),
                        _buildStatCard(
                          "High Score",
                          "$highestScore",
                          Colors.green,
                          Icons.trending_up,
                        ),
                        _buildStatCard(
                          "Low Score",
                          "$lowestScore",
                          Colors.red,
                          Icons.trending_down,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Chart Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Quiz Scores Overview",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 280,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: (_results.length * 80).toDouble(),
                                child: BarChart(
                                  BarChartData(
                                    minY: 0,
                                    maxY: 10,
                                    gridData: FlGridData(show: false),
                                    borderData: FlBorderData(show: false),
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 32,
                                          interval: 2,
                                          getTitlesWidget: (value, meta) {
                                            if (value < 0 || value > 10) {
                                              return const SizedBox();
                                            }
                                            return Text(
                                              value.toInt().toString(),
                                              style:
                                                  const TextStyle(fontSize: 12),
                                            );
                                          },
                                        ),
                                      ),
                                      rightTitles: AxisTitles(
                                          sideTitles:
                                              SideTitles(showTitles: false)),
                                      topTitles: AxisTitles(
                                          sideTitles:
                                              SideTitles(showTitles: false)),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            int index = value.toInt();
                                            if (index < 0 ||
                                                index >= _results.length) {
                                              return const SizedBox();
                                            }
                                            return Transform.rotate(
                                              angle: 0, // ~45°
                                              child: Text(
                                                _results[index]['subject'] ??
                                                    "-",
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    barGroups: _results.asMap().entries.map((
                                      entry,
                                    ) {
                                      int index = entry.key;
                                      final data = entry.value;
                                      return BarChartGroupData(
                                        x: index,
                                        barRods: [
                                          BarChartRodData(
                                            toY: (data['score'] as num)
                                                .toDouble(),
                                            gradient: const LinearGradient(
                                              colors: [
                                                Colors.blue,
                                                Colors.purple
                                              ],
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                            ),
                                            width: 22,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                        ],
                                        showingTooltipIndicators: [0],
                                      );
                                    }).toList(),
                                    barTouchData: BarTouchData(
                                      enabled: true,
                                      touchTooltipData: BarTouchTooltipData(
                                        getTooltipColor: (group) =>
                                            Colors.transparent,
                                        tooltipPadding: EdgeInsets.zero,
                                        tooltipMargin: 0,
                                        getTooltipItem: (
                                          group,
                                          groupIndex,
                                          rod,
                                          rodIndex,
                                        ) {
                                          return BarTooltipItem(
                                            "${rod.toY.toInt()} / 10",
                                            const TextStyle(
                                              
                                              fontWeight: FontWeight.w500,
                                              fontSize: 10,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Detailed Table
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            "Detailed Results",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  Colors.blue.shade50,
                                ),
                                border: TableBorder.all(
                                  color: Colors.grey.shade200,
                                ),
                                columns: const [
                                  DataColumn(label: Text("S.No")),
                                  DataColumn(label: Text("Subject")),
                                  DataColumn(label: Text("Score")),
                                  DataColumn(label: Text("Date")),
                                ],
                                rows: _results.asMap().entries.map((entry) {
                                  int index = entry.key;
                                  final data = entry.value;
                                  String formattedDate = DateFormat(
                                    'dd-MM-yyyy',
                                  ).format(DateTime.parse(data['created_at']));
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
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.8), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: Colors.white),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
