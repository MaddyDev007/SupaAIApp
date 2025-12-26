import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_progress_uploads/supabase_progress_uploads.dart';

class UploadMaterialPage extends StatefulWidget {
  final String classId; // ✅ NEW: class-based

  const UploadMaterialPage({
    super.key,
    required this.classId,
  });

  @override
  State<UploadMaterialPage> createState() => _UploadMaterialPageState();
}

class _UploadMaterialPageState extends State<UploadMaterialPage> {
  final supabase = Supabase.instance.client;

  XFile? selectedFile;

  bool uploading = false;
  bool generatingQuiz = false;
  bool generatingExam = false;
  bool uploaded = false;
  bool examGenerated = false;
  bool quizGenerated = false;

  final TextEditingController subjectCtrl = TextEditingController();

  String? uploadedMaterialId;
  String? uploadedFileUrl;

  final ValueNotifier<double> _uploadProgress = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    subjectCtrl.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // ---------------- PICK PDF ----------------
  Future<void> pickPDF() async {
    final typeGroup = XTypeGroup(label: 'pdf', extensions: ['pdf']);
    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

    if (file != null) {
      setState(() => selectedFile = file);
    }
  }

  // ---------------- UPLOAD PROGRESS DIALOG ----------------
  Future<void> _showUploadingDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Uploading material...'),
        content: ValueListenableBuilder<double>(
          valueListenable: _uploadProgress,
          builder: (_, p, __) {
            final v = (p.clamp(0, 100)) / 100;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: p == 0 ? null : v),
                const SizedBox(height: 12),
                Text('${p.toStringAsFixed(0)}%'),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------- UPLOAD MATERIAL (CLASS-BASED) ----------------
  Future<void> uploadMaterialOnly() async {
    if (selectedFile == null || subjectCtrl.text.trim().isEmpty) {
      _snack('⚠️ Pick a PDF and enter subject');
      return;
    }

    setState(() {
      uploading = true;
      uploaded = false;
    });

    _uploadProgress.value = 0;
    _showUploadingDialog();

    try {
      final uploadService = SupabaseUploadService(
        supabase,
        'lessons',
        rootPath: 'materials/${widget.classId}', // ✅ class-based folder
      );

      final publicUrl = await uploadService.uploadFile(
        selectedFile!,
        onUploadProgress: (p) => _uploadProgress.value = p,
      );

      final res = await supabase
          .from('materials')
          .insert({
            'title': selectedFile!.name.replaceAll('.pdf', ''),
            'file_url': publicUrl,
            'subject': subjectCtrl.text.trim(),
            'class_id': widget.classId, // ✅ NEW
            'uploaded_by': supabase.auth.currentUser!.id,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      uploadedMaterialId = res['id'];
      uploadedFileUrl = publicUrl;

      setState(() {
        uploading = false;
        uploaded = true;
      });

      Navigator.of(context, rootNavigator: true).pop();
      _snack('✅ Material uploaded successfully');
    } catch (e) {
      uploading = false;
      Navigator.of(context, rootNavigator: true).pop();
      _snack('❌ Upload failed: $e');
    }
  }

  // ---------------- GENERATE QUIZ ----------------
  Future<void> generateQuiz() async {
    if (uploadedMaterialId == null || uploadedFileUrl == null) {
      _snack('⚠️ Upload material first');
      return;
    }

    setState(() {
      generatingQuiz = true;
      quizGenerated = false;
    });

    try {
      final payload = {
        'pdf_url': uploadedFileUrl,
        'metadata': {
          'material_id': uploadedMaterialId,
          'class_id': widget.classId, // ✅ NEW
          'subject': subjectCtrl.text.trim(),
          'teacher_id': supabase.auth.currentUser!.id,
        },
      };

      final res = await http.post(
       // Uri.parse('http://127.0.0.1:8000/upload/'),
         Uri.parse('https://supaaiapp-1.onrender.com/upload/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (res.statusCode != 200) {
        throw 'Quiz generation failed';
      }

      setState(() {
        generatingQuiz = false;
        quizGenerated = true;
      });

      _snack('✅ Quiz generated successfully');
    } catch (e) {
      generatingQuiz = false;
      _snack('❌ Quiz generation failed: $e');
    }
  }

  // ---------------- GENERATE EXAM ----------------
  Future<void> generateExam() async {
    if (uploadedMaterialId == null || uploadedFileUrl == null) {
      _snack('⚠️ Upload material first');
      return;
    }

    setState(() {
      generatingExam = true;
      examGenerated = false;
    });

    try {
      final payload = {
        'pdf_url': uploadedFileUrl,
        'metadata': {
          'material_id': uploadedMaterialId,
          'class_id': widget.classId, // ✅ NEW
          'subject': subjectCtrl.text.trim(),
          'teacher_id': supabase.auth.currentUser!.id,
        },
      };

      final res = await http.post(
        // Uri.parse('http://127.0.0.1:8000/question/generate-exam'),
         Uri.parse(
             'https://supaaiapp-1.onrender.com/question/generate-exam'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (res.statusCode != 200) {
        throw 'Exam generation failed';
      }

      setState(() {
        generatingExam = false;
        examGenerated = true;
      });

      _snack('✅ Exam generated successfully');
    } catch (e) {
      generatingExam = false;
      _snack('❌ Exam generation failed: $e');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ---------------- UI (UNCHANGED) ----------------
  @override
  Widget build(BuildContext context) {
    final blue = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload & Generate'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          elevation: 6,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: subjectCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Subject'),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: pickPDF,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Pick PDF'),
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
                  onPressed: uploading || uploaded ? null : uploadMaterialOnly,
                  icon: Icon(uploaded
                      ? Icons.check_circle
                      : Icons.upload_file),
                  label: Text(uploaded ? 'Uploaded' : 'Upload Material'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: uploaded ? Colors.green : blue,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed:
                      generatingQuiz || quizGenerated ? null : generateQuiz,
                  icon: Icon(quizGenerated
                      ? Icons.check_circle
                      : Icons.quiz),
                  label: Text(
                      quizGenerated ? 'Quiz Generated' : 'Generate Quiz'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: quizGenerated ? Colors.green : blue,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed:
                      generatingExam || examGenerated ? null : generateExam,
                  icon: Icon(examGenerated
                      ? Icons.check_circle
                      : Icons.description),
                  label: Text(
                      examGenerated ? 'Exam Generated' : 'Generate Exam'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: examGenerated ? Colors.green : blue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
