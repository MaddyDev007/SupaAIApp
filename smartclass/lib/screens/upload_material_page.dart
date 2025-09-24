import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class UploadMaterialPage extends StatefulWidget {
  const UploadMaterialPage({super.key});

  @override
  State<UploadMaterialPage> createState() => _UploadMaterialPageState();
}

class _UploadMaterialPageState extends State<UploadMaterialPage> {
  final supabase = Supabase.instance.client;

  PlatformFile? selectedFile;
  bool uploading = false;
  bool generatingQuiz = false;
  bool generatingExam = false;

  final List<String> _departments = ['CSE', 'EEE', 'ECE', 'Mech'];
  final List<String> _years = ['1st year', '2nd year', '3rd year', '4th year'];

  String? _selectedDept;
  String? _selectedYear;

  final TextEditingController subjectCtrl = TextEditingController();

  String? uploadedMaterialId;
  String? uploadedFileUrl;

  @override
  void dispose() {
    subjectCtrl.dispose();
    super.dispose();
  }

  Future<void> pickPDF() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => selectedFile = result.files.first);
    }
  }

  Future<void> uploadMaterialOnly() async {
    if (selectedFile == null ||
        _selectedDept == null ||
        _selectedYear == null ||
        subjectCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Fill all fields and pick a PDF')),
      );
      return;
    }

    setState(() => uploading = true);
    final filePath =
        '${DateTime.now().millisecondsSinceEpoch}_${selectedFile!.name}';
    final fileTitle = selectedFile!.name.replaceAll('.pdf', '');

    try {
      await supabase.storage
          .from('lessons')
          .uploadBinary(
            filePath,
            selectedFile!.bytes!,
            fileOptions: const FileOptions(contentType: 'application/pdf'),
          );

      final publicUrl = supabase.storage.from('lessons').getPublicUrl(filePath);

      final insertRes = await supabase
          .from('materials')
          .insert({
            'title': fileTitle,
            'file_url': publicUrl,
            'subject': subjectCtrl.text.trim(),
            'department': _selectedDept,
            'year': _selectedYear,
            'teacher_id': supabase.auth.currentUser!.id,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      setState(() {
        uploadedMaterialId = insertRes['id'] as String;
        uploadedFileUrl = publicUrl;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Material uploaded successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Upload Error: $e')));
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> generateExam() async {
    if (uploadedFileUrl == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('⚠️ Upload material first')));
      return;
    }

    setState(() => generatingExam = true);
    try {
      final payload = {
        'pdf_url': uploadedFileUrl,
        'metadata': {
          'material_id': uploadedMaterialId,
          'department': _selectedDept,
          'year': _selectedYear,
          'subject': subjectCtrl.text.trim(),
          'teacher_id': supabase.auth.currentUser!.id,
        },
      };

      final res = await http.post(
        Uri.parse('http://127.0.0.1:8000/question/generate-exam'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (res.statusCode != 200) {
        throw Exception('Backend failed: ${res.statusCode}');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final examPdfUrl = body['file_url'];
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Exam generated! PDF at $examPdfUrl')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Exam Generation Error: $e')));
    } finally {
      if (mounted) setState(() => generatingExam = false);
    }
  }

  Future<void> generateQuiz() async {
    if (uploadedMaterialId == null || uploadedFileUrl == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('⚠️ Upload material first')));
      return;
    }

    setState(() => generatingQuiz = true);
    try {
      final payload = {
        'pdf_url': uploadedFileUrl,
        'metadata': {
          'material_id': uploadedMaterialId,
          'department': _selectedDept,
          'year': _selectedYear,
          'subject': subjectCtrl.text.trim(),
          'teacher_id': supabase.auth.currentUser!.id,
        },
      };

      final uploadRes = await http.post(
        Uri.parse('http://127.0.0.1:8000/upload/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (uploadRes.statusCode != 200) {
        throw Exception('Backend /upload failed: ${uploadRes.statusCode}');
      }

      final body = jsonDecode(uploadRes.body) as Map<String, dynamic>;
      final questions = body['questions'];

      final storePayload = {
        'material_id': uploadedMaterialId,
        'teacher_id': body['metadata']['teacher_id'],
        'department': body['metadata']['department'],
        'year': body['metadata']['year'],
        'subject': body['metadata']['subject'],
        'questions': questions,
        'pdf_url': uploadedFileUrl,
      };

      final storeRes = await http.post(
        Uri.parse('http://127.0.0.1:8000/quiz/store'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(storePayload),
      );

      if (storeRes.statusCode != 200) {
        throw Exception('Backend /quiz/store failed: ${storeRes.statusCode}');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Quiz generated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Quiz Generation Error: $e')));
    } finally {
      if (mounted) setState(() => generatingQuiz = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blue = Colors.blue;

    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text(
          'Upload & Generate',
          style: TextStyle(color: Colors.white , fontWeight: FontWeight.w500),
        ),
        iconTheme: IconThemeData(
          color: Colors.white, // <-- change back arrow color here
        ),
        centerTitle: true,
        backgroundColor: blue,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [blue.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedDept,
                    decoration: InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.blueAccent, // Color when focused
                          width: 2,
                        ),
                      ),
                    ),
                    items: _departments
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedDept = v),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedYear,
                    decoration: InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.blueAccent, // Color when focused
                          width: 2,
                        ),
                      ),
                    ),
                    items: _years
                        .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedYear = v),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: subjectCtrl,
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.blueAccent, // Color when focused
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: pickPDF,
                    icon: const Icon(Icons.attach_file, color: Colors.white),
                    label: const Text('Pick PDF', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      selectedFile?.name ?? 'No file selected',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: uploading ? null : uploadMaterialOnly,
                    icon: const Icon(Icons.upload_file, color: Colors.white),
                    label: Text(uploading ? 'Uploading...' : 'Upload Material',
                        style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: generatingQuiz ? null : generateQuiz,
                    icon: const Icon(Icons.quiz, color: Colors.white),
                    label: Text(
                      generatingQuiz ? 'Generating Quiz...' : 'Generate Quiz',
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: generatingExam ? null : generateExam,
                    icon: const Icon(Icons.description, color: Colors.white),
                    label: Text(
                      generatingExam ? 'Generating Exam...' : 'Generate Exam',
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
