import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_progress_uploads/supabase_progress_uploads.dart';

class UploadMaterialPage extends StatefulWidget {
  const UploadMaterialPage({super.key});

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

  final List<String> _departments = ['CSE', 'EEE', 'ECE', 'Mech'];
  final List<String> _years = ['1st year', '2nd year', '3rd year', '4th year'];

  String? _selectedDept;
  String? _selectedYear;

  final TextEditingController subjectCtrl = TextEditingController();

  String? uploadedMaterialId;
  String? uploadedFileUrl;

  double uploadProgress = 0; // 0.0 to 100.0

  final ValueNotifier<double> _uploadProgress = ValueNotifier(0); // 0..100

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    subjectCtrl.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<void> pickPDF() async {
    // Allow only PDF files
    final typeGroup = XTypeGroup(label: 'pdf', extensions: ['pdf']);

    // Pick a single file
    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

    if (file != null) {
      setState(() {
        selectedFile = file; // selectedFile is now XFile
      });
    }
  }

  /* Future<void> uploadMaterialOnly() async {
    if (selectedFile == null ||
        _selectedDept == null ||
        _selectedYear == null ||
        subjectCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Fill all fields and pick a PDF'),
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
      uploaded = false; // reset before starting
    });

    final filePath =
        '${DateTime.now().millisecondsSinceEpoch}_${selectedFile!.name}';
    final fileTitle = selectedFile!.name.replaceAll('.pdf', '');
    final bytes = await selectedFile!.readAsBytes();

    try {
      await supabase.storage
          .from('lessons')
          .uploadBinary(
            filePath,
            bytes,
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
        uploaded = true; // ✅ mark as uploaded
        uploading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Material uploaded successfully'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Upload Error: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
 */

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

  Future<void> uploadMaterialOnly() async {
    if (selectedFile == null ||
        _selectedDept == null ||
        _selectedYear == null ||
        subjectCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Fill all fields and pick a PDF'),
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

    final supa = Supabase.instance.client;
    final fileTitle = selectedFile!.name.replaceAll('.pdf', '');

    try {
      // Optionally set a folder here with rootPath:
      final uploadService = SupabaseUploadService(
        supa,
        'lessons',
        // e.g., materials/IT/2025  (folders only; file name is auto)
        rootPath: 'materials/$_selectedDept/$_selectedYear',
      );

      // ⬇️ Correct call: only file + progress callback
      final publicUrl = await uploadService.uploadFile(
        selectedFile!,
        onUploadProgress: (progress) =>
            _uploadProgress.value = progress, // 0..100
      );

      final insertRes = await supa
          .from('materials')
          .insert({
            'title': fileTitle,
            'file_url': publicUrl,
            'subject': subjectCtrl.text.trim(),
            'department': _selectedDept,
            'year': _selectedYear,
            'teacher_id': supa.auth.currentUser!.id,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      if (!mounted) return;
      uploadedMaterialId = insertRes['id'] as String;
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
          content: const Text('✅ Material uploaded successfully'),
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
          content: Text('❌ Upload Error: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> generateExam() async {
    if (uploadedMaterialId == null || uploadedFileUrl == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Upload material first'),
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
          'department': _selectedDept,
          'year': _selectedYear,
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
        throw Exception('Backend failed: ${res.statusCode}');
      }

      // Optional: read response to get exam PDF URL
      // final body = jsonDecode(res.body) as Map<String, dynamic>;
      // final examPdfUrl = body['file_url'] as String?;

      if (!mounted) return;
      setState(() {
        generatingExam = false;
        examGenerated = true; // ✅ only mark true on success
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Exam generated successfully'),
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
          content: Text('❌ Exam Generation Error: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> generateQuiz() async {
    if (uploadedMaterialId == null || uploadedFileUrl == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Upload material first'),
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
      quizGenerated = false; // reset before generating
    });

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
        Uri.parse('https://supaaiapp-1.onrender.com/upload/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (uploadRes.statusCode != 200) {
        throw Exception('Backend /upload failed: ${uploadRes.statusCode}');
      }

      final body = jsonDecode(uploadRes.body) as Map<String, dynamic>;
      final questions = body['questions'];
      final textPreview = body['text_preview'];

      final storePayload = {
        'material_id': uploadedMaterialId,
        'teacher_id': body['metadata']['teacher_id'],
        'department': body['metadata']['department'],
        'year': body['metadata']['year'],
        'subject': body['metadata']['subject'],
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
        throw Exception('Backend /quiz/store failed: ${storeRes.statusCode}');
      }

      if (!mounted) return;
      setState(() {
        generatingQuiz = false;
        quizGenerated = true; // ✅ show “Quiz Generated” & keep disabled
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Quiz generated successfully'),
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
        quizGenerated = false; // allow retry
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Quiz Generation Error: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
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
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
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
            colors: [blue.shade50, blue.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            color: Colors.white,
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
                      floatingLabelStyle: TextStyle(
                        color: Colors
                            .blueAccent, // 👈 Change label text color here
                      ),
                      suffixIconColor: Colors.grey,
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
                      floatingLabelStyle: TextStyle(
                        color: Colors
                            .blueAccent, // 👈 Change label text color here
                      ),
                      suffixIconColor: Colors.grey,
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
                      floatingLabelStyle: TextStyle(
                        color: Colors
                            .blueAccent, // 👈 Change label text color here
                      ),
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
                  ElevatedButton.icon(
                    onPressed: pickPDF,
                    icon: const Icon(Icons.attach_file, color: Colors.white),
                    label: const Text(
                      'Pick PDF',
                      style: TextStyle(color: Colors.white),
                    ),
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
                    onPressed: uploading || uploaded
                        ? null
                        : uploadMaterialOnly,
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
                      backgroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        // Force green even when disabled
                        if (states.contains(WidgetState.disabled)) {
                          return uploaded ? Colors.green : blue;
                        }
                        return uploaded ? Colors.green : blue;
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        return Colors
                            .white; // keep text/icon white when disabled
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
                      backgroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
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
                      backgroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
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
      ),
    );
  }
}
