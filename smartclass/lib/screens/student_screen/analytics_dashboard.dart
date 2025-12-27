import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:smartclass/screens/common_screen/error_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AnalyticsDashboard extends StatefulWidget {
  final String classId; // ✅ NEW

  const AnalyticsDashboard({super.key, required this.classId});

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  bool _isLoading = true;
  bool _hasError = false;

  List<Map<String, dynamic>> _results = [];
  Object? _errorObj;
  StackTrace? _errorStack;

  @override
  void initState() {
    super.initState();
    _fetchResults();
  }

  // ---------------- FETCH RESULTS (CLASS-BASED) ----------------
  Future<void> _fetchResults() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorObj = null;
      _errorStack = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User not signed in');
      }

      final response = await supabase
          .from('results')
          .select('score, created_at, subject')
          .eq('student_id', user.id)
          .eq('class_id', widget.classId) // ✅ KEY CHANGE
          .order('created_at', ascending: true)
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw TimeoutException('Results fetch timed out'),
          );

      if (!mounted) return;
      setState(() {
        _results = List<Map<String, dynamic>>.from(response);
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

  // ---------------- STATS ----------------
  double get averageScore => _results.isEmpty
      ? 0
      : _results
                .map((r) => (r['score'] as num).toDouble())
                .reduce((a, b) => a + b) /
            _results.length;

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

  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    Widget bodyChild;

    if (_isLoading) {
      bodyChild = Center(
        child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
      );
    } else if (_hasError) {
      bodyChild = SmartClassErrorPage(
        type: SmartClassErrorPage.mapToType(_errorObj),
        error: _errorObj,
        stackTrace: _errorStack,
        onRetry: _fetchResults,
      );
    } else if (_results.isEmpty) {
      bodyChild = SmartClassErrorPage(
        type: SmartErrorType.notFound,
        title: 'No results yet',
        message: 'Take a quiz to see your analytics here.',
        onRetry: _fetchResults,
      );
    } else {
      bodyChild = RefreshIndicator(
        color: Theme.of(context).primaryColor,
        onRefresh: _fetchResults,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---------- STAT CARDS ----------
                Row(
                  children: [
                    _buildStatCard(
                      "High Score",
                      "$highestScore",
                      Colors.green,
                      Icons.trending_up,
                    ),
                    _buildStatCard(
                      "Avg Score",
                      averageScore.toStringAsFixed(1),
                      Colors.blue,
                      Icons.bar_chart,
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

                // ---------- BAR CHART ----------
                _buildBarChart(),

                const SizedBox(height: 24),

                // ---------- DETAILED TABLE ----------
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
        title: const Text(
          "Performance Analytics",
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: bodyChild,
    );
  }

  // ---------------- BAR CHART ----------------
  Widget _buildBarChart() {
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
          const Text(
            "Quiz Scores Overview",
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
                    gridData: FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: _buildChartTitles(),
                    barGroups: _results.asMap().entries.map((entry) {
                      final index = entry.key;
                      final data = entry.value;
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: (data['score'] as num).toDouble(),
                            gradient: const LinearGradient(
                              colors: [Colors.blue, Colors.purple],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            width: 22,
                            borderRadius: BorderRadius.circular(6),
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

  FlTitlesData _buildChartTitles() {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          interval: 2,
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
            final index = value.toInt();
            if (index < 0 || index >= _results.length) {
              return const SizedBox();
            }
            return Transform.rotate(
              angle: 0,
              child: Text(
                _results[index]['subject'] ?? "-",
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
                final index = entry.key;
                final data = entry.value;
                final dt = DateTime.tryParse(data['created_at'] ?? '');
                final formattedDate = dt == null
                    ? '-'
                    : DateFormat('dd-MM-yyyy').format(dt);

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
    );
  }

  // ---------------- STAT CARD ----------------
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
