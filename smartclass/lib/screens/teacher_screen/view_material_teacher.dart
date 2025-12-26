import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:smartclass/screens/common_screen/error_page.dart';
import 'package:smartclass/screens/common_screen/pdf_view_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:url_launcher/url_launcher.dart';

class ViewMaterialsTeacherPage extends StatefulWidget {
  final String classId;
  const ViewMaterialsTeacherPage({super.key, required this.classId});

  @override
  State<ViewMaterialsTeacherPage> createState() =>
      _ViewMaterialsTeacherPageState();
}

class _ViewMaterialsTeacherPageState extends State<ViewMaterialsTeacherPage>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  bool _loading = true;
  bool _hasError = false;
  Object? _errorObj;
  StackTrace? _errorStack;
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _filteredMaterials = [];

  final TextEditingController _searchController = TextEditingController();


  late final AnimationController _listController;
  late final Animation<double> _listAnimation;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _listAnimation = CurvedAnimation(
      parent: _listController,
      curve: Curves.easeOut,
    );
    _fetchMaterials();
    _searchController.addListener(_applySearch);
  }

  @override
  void dispose() {
    _listController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _applySearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredMaterials = _materials
          .where((m) =>
              (m['subject'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(query))
          .toList();
    });
  }

  Future<void> _openMaterialExternal(String url) async {
    final uri = Uri.tryParse(url);

    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid URL.')));
      return;
    }

    // Try to launch externally (browser, PDF viewer, etc.)
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the material.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening material: $e')));
      }
    }
  }

  Future<void> _openMaterial(String url, String title) async {
    final uri = Uri.tryParse(url);

    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
           backgroundColor: Theme.of(context).cardColor,
          content: Text('Invalid material link',style: TextStyle(color: Theme.of(context).highlightColor)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // 👇 Open in-app PDF viewer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PDFViewerPage(pdfUrl: url, title: title),
      ),
    );
  }

  Future<void> _fetchMaterials() async {
    setState(() {
      _loading = true;

      _hasError = false;
      _errorObj = null;
      _errorStack = null;
      _materials = [];
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("Not logged in");

      final data = await supabase
          .from('materials')
          .select('id, subject, file_url, created_at')
          .eq('class_id', widget.classId) // ✅ KEY CHANGE
          .eq('uploaded_by', user.id)     // ✅ only creator
          .order('created_at', ascending: false)
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () =>
                throw TimeoutException('Materials fetch timed out'),
          );


      _materials = List<Map<String, dynamic>>.from(data);
      _filteredMaterials = _materials;

      _listController.forward(from: 0);
    } on TimeoutException catch (e, st) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorObj = e;
        _errorStack = st;
      });
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorObj = e;
        _errorStack = st;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Modern confirmation dialog widget
  Future<bool> _showModernConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    Color confirmColor = Colors.blue,
  }) async {
    final theme = Theme.of(context);
    return (await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              title,
              style: theme.textTheme.titleLarge
            ),
            content: Text(
              message,

            ),
            actionsPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            actions: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.transparent),
                ),
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  confirmText,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        )) ??
        false;
  }

  /// 🗑️ Delete Material
  Future<void> _deleteMaterial(String url, String id) async {
    final confirm = await _showModernConfirmDialog(
      title: "Delete Material",
      message:
          "Are you sure you want to delete this material?\n\n⚠️ All generated questions and files will also be deleted.",
      confirmText: "Delete",
      confirmColor: Colors.red,
    );

    if (!confirm) return;

    try {
      // 1️⃣ Delete Material File From "lessons" Bucket
      final materialFilePath = url.split('/lessons/').last;
      await supabase.storage.from('lessons').remove([materialFilePath]);

      // 2️⃣ Fetch All Questions Linked to This Material
      final questions = await supabase
          .from('questions')
          .select('file_url')
          .eq('material_id', id);

      // 3️⃣ Delete Each Question FILE From "questions" Bucket
      for (final q in questions) {
        final file = q['file_url'];
        if (file != null && file.toString().isNotEmpty) {
          final name = file.split('/questions/').last;
          await supabase.storage.from('questions').remove([name]);
        }
      }

      // 4️⃣ Delete Question Rows From DB
      await supabase.from('questions').delete().eq('material_id', id);

      // 5️⃣ Delete Material Row From DB
      await supabase.from('materials').delete().eq('id', id);

      // 6️⃣ Update UI
      if (mounted) {
        setState(() {
          _materials.removeWhere((mat) => mat['id'] == id);
          _filteredMaterials.removeWhere((mat) => mat['id'] == id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
             backgroundColor: Theme.of(context).cardColor,
            content: Text("Material & Questions deleted successfully.",style: TextStyle(color: Theme.of(context).highlightColor)),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
           backgroundColor: Theme.of(context).cardColor,
          content: Text("Error deleting material: $e",style: TextStyle(color: Theme.of(context).highlightColor)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  /// ⬇️ Download Material with confirmation
  Future<void> _confirmAndDownload(String url, String filename) async {
    final confirm = await _showModernConfirmDialog(
      title: "Download Material",
      message:
          "Do you want to download this material to your Downloads folder?",
      confirmText: "Download",
    );

    if (confirm) await _downloadMaterial(url, filename);
  }

   Future<void> _downloadMaterial(String url, String filename) async {
    final progress = ValueNotifier<double?>(
      0.0,
    ); // 0..1, or null = indeterminate
    final cancelToken = CancelToken();

    Future<void> showProgressDialog() async {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Downloading…'),
            content: ValueListenableBuilder<double?>(
              valueListenable: progress,
              builder: (_, p, __) {
                final v = p; // CircularProgressIndicator takes 0..1 or null
                final pct = p == null
                    ? null
                    : ((p * 100).clamp(0, 100)).toStringAsFixed(0);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LinearProgressIndicator(
                      value: v,
                      color: Theme.of(context).primaryColor,
                      backgroundColor: Colors.blue.shade100,
                    ),
                    const SizedBox(height: 12),
                    Text(pct == null ? 'Starting…' : '$pct%'),
                  ],
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  cancelToken.cancel('Cancelled by user');
                },
                child:  Text(
                  'Cancel',
                  style: TextStyle(color: Theme.of(context).primaryColor),
                ),
              ),
            ],
          ),
        ),
      );
    }

    try {
      // 📂 Prepare save path
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      String savePath = "${downloadsDir.path}/$filename";

      // 🧠 Auto-rename if file exists
      int counter = 1;
      while (await File(savePath).exists()) {
        final nameWithoutExt = filename.contains('.')
            ? filename.substring(0, filename.lastIndexOf('.'))
            : filename;
        final ext = filename.contains('.')
            ? filename.substring(filename.lastIndexOf('.'))
            : '';
        savePath = "${downloadsDir.path}/$nameWithoutExt ($counter)$ext";
        counter++;
      }

      // 🚀 Show dialog
      progress.value = 0.0;
      showProgressDialog();

      // 📥 Download with progress + cancel support
      await Dio().download(
        url,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total <= 0) {
            // unknown total size -> indeterminate spinner
            progress.value = null;
          } else {
            progress.value = received / total;
          }
        },
      );

      // ✅ Close dialog
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
           backgroundColor: Theme.of(context).cardColor,
          content: Text('✅ Downloaded to: $savePath',style: TextStyle(color: Theme.of(context).highlightColor)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      // 📂 Open file
      await OpenFilex.open(savePath);
    } on DioException catch (e) {
      // close dialog if open
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!mounted) return;

      if (CancelToken.isCancel(e)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).cardColor,
            content: Text('⛔ Download cancelled',style: TextStyle(color: Theme.of(context).highlightColor),),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).cardColor,
            content: Text('❌ Download failed: ${e.message}',style: TextStyle(color: Theme.of(context).highlightColor)),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
           backgroundColor: Theme.of(context).cardColor,
          content: Text('❌ Download failed: $e',style: TextStyle(color: Theme.of(context).highlightColor)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
 
  
  
  Widget _buildMaterialCard(Map<String, dynamic> material, int index) {

    final subject = material['subject'] ?? 'Untitled';
    final url = material['file_url'] as String;
    final id = material['id'] as String;

    final slideTween = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOut));

    return FadeTransition(
      opacity: _listAnimation,
      child: SlideTransition(
        position: _listAnimation.drive(slideTween),
        child: Card(
          color: Theme.of(context).cardColor,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: InkWell(
            // Added InkWell for card tap
            onTap: () => _openMaterial(url, subject),
            splashColor: Color.fromARGB(255, 196, 221, 254),
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              title: Text(
                subject,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _openMaterialExternal(url),
                    borderRadius: BorderRadius.circular(50),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.open_in_new, color:Theme.of(context).primaryColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _confirmAndDownload(url, "$subject.pdf"),
                    borderRadius: BorderRadius.circular(50),
                    child:Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.download, color:Theme.of(context).primaryColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _deleteMaterial(url, id),
                    borderRadius: BorderRadius.circular(50),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.delete, color: Colors.red),
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

  Widget _buildContent() {
    // Always return a scrollable so RefreshIndicator works
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children:  [
          SizedBox(height: 160),
          Center(child: CircularProgressIndicator(
            color: Theme.of(context).primaryColor,
          )),
          SizedBox(height: 300),
        ],
      );
    }

    if (_hasError) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // const SizedBox(height: 80),
          SmartClassErrorPage(
            standalone: false,
            type: SmartClassErrorPage.mapToType(_errorObj),
            error: _errorObj,
            stackTrace: _errorStack,
            onRetry: _fetchMaterials,
          ),
          // const SizedBox(height: 300),
        ],
      );
    }

    if (_filteredMaterials.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // SizedBox(height: 120),
          // Use your SmartClass not-found preset
          SmartClassErrorPage(
            standalone: false,
            type: SmartErrorType.notFound,
            title: 'No materials yet',
            message: 'Try a different search or pull to refresh.',
            onRetry: _fetchMaterials,
          ),
          // const SizedBox(height: 300),
        ],
      );
    }

    // Data list
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _filteredMaterials.length,
      itemBuilder: (context, index) =>
          _buildMaterialCard(_filteredMaterials[index], index),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'My Uploaded Materials',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
        child: RefreshIndicator(
          onRefresh: _fetchMaterials,
          color: Theme.of(context).primaryColor,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search materials by name...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

}
