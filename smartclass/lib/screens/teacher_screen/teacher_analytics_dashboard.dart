import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smartclass/screens/common_screen/error_page.dart';
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
  bool _isLoading = true;
  Object? _errorObj; // 👈 add
  StackTrace? _errorStack; // 👈 add
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _hasError = true;
        _errorObj = Exception('Not signed in');
        _errorStack = StackTrace.current;
        _isLoading = false;
      });
      return;
    }
    final teacherId = user.id;
    try {
      final data = await supabase
          .from('results')
          .select(
            'score, student_id, subject, quiz_id, created_at, quizzes!inner(created_by), profiles!inner(name)',
          )
          .eq('quizzes.created_by', teacherId)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw TimeoutException('Analytics fetch timed out'),
          );

      setState(() {
        studentPerformance = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorObj = e;
        _errorStack = st;
      });
    }
  }

  double _calculateAverageScore() {
    if (studentPerformance.isEmpty) return 0;
    final total = studentPerformance.fold<int>(
      0,
      (sum, e) => sum + ((e['score'] ?? 0) as int),
    );
    return total / studentPerformance.length;
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyChild;
    if (_isLoading) {
      bodyChild = Center(child: CircularProgressIndicator(
         color: Theme.of(context).primaryColor,
      ));
    } else if (_hasError) {
      bodyChild = SmartClassErrorPage(
        type: SmartClassErrorPage.mapToType(_errorObj),
        error: _errorObj,
        stackTrace: _errorStack,
        onRetry: _fetchAnalytics,
      );
    } else if (studentPerformance.isEmpty) {
      bodyChild = SmartClassErrorPage(
        type: SmartErrorType.notFound,
        title: 'No results yet',
        message: 'Students didnot take any quizzes yet.',
        onRetry: _fetchAnalytics,
      );
    } else {
      bodyChild = RefreshIndicator(
        color: Theme.of(context).primaryColor,
        onRefresh: _fetchAnalytics,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                /// 🔹 Summary Cards
                Row(
                  children: [
                    _buildStatCard(
                      "Total Students",
                      studentPerformance
                          .map((e) => e['student_id'])
                          .toSet()
                          .length
                          .toString(),
                      Colors.blue,
                      Icons.people,
                    ),
                    _buildStatCard(
                      "Quizzes Taken",
                      studentPerformance
                          .map((e) => e['quiz_id'])
                          .toSet()
                          .length
                          .toString(),
                      Colors.green,
                      Icons.assignment,
                    ),
                    _buildStatCard(
                      "Avg Score",
                      _calculateAverageScore().toStringAsFixed(1),
                      Colors.orange,
                      Icons.bar_chart,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                /// 🔹 Performance Chart
                _buildPerformanceChart(),

                const SizedBox(height: 24),

                /// 🔹 Detailed Table
                _buildDetailedTable(),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Teacher Analytics Dashboard",
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: bodyChild,
    );
  }

  /// 📊 Performance Chart Widget
  Widget _buildPerformanceChart() {
    return _buildCard(
      title: "Student Performance",
      child: SizedBox(
        height: 280,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: (studentPerformance.length * 80).toDouble(),
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: 11.5,
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 2,
                      getTitlesWidget: (value, _) {
                        if (value < 0 || value > 10) return const SizedBox();
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) {
                        int index = value.toInt();
                        if (index < 0 || index >= studentPerformance.length) {
                          return const SizedBox();
                        }
                        return Text(
                          studentPerformance[index]['profiles']?['name'] ?? "-",
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: studentPerformance.asMap().entries.map((entry) {
                  int index = entry.key;
                  final score = (entry.value['score'] ?? 0) as int;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: score.toDouble(),
                        gradient: const LinearGradient(
                          colors: [Colors.blue, Colors.purple],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: 22,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                    showingTooltipIndicators: [0],
                  );
                }).toList(),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => Colors.transparent,
                    tooltipPadding: EdgeInsets.zero,
                    tooltipMargin: 0,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        "${rod.toY.toInt()} / 10 \n ${studentPerformance[group.x]['subject'] ?? "-"}",

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
    );
  }

  /// 📋 Detailed Table Widget
  Widget _buildDetailedTable() {
    return _buildCard(
      title: "Detailed Results",
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Theme.of(context).scaffoldBackgroundColor),
            border: TableBorder.all(color: Colors.grey.shade200),
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
                              'dd-MM-yyyy',
                            ).format(DateTime.parse(e['created_at']))
                          : "",
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// 📦 Reusable Card
  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  /// 🔹 Summary Stat Card
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
