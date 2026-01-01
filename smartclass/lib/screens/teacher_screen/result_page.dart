import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smartclass/screens/common_screen/error_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResultPage extends StatefulWidget {
    final String classId; 
  const ResultPage({super.key, required this.classId});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> results = [];
  List<Map<String, dynamic>> filteredResults = [];
  bool isLoading = true;
  bool _hasError = false;
  Object? _errorObj;
  StackTrace? _errorStack;

  String searchQuery = '';
  String sortOption = 'Default';

  final List<String> sortOptions = ['Default', 'High → Low', 'Low → High'];
  

  late final AnimationController _listController;
  late final Animation<double> _listAnimation;
  final TextEditingController _searchController = TextEditingController();

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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchResults() async {
  final user = supabase.auth.currentUser;
  if (user == null) {
    if (!mounted) return;
    setState(() {
      isLoading = false;
      _hasError = true;
      _errorObj = Exception('Not signed in');
      _errorStack = StackTrace.current;
    });
    return;
  }


  if (!mounted) return;
  setState(() {
    isLoading = true;
    _hasError = false;   // reset
    _errorObj = null;    // reset
    _errorStack = null;  // reset
  });

  try {
    final response = await supabase
          .from('results')
          .select(
            '''
            id,
            score,
            subject,
            student_id,
            created_at,
            student_name,
            avatar_url
            ''',
          )
          .eq('class_id', widget.classId) // ✅ KEY CHANGE
          .order('created_at', ascending: false)
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () =>
                throw TimeoutException('Results fetch timed out'),
          );

    results = List<Map<String, dynamic>>.from(response);
    filteredResults = List.from(results);

    _listController.forward(from: 0);
    applyFilters(); // will call setState inside applySort()
  } on TimeoutException catch (e, st) {
    if (!mounted) return;
    setState(() {
      _hasError = true;
      _errorObj = e;
      _errorStack = st;
    });
  } catch (e, st) {
    if (!mounted) return;
    setState(() {
      _hasError = true;
      _errorObj = e;
      _errorStack = st;
    });
  } finally {
    setState(() => isLoading = false);
  }
}


  void applyFilters() {
    filteredResults = results.where((result) {
      final name =
    (result['student_name'] ?? '').toString().toLowerCase();
      return name.contains(searchQuery.toLowerCase());
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
    final studentName = result['student_name'] ?? "Unknown";


    final slideTween = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOut));

    return FadeTransition(
      opacity: _listAnimation,
      child: SlideTransition(
        position: _listAnimation.drive(slideTween),
        child: Card(
          color: Theme.of(context).cardColor,
          margin: const EdgeInsets.symmetric(vertical: 8,),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            leading:  CircleAvatar(
                  radius: 25,
                  backgroundImage: result['avatar_url'] != null
                      ? NetworkImage(result['avatar_url'])
                      : null,
                  child: result['avatar_url'] == null
                      ? const Icon(Icons.person)
                      : null,
                ),
            title: Text(
              studentName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              "Subject: ${result['subject']}",
              style: const TextStyle(color: Colors.grey),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withAlpha((0.2 * 255).toInt()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Score: ${result['score']}",
                style:  TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  void _resetSearchAndFetch() {
  searchQuery = '';
  _searchController.clear(); // clears TextField
  filteredResults = List.from(results);
  fetchResults();
}

  Widget _buildContent() {
    // Always return a scrollable so RefreshIndicator works
    if (isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children:  [
          SizedBox(height: 160),
          Center(child: CircularProgressIndicator(
            color: Theme.of(context).primaryColor,
          )),
          SizedBox(height: 300),
        ],
      );
    }

    if (_hasError) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // const SizedBox(height: 80),
          SmartClassErrorPage(
            standalone: false,
            type: SmartClassErrorPage.mapToType(_errorObj),
            error: _errorObj,
            stackTrace: _errorStack,
            onRetry: _resetSearchAndFetch,
          ),
          // const SizedBox(height: 300),
        ],
      );
    }

    if (filteredResults.isEmpty) {
      return ListView(
        
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // SizedBox(height: 120),
          // Use your SmartClass not-found preset
          SmartClassErrorPage(
            standalone: false,
            type: SmartErrorType.notFound,
            title: 'No materials yet',
            onRetry: _resetSearchAndFetch,
            message: 'Try a different search or pull to refresh.',
          ),
          // const SizedBox(height: 300),
        ],
      );
    }

    // Data list
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: filteredResults.length,
      itemBuilder: (context, index) =>
          _buildResultCard(filteredResults[index], index),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Quiz Results",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Sort Popup Menu
          PopupMenuButton<String>(
            color: Theme.of(context).cardColor,
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
      body: Column(
        children: [
          // Search + Clear
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                searchQuery = val;
                applyFilters();
              },
              decoration: InputDecoration(
                hintText: "Search by name",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),  
              ),
            ),
          ),
          // Department & Year Dropdown
          // Results List
          const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            color: Theme.of(context).primaryColor,
            onRefresh: fetchResults,
            child: _buildContent(),
          ),
        ),
        ],
      ),
    );
  }
}
