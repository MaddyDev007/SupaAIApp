import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartclass/screens/common_screen/error_page.dart';

class StudentPerformancePage extends StatefulWidget {
  final String classId;
  final String studentId;
  final String studentName;

  const StudentPerformancePage({
    super.key,
    required this.classId,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentPerformancePage> createState() => _StudentPerformancePageState();
}

class _StudentPerformancePageState extends State<StudentPerformancePage> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _hasError = false;

  Object? _errorObj;
  StackTrace? _errorStack;

  List<Map<String, dynamic>> _results = [];

  // ---------------- INIT ----------------
  @override
  void initState() {
    super.initState();
    _fetchResults();
  }

  // ---------------- FETCH RESULTS ----------------
  Future<void> _fetchResults() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorObj = null;
      _errorStack = null;
    });

    try {
      final res = await supabase
          .from('results')
          .select('''
            score,
            created_at,
            quizzes (
              subject
            )
          ''')
          .eq('class_id', widget.classId)
          .eq('student_id', widget.studentId)
          .order('created_at', ascending: true)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Fetch timed out'),
          );

      _results = List<Map<String, dynamic>>.from(res);

      if (!mounted) return;
      setState(() => _isLoading = false);
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

  // ---------------- STATS ----------------
  double get averageScore {
    if (_results.isEmpty) return 0;
    final sum = _results
        .map((r) => (r['score'] as num).toDouble())
        .reduce((a, b) => a + b);
    return sum / _results.length;
  }

  int get highestScore => _results.isEmpty
      ? 0
      : _results
            .map((r) => (r['score'] as num).toInt())
            .reduce((a, b) => a > b ? a : b);

  int get lowestScore => _results.isEmpty
      ? 0
      : _results
            .map((r) => (r['score'] as num).toInt())
            .reduce((a, b) => a < b ? a : b);

  int get maxChartY => (_results.isEmpty)
      ? 10
      : (_results
                .map((r) => (r['score'] as num).toInt())
                .reduce((a, b) => a > b ? a : b) +
            2);

  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_isLoading) {
      body = Center(
        child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
      );
    } else if (_hasError) {
      body = SmartClassErrorPage(
        type: SmartClassErrorPage.mapToType(_errorObj),
        error: _errorObj,
        stackTrace: _errorStack,
        onRetry: _fetchResults,
      );
    } else if (_results.isEmpty) {
      body = SmartClassErrorPage(
        type: SmartErrorType.notFound,
        title: 'No results yet',
        message: 'This student has not attempted any quizzes.',
        onRetry: _fetchResults,
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _fetchResults,
        color: Theme.of(context).primaryColor,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _buildStatCard(
                      "High",
                      "$highestScore",
                      Colors.green,
                      Icons.trending_up,
                    ),
                    _buildStatCard(
                      "Average",
                      averageScore.toStringAsFixed(1),
                      Colors.blue,
                      Icons.bar_chart,
                    ),
                    _buildStatCard(
                      "Low",
                      "$lowestScore",
                      Colors.red,
                      Icons.trending_down,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildBarChart(),
                const SizedBox(height: 24),
                _buildTable(),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.studentName,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: body,
    );
  }

  // ---------------- BAR CHART ----------------
  Widget _buildBarChart() {
    return _cardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quiz Performance",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 280,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
               width: (_results.length.clamp(1, 9999) * 80).toDouble(),
                child: BarChart(
                  BarChartData(
                    minY: 0,
                    maxY: 11,
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(show: false),
                    titlesData: _chartTitles(),
                    barGroups: _results.asMap().entries.map((e) {
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: (e.value['score'] as num).toDouble(),
                            width: 22,
                            borderRadius: BorderRadius.circular(6),
                            gradient: const LinearGradient(
                              colors: [Colors.blue, Colors.purple],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ],
                        showingTooltipIndicators: const [0],
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
    );
  }

  FlTitlesData _chartTitles() {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: 2,
          reservedSize: 30,
          getTitlesWidget: (value, meta) {
            if (value < 0 || value > 10) {
              return const SizedBox();
            }
            return Text(
              value.toInt().toString(),
              style: const TextStyle(fontSize: 12),
            );
          },
        ),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, _) {
            final i = value.toInt();
            if (i < 0 || i >= _results.length) return const SizedBox();
            return Transform.rotate(
              angle: 0,
              child: Text(
                _results[i]['quizzes']?['subject'] ?? '-',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------- TABLE ----------------
  Widget _buildTable() {
    return _cardWrapper(
      child: Column(
        children: [
          const Text(
            "Detailed Results",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                Theme.of(context).scaffoldBackgroundColor,
              ),
              border: TableBorder.all(color: Colors.grey.shade200),
              columns: const [
                DataColumn(label: Text("S.No")),
                DataColumn(label: Text("Quiz")),
                DataColumn(label: Text("Score")),
                DataColumn(label: Text("Date")),
              ],
              rows: _results.asMap().entries.map((e) {
                final dt = DateTime.tryParse(e.value['created_at'] ?? '');
                return DataRow(
                  cells: [
                    DataCell(Text("${e.key + 1}")),
                    DataCell(Text(e.value['quizzes']?['subject'] ?? '-')),
                    DataCell(Text("${e.value['score']}/10")),
                    DataCell(
                      Text(
                        dt == null ? '-' : DateFormat('dd-MM-yyyy').format(dt),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- HELPERS ----------------
  Widget _cardWrapper({required Widget child}) {
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
      child: child,
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
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.8), color],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
