import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartclass/screens/common_screen/error_page.dart';

class ListStudentPage extends StatefulWidget {
  final String classId;
  final String className;

  const ListStudentPage({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<ListStudentPage> createState() => _ListStudentPageState();
}

class _ListStudentPageState extends State<ListStudentPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _hasError = false;
  Object? _errorObj;
  StackTrace? _errorStack;

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];

  String _searchQuery = '';
  int get totalStudents => _students.length;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  // ---------------- FETCH STUDENTS ----------------
  Future<void> _fetchStudents() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorObj = null;
      _errorStack = null;
    });

    try {
      final response = await supabase
          .from('class_members')
          .select('''
          user_id,
          joined_at,
          users (
            id,
            name,
            email,
            avatar_url
          )
        ''')
          .eq('class_id', widget.classId)
          .eq('student', true) // ✅ KEY FILTER
          .order('joined_at', ascending: true)
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () => throw TimeoutException('Student fetch timed out'),
          );

      _students = List<Map<String, dynamic>>.from(response);
      _filteredStudents = List.from(_students);

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

  // ---------------- SEARCH ----------------
  void _applySearch(String value) {
    _searchQuery = value.toLowerCase();

    _filteredStudents = _students.where((row) {
      final user = row['users'] ?? {};
      final name = (user['name'] ?? '').toString().toLowerCase();
      // final email = (user['email'] ?? '').toString().toLowerCase();

      return name.contains(_searchQuery) /*  || email.contains(_searchQuery) */;
    }).toList();

    setState(() {});
  }

  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(widget.className), centerTitle: true),
      body: Column(
        children: [
          // 🔍 Search Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: _applySearch,
              decoration: InputDecoration(
                hintText: 'Search students',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 1.2,
                  ),
                ),
                avatar: Icon(
                  Icons.group,
                  size: 18,
                  color: Theme.of(context).primaryColor,
                ),
                label: Text(
                  'Total: $totalStudents',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                backgroundColor: Theme.of(
                  context,
                ).primaryColor.withOpacity(0.12),
              ),
            ),
          ),

          // Content
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // ---------------- BODY ----------------
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return SmartClassErrorPage(
        type: SmartClassErrorPage.mapToType(_errorObj),
        error: _errorObj,
        stackTrace: _errorStack,
        onRetry: _fetchStudents,
      );
    }

    if (_filteredStudents.isEmpty) {
      return SmartClassErrorPage(
        type: SmartErrorType.notFound,
        title: 'No students enrolled',
        message: 'Students have not joined this class yet.',
        onRetry: _fetchStudents,
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchStudents,
      color: Theme.of(context).primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredStudents.length,
        itemBuilder: (context, index) {
          final user = _filteredStudents[index]['users'] ?? {};
          return _buildStudentCard(
            index + 1,
            user['name'],
            user['email'],
            user,
          );
        },
      ),
    );
  }

  // ---------------- STUDENT CARD ----------------
  Widget _buildStudentCard(
    int index,
    String? name,
    String? email,
    Map<String, dynamic> user,
  ) {
    final theme = Theme.of(context);
    final avatarUrl = user['avatar_url'];

    return Card(
      color: theme.cardColor,
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: theme.primaryColor,
        width: 1.5,
      ),),
      child: ListTile(
        leading: CircleAvatar(
          radius: 15, // AppBar-friendly size
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null ? const Icon(Icons.person, size: 20) : null,
        ),
        title: Text(
          name ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(email ?? ''),
      ),
    );
  }
}
