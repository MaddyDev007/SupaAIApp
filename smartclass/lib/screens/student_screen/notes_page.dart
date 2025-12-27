import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smartclass/screens/common_screen/error_page.dart';
import 'package:smartclass/screens/student_screen/editnote.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'view_note_page.dart';
// import 'portrait_only.dart';

class NotesPage extends StatefulWidget {
  final String classId;
  const NotesPage({super.key, required this.classId});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final supabase = Supabase.instance.client;

  late Future<List<Map<String, dynamic>>> _notesFuture;
  Object? _errorObj;
  StackTrace? _errorStack;

  @override
  void initState() {
    super.initState();
    _notesFuture = _fetchNotes();
  }

  // ---------------- FETCH NOTES ----------------
  Future<List<Map<String, dynamic>>> _fetchNotes() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception("User not signed in");
      }

      final res = await supabase
          .from('notes')
          .select()
          .eq('user_id', user.id)
          .eq('class_id', widget.classId) 
          .order('created_at', ascending: false)
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw TimeoutException("Notes fetch timed out"),
          );

      return List<Map<String, dynamic>>.from(res);
    } catch (e, st) {
      _errorObj = e;
      _errorStack = st;
      rethrow;
    }
  }

  // ---------------- DELETE NOTE ----------------
  Future<void> _deleteNote(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text("Confirm Delete", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text("Are you sure you want to delete this note?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Yes, Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final fetched = await supabase
          .from('notes')
          .select('image_url')
          .eq('id', id)
          .maybeSingle();

      if (fetched != null &&
          fetched['image_url'] != null &&
          fetched['image_url'].toString().isNotEmpty) {
        final fileName = fetched['image_url'].split('/').last;
        await supabase.storage.from('notes').remove([fileName]);
      }

      await supabase.from('notes').delete().eq('id', id);

      if (mounted) {
        setState(() {
          _notesFuture = _fetchNotes();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Note deleted"),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error deleting note. $e"),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // ---------------- NAV ANIMATION ----------------
  Future<T?> pushWithAnimation<T>(BuildContext context, Widget page) {
    return Navigator.push<T?>(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: const Cubic(0.22, 0.61, 0.36, 1.0),
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      ),
    );
  }

  // ---------------- OPEN EDIT PAGE ----------------
  void _openEditNotePage({Map<String, dynamic>? note}) async {
    final result = await pushWithAnimation<bool?>(
      context,
      EditNotePage(note: note, classId: widget.classId),
    );

    if (result == true) {
      setState(() {
        _notesFuture = _fetchNotes();
      });
    }
  }

  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Notes",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: Theme.of(context).primaryColor,
        onRefresh: () async {
          setState(() {
            _notesFuture = _fetchNotes();
          });
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _notesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              );
            }

            if (snapshot.hasError) {
              return SmartClassErrorPage(
                type: SmartClassErrorPage.mapToType(_errorObj),
                error: _errorObj,
                stackTrace: _errorStack,
                onRetry: () {
                  setState(() {
                    _notesFuture = _fetchNotes();
                  });
                },
              );
            }

            final notes = snapshot.data ?? [];

            if (notes.isEmpty) {
              return SmartClassErrorPage(
                type: SmartErrorType.notFound,
                title: "No notes yet",
                message: "Tap + to add your first note.",
                onRetry: () {
                  setState(() {
                    _notesFuture = _fetchNotes();
                  });
                },
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                final cardColor = note['color'] != null
                    ? Color(int.parse(note['color']))
                    : Colors.white;

                return Card(
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    splashColor: cardColor.withAlpha(120),
                    onTap: () {
                      pushWithAnimation(
                        context,
                        PortraitOnly(
                          child: ViewNotePage(
                            title: note['title'],
                            content: note['content'],
                            imageUrl: note['image_url'],
                            noteId: note['id'],
                            color: cardColor,
                            onEdit: () {
                              Navigator.pop(context);
                              _openEditNotePage(note: note);
                            },
                            onDelete: () async {
                              await _deleteNote(note['id']);
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      note['title'] ?? '',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      note['content'] ?? '',
                                      style: TextStyle(color: Colors.grey[700]),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),

                                    Text(
                                      note['created_at'] != null
                                          ? DateTime.parse(
                                              note['created_at'],
                                            ).toLocal().toString().split(' ')[0]
                                          : '',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (note['image_url'] != null &&
                                  note['image_url'].toString().isNotEmpty) ...[
                                const SizedBox(width: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    note["image_url"],
                                    height: 70,
                                    width: 70,
                                    fit: BoxFit.cover,
                                    // While loading
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        height: 70,
                                        width: 70,
                                        color: Colors.grey.shade200,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: Theme.of(context).primaryColor,
                                            strokeWidth: 2.5,
                                            value:
                                                loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                : null,
                                          ),
                                        ),
                                      );
                                    },
                                    // If loading fails
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              height: 70,
                                              width: 70,
                                              color: Colors.grey.shade300,
                                              child: const Icon(
                                                Icons.broken_image,
                                                color: Colors.grey,
                                              ),
                                            ),
                                  ),
                                ),
                              ],
                            ],
                          ),

                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_red_eye,
                                  color: Color.fromARGB(255, 102, 224, 224),
                                ),
                                onPressed: () {
                                  pushWithAnimation(
                                    context,
                                    PortraitOnly(
                                      child: ViewNotePage(
                                        title: note['title'],
                                        content: note['content'],
                                        imageUrl: note['image_url'],
                                        noteId: note['id'],
                                        color: note['color'] != null
                                            ? Color(int.parse(note['color']))
                                            : Colors.white,
                                        onEdit: () {
                                          Navigator.pop(
                                            context,
                                          ); // close detail page
                                          _openEditNotePage(note: note);
                                        },
                                        onDelete: () async {
                                          await _deleteNote(note['id']);
                                          Navigator.pop(
                                            context,
                                          ); // close after delete
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),

                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blueAccent,
                                ),
                                onPressed: () {
                                  _openEditNotePage(note: note);
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _deleteNote(note['id']),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _openEditNotePage(),
      ),
    );
  }
}
