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
    if (selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a PDF')),
      );
      return;
    }
    if (_selectedDept == null || _selectedYear == null || subjectCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Department, Year and enter Subject')),
      );
      return;
    }

    setState(() => uploading = true);
    final filePath = '${DateTime.now().millisecondsSinceEpoch}_${selectedFile!.name}';
    final fileTitle = selectedFile!.name.replaceAll('.pdf', '');

    try {
      // 1) Upload file
      await supabase.storage.from('lessons').uploadBinary(
        filePath,
        selectedFile!.bytes!,
        fileOptions: const FileOptions(contentType: 'application/pdf'),
      );
      final publicUrl = supabase.storage.from('lessons').getPublicUrl(filePath);

      // 2) Insert into DB
      final insertRes = await supabase.from('materials').insert({
        'title': fileTitle,
        'file_url': publicUrl,
        'subject': subjectCtrl.text.trim(),
        'department': _selectedDept,
        'year': _selectedYear,
        'teacher_id': supabase.auth.currentUser!.id,
        'created_at': DateTime.now().toIso8601String(),
      }).select('id').single();

      setState(() {
        uploadedMaterialId = insertRes['id'] as String;
        uploadedFileUrl = publicUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Material uploaded successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Upload Error: $e')),
      );
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> generateExam() async {
    if (uploadedFileUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload the material first')),
      );
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
        }
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Exam generated! PDF available at $examPdfUrl')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Exam Generation Error: $e')),
      );
    } finally {
      if (mounted) setState(() => generatingExam = false);
    }
  }

  Future<void> generateQuiz() async {
    if (uploadedMaterialId == null || uploadedFileUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload the material first')),
      );
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
        }
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Quiz generated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Quiz Generation Error: $e')),
      );
    } finally {
      if (mounted) setState(() => generatingQuiz = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload & Generate Quiz/Exam')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedDept,
              decoration: const InputDecoration(labelText: 'Department'),
              items: _departments
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedDept = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedYear,
              decoration: const InputDecoration(labelText: 'Year'),
              items: _years
                  .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedYear = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subjectCtrl,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: pickPDF,
              icon: const Icon(Icons.attach_file),
              label: const Text('Pick PDF'),
            ),
            const SizedBox(height: 10),
            Text(selectedFile?.name ?? 'No file selected'),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: uploading ? null : uploadMaterialOnly,
              icon: const Icon(Icons.upload_file),
              label: uploading
                  ? const Text('Uploading...')
                  : const Text('Upload Material'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: generatingQuiz ? null : generateQuiz,
              icon: const Icon(Icons.quiz),
              label: generatingQuiz
                  ? const Text('Generating Quiz...')
                  : const Text('Generate Quiz'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: generatingExam ? null : generateExam,
              icon: const Icon(Icons.description),
              label: generatingExam
                  ? const Text('Generating Exam...')
                  : const Text('Generate Exam'),
            ),
          ],
        ),
      ),
    );
  }
}
