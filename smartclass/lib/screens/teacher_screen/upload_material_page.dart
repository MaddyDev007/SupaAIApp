import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_progress_uploads/supabase_progress_uploads.dart';

class UploadMaterialPage extends StatefulWidget {
  final String classId; // ✅ NEW: class-based

  const UploadMaterialPage({super.key, required this.classId});

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
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(value: p == 0 ? null : v),
                  const SizedBox(height: 12),
                  Text('${p.toStringAsFixed(0)}%'),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------- UPLOAD MATERIAL (CLASS-BASED) ----------------
  Future<void> uploadMaterialOnly() async {
    if (selectedFile == null || subjectCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).cardColor,
          content: Text(
            '⚠️ Fill Title and pick a PDF',
            style: TextStyle(color: Theme.of(context).highlightColor),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
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

      if (!mounted) return;
      uploadedMaterialId = res['id'];
      uploadedFileUrl = publicUrl;

      setState(() {
        uploaded = true;
        uploading = false;
      });
      _uploadProgress.value = 100;

      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).cardColor,
          content: Text(
            '✅ Material uploaded successfully',
            style: TextStyle(color: Theme.of(context).highlightColor),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => uploading = false);
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).cardColor,
          content: Text(
            '❌ Upload Error: $e',
            style: TextStyle(color: Theme.of(context).highlightColor),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // ---------------- GENERATE QUIZ ----------------
  Future<void> generateQuiz() async {
    if (uploadedMaterialId == null || uploadedFileUrl == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).cardColor,
          content: Text(
            '⚠️ Upload material first',
            style: TextStyle(color: Theme.of(context).highlightColor),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() {
      generatingQuiz = true;
      quizGenerated = false;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception("User not authenticated");
      }

      // ---------------- PAYLOAD FOR /upload ----------------
      final uploadPayload = {
        'pdf_url': uploadedFileUrl,
        'metadata': {
          'material_id': uploadedMaterialId,
          'class_id': widget.classId, // ✅ IMPORTANT
          'subject': subjectCtrl.text.trim(),
          'teacher_id': user.id,
        },
      };

      final uploadRes = await http.post(
        Uri.parse('https://supaaiapp-1.onrender.com/upload/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(uploadPayload),
      );

      if (uploadRes.statusCode != 200) {
        throw Exception('Backend /upload failed (${uploadRes.statusCode})');
      }

      final uploadBody = jsonDecode(uploadRes.body) as Map<String, dynamic>;
      final questions = uploadBody['questions'];
      final textPreview = uploadBody['text_preview'];

      // ---------------- PAYLOAD FOR /quiz/store ----------------
      final storePayload = {
        'material_id': uploadedMaterialId,
        'class_id': widget.classId, // ✅ IMPORTANT
        'teacher_id': user.id,
        'subject': subjectCtrl.text.trim(),
        'questions': questions,
        'pdf_url': uploadedFileUrl,
        'text_preview': textPreview,
      };

      final storeRes = await http.post(
        Uri.parse('https://supaaiapp-1.onrender.com/quiz/store'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(storePayload),
      );

      if (storeRes.statusCode != 200) {
        throw Exception('Backend /quiz/store failed (${storeRes.statusCode})');
      }

      if (!mounted) return;
      setState(() {
        generatingQuiz = false;
        quizGenerated = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).cardColor,
          content: Text(
            '✅ Quiz generated successfully',
            style: TextStyle(color: Theme.of(context).highlightColor),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        generatingQuiz = false;
        quizGenerated = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).cardColor,
          content: Text(
            '❌ Quiz Generation Error: $e',
            style: TextStyle(color: Theme.of(context).highlightColor),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // ---------------- GENERATE EXAM ----------------
  Future<void> generateExam() async {
    if (uploadedMaterialId == null || uploadedFileUrl == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).cardColor,
          content: Text(
            '⚠️ Upload material first',
            style: TextStyle(color: Theme.of(context).highlightColor),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() {
      generatingExam = true;
      examGenerated = false; // reset before generation
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
        Uri.parse('https://supaaiapp-1.onrender.com/question/generate-exam'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (res.statusCode != 200) {
        throw 'Exam generation failed';
      }

      if (!mounted) return;
      setState(() {
        generatingExam = false;
        examGenerated = true; // ✅ only mark true on success
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).cardColor,
          content: Text(
            '✅ Exam generated successfully',
            style: TextStyle(color: Theme.of(context).highlightColor),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        generatingExam = false;
        examGenerated = false; // keep disabled state OFF on error
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).cardColor,
          content: Text(
            '❌ Exam Generation Error: $e',
            style: TextStyle(color: Theme.of(context).highlightColor),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // ---------------- UI (UNCHANGED) ----------------
  @override
  Widget build(BuildContext context) {
    final blue = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Upload & Generate',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        iconTheme: IconThemeData(
          color: Colors.white, // <-- change back arrow color here
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Theme.of(context).cardColor,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: pickPDF,
                  icon: const Icon(Icons.attach_file),
                  label: const Text(
                    'Pick PDF',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
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
                  onPressed: uploading || uploaded ? null : uploadMaterialOnly,
                  icon: Icon(
                    uploading
                        ? Icons.hourglass_empty
                        : uploaded
                        ? Icons.check_circle
                        : Icons.upload_file_rounded,
                    color: Colors.white,
                  ),
                  label: Text(
                    uploading
                        ? 'Uploading...'
                        : uploaded
                        ? 'Uploaded'
                        : 'Upload Material',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      // Force green even when disabled
                      if (states.contains(WidgetState.disabled)) {
                        return uploaded ? Colors.green : blue;
                      }
                      return uploaded ? Colors.green : blue;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      return Colors.white; // keep text/icon white when disabled
                    }),
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(vertical: 14),
                    ),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: generatingQuiz || quizGenerated
                      ? null
                      : generateQuiz,
                  icon: generatingQuiz
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          quizGenerated ? Icons.check_circle : Icons.quiz,
                          color: Colors.white,
                        ),
                  label: Text(
                    generatingQuiz
                        ? 'Generating Quiz...'
                        : quizGenerated
                        ? 'Quiz Generated'
                        : 'Generate Quiz',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.disabled)) {
                        return quizGenerated ? Colors.green : blue;
                      }
                      return quizGenerated ? Colors.green : blue;
                    }),
                    foregroundColor: WidgetStateProperty.all(Colors.white),
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(vertical: 14),
                    ),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: generatingExam || examGenerated
                      ? null
                      : generateExam,
                  icon: generatingExam
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          examGenerated
                              ? Icons.check_circle
                              : Icons.description,
                          color: Colors.white,
                        ),
                  label: Text(
                    generatingExam
                        ? 'Generating Exam...'
                        : examGenerated
                        ? 'Exam Generated'
                        : 'Generate Exam',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.disabled)) {
                        // when button is disabled
                        return examGenerated ? Colors.green : blue;
                      }
                      // when button is enabled
                      return examGenerated ? Colors.green : blue;
                    }),
                    foregroundColor: WidgetStateProperty.all(Colors.white),
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(vertical: 14),
                    ),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
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
