import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smartclass/screens/teacher_screen/StudentPerformancePage.dart';
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
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            const Duration(seconds: 20),
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

  Future<void> _confirmRemoveStudent(
    String studentId,
    String? studentName,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove student',
          style:  Theme.of(context).textTheme.titleLarge,
        ),
        content: Text(
          'Are you sure you want to remove: \n'
          '• The Student can no longer attend quizs\n'
          '• The Result of that student also be delete\n'
          '• The Notes that the student saved also be delete\n'
          'Sure to remove ${studentName ?? "this student"} from this class?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _removeStudent(studentId);
    }
  }

  Future<void> _removeStudent(String studentId) async {
    try {
      // Notes and note images are private to the note owner. Removing a
      // student from a class must not delete their personal notes.

      // 🔹 Delete results
      await supabase
          .from('results')
          .delete()
          .eq('class_id', widget.classId)
          .eq('student_id', studentId);

      // 🔹 Remove membership
      await supabase
          .from('class_members')
          .delete()
          .eq('class_id', widget.classId)
          .eq('user_id', studentId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).cardColor,
          content: Text(
            'Student and related data removed',
            style: TextStyle(color: Theme.of(context).dividerColor),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      _fetchStudents();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).cardColor,
          content: Text(
            'Failed: $e',
            style: TextStyle(color: Theme.of(context).dividerColor),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
  void _resetSearchAndFetch() {
  _searchQuery = '';
  _searchController.clear(); // clears TextField
  _filteredStudents = List.from(_students);
  _fetchStudents();
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
              controller: _searchController,
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
      return  Center(child: CircularProgressIndicator(
        color: Theme.of(context).primaryColor,
      ));
    }

    if (_hasError) {
      return SmartClassErrorPage(
        type: SmartClassErrorPage.mapToType(_errorObj),
        error: _errorObj,
        stackTrace: _errorStack,
        onRetry: _resetSearchAndFetch,
      );
    }

    if (_filteredStudents.isEmpty) {
      return SmartClassErrorPage(
        type: SmartErrorType.notFound,
        title: 'No students enrolled',
        message: 'Students have not joined this class yet.',
        onRetry: _resetSearchAndFetch,
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
            _filteredStudents[index]['user_id'],
            user,
          );
        },
      ),
    );
  }

  static const _curve = Cubic(0.22, 0.61, 0.36, 1.0);
  static final _slideTween = Tween<Offset>(
    begin: const Offset(1, 0),
    end: Offset.zero,
  );

  Future<dynamic> pushWithAnimation(BuildContext context, Widget page) {
    return Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(parent: animation, curve: _curve);
          return SlideTransition(
            position: _slideTween.animate(curved),
            child: child,
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
    String studentId,
    Map<String, dynamic> user,
  ) {
    final theme = Theme.of(context);
    final avatarUrl = user['avatar_url'];

    return Card(
      color: theme.cardColor,
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.primaryColor, width: 1.5),
      ),
      child: ListTile(
        onTap: () {
          pushWithAnimation(
            context,
            StudentPerformancePage(
              classId: widget.classId,
              studentId: studentId,
              studentName: name ?? 'Student',
            ),
          );
        },
        trailing: PopupMenuButton<String>(
          elevation: 3,
          color: Theme.of(context).scaffoldBackgroundColor,
          onSelected: (value) {
            if (value == 'performance') {
              pushWithAnimation(
                context,
                StudentPerformancePage(
                  classId: widget.classId,
                  studentId: studentId,
                  studentName: name ?? 'Student',
                ),
              );
            } else if (value == 'remove') {
              _confirmRemoveStudent(studentId, name);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'performance',
              child: Row(
                spacing: 10,
                children: [
                  Icon(Icons.trending_up_rounded, color: Theme.of(context).dividerColor,),
                  Text(
                    'View performance',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'remove',
              child: Row(
                spacing: 10,
                children: [
                  Icon(Icons.delete),
                  Text(
                    'Remove from class',
                    style: TextStyle(color: Theme.of(context).dividerColor),
                  ),
                ],
              ),
            ),
          ],
        ),

        leading: CircleAvatar(
          backgroundColor: Colors.blueAccent,
          radius: 15, // AppBar-friendly size
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? const Icon(Icons.person, size: 20, color: Colors.white)
              : null,
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
