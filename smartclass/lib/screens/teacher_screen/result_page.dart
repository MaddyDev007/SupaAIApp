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
  List<Map<String, dynamic>> filteredResults = [];
  bool isLoading = true;

  String searchQuery = '';
  String sortOption = 'Default';
  String selectedDepartment = 'All';
  String selectedYear = 'All';

  final List<String> sortOptions = ['Default', 'High → Low', 'Low → High'];
  final List<String> departmentOptions = [
    'All',
    'CSE',
    'ECE',
    'MECH',
    'EEE',
    'CIVIL',
  ]; // example departments
  final List<String> yearOptions = [
    'All',
    '1st year',
    '2nd year',
    '3rd year',
    '4th year',
  ]; // example years

  late final AnimationController _listController;
  late final Animation<double> _listAnimation;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _listAnimation = CurvedAnimation(
      parent: _listController,
      curve: Curves.easeOut,
    );
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
      final query = supabase
          .from('results')
          .select(
            'id, score, quiz_id, subject, student_id, profiles(name, email, department, year), quizzes!inner(created_by)',
          )
          .eq('quizzes.created_by', teacherId)
          .order('created_at', ascending: false);

      final response = await query;

      results = List<Map<String, dynamic>>.from(response);
      filteredResults = List.from(results);
      _listController.forward(from: 0);
      applyFilters();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to load results: Check your Internet.")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void applyFilters() {
    filteredResults = results.where((result) {
      final profile = result['profiles'] ?? {};
      final name = (profile['name'] ?? '').toString().toLowerCase();
      final department = (profile['department'] ?? '').toString();
      final year = (profile['year'] ?? '').toString();

      final matchesSearch = name.contains(searchQuery.toLowerCase());
      final matchesDept =
          selectedDepartment == 'All' || department == selectedDepartment;
      final matchesYear = selectedYear == 'All' || year == selectedYear;

      return matchesSearch && matchesDept && matchesYear;
    }).toList();

    applySort();
  }

  void applySort() {
    if (sortOption == 'High → Low') {
      filteredResults.sort(
        (a, b) => (b['score'] ?? 0).compareTo(a['score'] ?? 0),
      );
    } else if (sortOption == 'Low → High') {
      filteredResults.sort(
        (a, b) => (a['score'] ?? 0).compareTo(b['score'] ?? 0),
      );
    } else {
      filteredResults.sort(
        (a, b) => (b['created_at'] ?? '').toString().compareTo(
          (a['created_at'] ?? '').toString(),
        ),
      );
    }
    setState(() {});
  }

  Widget _buildResultCard(Map<String, dynamic> result, int index) {
    final profile = result['profiles'] ?? {};
    final studentName = profile['name'] ?? "Unknown";
    final studentDepartment = profile['department'] ?? "N/A";
    final studentYear = profile['year'] ?? "N/A";

    final slideTween = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOut));

    return FadeTransition(
      opacity: _listAnimation,
      child: SlideTransition(
        position: _listAnimation.drive(slideTween),
        child: Card(
          color: Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            leading: const CircleAvatar(
              backgroundColor: Colors.blue,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text(
              studentName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              "Subject: ${result['subject']}\nDepartment: $studentDepartment \nYear: $studentYear",
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
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
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
      backgroundColor: blue.shade50,
      appBar: AppBar(
        title: const Text(
          "Quiz Results",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        backgroundColor: blue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Sort Popup Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (val) {
              sortOption = val;
              applyFilters();
            },
            itemBuilder: (_) => sortOptions
                .map((opt) => PopupMenuItem(value: opt, child: Text(opt)))
                .toList(),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [blue.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Search + Clear
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                onChanged: (val) {
                  searchQuery = val;
                  applyFilters();
                },
                decoration: InputDecoration(
                  hintText: "Search by name",
                  prefixIcon: const Icon(Icons.search, color: Colors.grey,),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey,),
                          onPressed: () {
                            searchQuery = '';
                            applyFilters();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue.shade100),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.blue.shade300,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            // Department & Year Dropdowns
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedDepartment,
                      items: departmentOptions
                          .map(
                            (opt) =>
                                DropdownMenuItem(value: opt, child: Text(opt)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          selectedDepartment = val;
                          applyFilters();
                        }
                      },
                      decoration: InputDecoration(
                        labelText: "Department",
                        labelStyle: TextStyle(color: Colors.blue),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue.shade100),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.blue.shade300,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedYear,
                      items: yearOptions
                          .map(
                            (opt) =>
                                DropdownMenuItem(value: opt, child: Text(opt)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          selectedYear = val;
                          applyFilters();
                        }
                      },
                      decoration: InputDecoration(
                        labelText: "Year",
                        labelStyle: TextStyle(color: Colors.blue),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue.shade100),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.blue.shade300,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Results List
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredResults.isEmpty
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
                        itemCount: filteredResults.length,
                        itemBuilder: (context, index) =>
                            _buildResultCard(filteredResults[index], index),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
