import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'view_note_page.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _fetchNotes() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final response = await supabase
        .from('notes')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _deleteNote(int id) async {
    await supabase.from('notes').delete().eq('id', id);
    setState(() {}); // refresh UI
  }

  void _openEditNotePage({Map<String, dynamic>? note}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditNotePage(note: note)),
    );

    if (result == true) {
      setState(() {}); // refresh notes after saving
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: Text("Notes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        iconTheme: IconThemeData(
          color: Colors.white, // <-- change back arrow color here
        ),
        backgroundColor: Colors.blue,
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
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
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
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
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_red_eye, color: Color.fromARGB(255, 102, 224, 224),),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ViewNotePage(
                                    title: note['title'],
                                    content: note['content'],
                                    noteId: note['id'],
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
                            icon: const Icon(Icons.edit, color: Colors.blueAccent,),
                            onPressed: () {
                              _openEditNotePage(note: note);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent,),
                            onPressed: () => _deleteNote(note['id']),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _openEditNotePage(),
      ),
    );
  }
}

class EditNotePage extends StatefulWidget {
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
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text("Edit Note", style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: "Title",
                hintText: "Enter title",
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: "Note",
                hintText: "Enter note",
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: _saveNote,
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
