import 'package:flutter/material.dart';
import 'package:smartclass/screens/student_screen/editnote.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'view_note_page.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final supabase = Supabase.instance.client;

  String? imageUrl;

  Future<List<Map<String, dynamic>>> _fetchNotes() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return [];

      final response = await supabase
          .from('notes')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      // ✅ Make sure it's a valid list
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (!mounted) return [];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "⚠️ Failed to load notes: Check your internet connection.",
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      // ✅ Return empty list (not invalid data type)
      return [];
    }
  }

  Future<void> _deleteNote(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text(
              'Confirm Delete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this note?',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Yes, Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    // ✅ User pressed cancel
    if (confirm != true) return;

    // ✅ Delete only if confirmed
    try {
      final fetched = await supabase
          .from('notes')
          .select('image_url')
          .eq('id', id)
          .maybeSingle();

      // 2) Delete image if exists
      if (fetched != null &&
          fetched['image_url'] != null &&
          fetched['image_url'].toString().isNotEmpty) {
        final fileName = fetched['image_url'].split('/').last;
        await supabase.storage.from('notes').remove([fileName]);
      }

      await supabase.from('notes').delete().eq('id', id);

      if (mounted) {
        setState(() {}); // Refresh UI
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
          content: Text("Error deleting note,Check your Internet. $e"),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<T?> pushWithAnimation<T>(BuildContext context, Widget page) {
    return Navigator.push<T?>(
      context,
      PageRouteBuilder<T?>(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: const Cubic(0.22, 0.61, 0.36, 1.0), // smooth custom curve
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

  void _openEditNotePage({Map<String, dynamic>? note}) async {
    final result = await pushWithAnimation<bool?>(
      context,
      EditNotePage(note: note),
    );

    if (result == true) {
      setState(() {}); // refresh notes
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: Text(
          "Notes",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        iconTheme: IconThemeData(
          color: Colors.white, // <-- change back arrow color here
        ),
        backgroundColor: Colors.blue,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchNotes,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchNotes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            }

            final notes = snapshot.data ?? [];

            if (notes.isEmpty) {
              return const Center(child: Text("No notes found. Add some!"));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return Card(
                  color: note['color'] != null
                      ? Color(int.parse(note['color']))
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: InkWell(
                    onTap: () {
                      pushWithAnimation(
                        context,
                        PortraitOnly(child: ViewNotePage(
                          title: note['title'],
                          content: note['content'],
                          imageUrl: note['image_url'],
                          noteId: note['id'],
                          color: note['color'] != null
                              ? Color(int.parse(note['color']))
                              : Colors.white,
                          onEdit: () {
                            Navigator.pop(context); // close detail page
                            _openEditNotePage(note: note);
                          },
                          onDelete: () async {
                            await _deleteNote(note['id']);
                            Navigator.pop(context); // close after delete
                          },
                        ),)
                      );
                    },
                    splashColor: note['color'] != null
                        ? Color(int.parse(note['color'])).withAlpha(128)
                        : Colors.white.withAlpha(128),

                    borderRadius: BorderRadius.circular(16),

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
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _openEditNotePage(),
      ),
    );
  }
}

/* class EditNotePage extends StatefulWidget {
  final Map<String, dynamic>? note;

  const EditNotePage({super.key, this.note});

  @override
  State<EditNotePage> createState() => _EditNotePageState();
}

class _EditNotePageState extends State<EditNotePage> {
  final supabase = Supabase.instance.client;
  late TextEditingController titleController;
  late TextEditingController noteController;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.note?['title'] ?? '');
    noteController = TextEditingController(text: widget.note?['content'] ?? '');
  }

  Future<void> _saveNote() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final title = titleController.text.trim();
    final content = noteController.text.trim();
    

    if (title.isEmpty || content.isEmpty) return;

    if (widget.note == null) {
      // Insert new note
      await supabase.from('notes').insert({
        'user_id': user.id,
        'title': title,
        'content': content,
      });
    } else {
      // Update existing note
      await supabase
          .from('notes')
          .update({'title': title, 'content': content})
          .eq('id', widget.note!['id']);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.blue; // your main color

    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        backgroundColor: themeColor,
        elevation: 0,
        title: const Text("Edit Note", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: themeColor.withOpacity(.15),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // -------- Title field ----------
              const Text(
                "Title",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),

              TextField(
                controller: titleController,
                cursorColor: themeColor,
                decoration: InputDecoration(
                  hintText: "Enter title",
                  filled: true,
                  fillColor: Colors.blue.shade50.withOpacity(.4),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: themeColor.withOpacity(.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: themeColor, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // -------- Note body field ----------
              const Text(
                "Note",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),

              TextField(
                controller: noteController,
                maxLines: 8,
                cursorColor: themeColor,
                decoration: InputDecoration(
                  hintText: "Write your note here...",
                  filled: true,
                  fillColor: Colors.blue.shade50.withOpacity(.4),
                  contentPadding: const EdgeInsets.all(16),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: themeColor.withOpacity(.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: themeColor, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 35),

              // ---------- Save button ----------
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveNote,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                    shadowColor: themeColor.withOpacity(.4),
                  ),
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text(
                    "Save",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
 */
