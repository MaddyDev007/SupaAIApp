// import 'dart:io';
import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // ✅ Speech-to-text controller
  /* late stt.SpeechToText speech;
  bool isListening = false;

  // ✅ Image picker
  final ImagePicker picker = ImagePicker();
  String? imageUrl; */

  // ✅ Color picker palette
  final List<Color> palette = [
    const Color(0xFFFFF9C4), // Yellow
    const Color(0xFFBBDEFB), // Blue
    const Color(0xFFC8E6C9), // Green
    const Color(0xFFFFCDD2), // Red
    const Color(0xFFE1BEE7), // Purple
    Colors.white,
  ];

  late Color selectedColor;

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(text: widget.note?['title'] ?? '');
    noteController = TextEditingController(text: widget.note?['content'] ?? '');

    // ✅ Initialize color
    final savedColor = widget.note?['color'];
    selectedColor = savedColor != null
        ? Color(int.parse(savedColor))
        : Colors.white;

    // ✅ Initialize saved image
    /* imageUrl = widget.note?['image_url'];

    // ✅ Init speech
    speech = stt.SpeechToText(); */
  }

  /* // ✅ Upload image to Supabase Storage
  Future<void> pickImage() async {
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);

    if (file == null) return;

    final bytes = await File(file.path).readAsBytes();
    final filename = "note_${DateTime.now().millisecondsSinceEpoch}.jpg";

    await supabase.storage.from('notes').uploadBinary(filename, bytes);

    final publicUrl = supabase.storage.from('notes').getPublicUrl(filename);

    setState(() => imageUrl = publicUrl);
  }

  // ✅ Start listening
  Future<void> startListening() async {
    bool available = await speech.initialize();
    if (available) {
      setState(() => isListening = true);
      speech.listen(
        onResult: (result) {
          setState(() {
            noteController.text = result.recognizedWords;
          });
        },
      );
    }
  }

  // ✅ Stop listening
  void stopListening() {
    speech.stop();
    setState(() => isListening = false);
  } */

  Future<void> _saveNote() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final title = titleController.text.trim();
      final content = noteController.text.trim();

      if (title.isEmpty || content.isEmpty) return;

      final colorValue = selectedColor.value.toString();
     
      if (widget.note == null) {
        await supabase.from('notes').insert({
          'user_id': user.id,
          'title': title,
          'content': content,
          'color': colorValue,
          // 'image_url': imageUrl,
        });
      } else {
        await supabase
            .from('notes')
            .update({
              'title': title,
              'content': content,
              'color': colorValue,
              // 'image_url': imageUrl,
            })
            .eq('id', widget.note!['id']);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save note: Check your Internet.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.blue;

    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        backgroundColor: themeColor,
        title: const Text("Edit Note", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        /* actions: [
          IconButton(icon: const Icon(Icons.image), onPressed: pickImage),
          IconButton(
            icon: Icon(isListening ? Icons.mic : Icons.mic_none),
            onPressed: isListening ? stopListening : startListening,
          ),
        ], */
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ✅ Color Picker
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: palette.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, index) {
                  final color = palette[index];
                  final isSelected = selectedColor == color;

                  return GestureDetector(
                    onTap: () => setState(() => selectedColor = color),
                    child: Container(
                      width: 35,
                      height: 35,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? const Color.fromARGB(148, 0, 0, 0)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // ✅ Image preview
            /* if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(imageUrl!, height: 180, fit: BoxFit.cover),
              ), */
            const SizedBox(height: 20),

            // ✅ White container with shadow
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: selectedColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 12,
                    color: Colors.black12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Title",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),

                  TextField(
                    controller: titleController,
                    cursorColor: themeColor,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.blue[50],
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.blue.shade100,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.blue.shade300, // Color when focused
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Note",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),

                  TextField(
                    controller: noteController,
                    maxLines: 8,
                    cursorColor: themeColor,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.blue[50],
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.blue.shade100,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.blue.shade300, // Color when focused
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ✅ Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveNote,
                icon: const Icon(Icons.check, color: Colors.white, size: 20),
                label: const Text(
                  "Save",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
