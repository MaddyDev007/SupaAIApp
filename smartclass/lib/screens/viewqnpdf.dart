import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:smartclass/screens/pdf_view_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';

class ViewMaterialsQNPage extends StatefulWidget {
  final String department;
  final String year;

  const ViewMaterialsQNPage({
    super.key,
    required this.department,
    required this.year,
  });

  @override
  State<ViewMaterialsQNPage> createState() => _ViewMaterialsQNPageState();
}

class _ViewMaterialsQNPageState extends State<ViewMaterialsQNPage>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  bool _loading = true;
  String? _errorMessage;
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
    _listAnimation = CurvedAnimation(parent: _listController, curve: Curves.easeOut);

    _searchController.addListener(_onSearchChanged);

    _fetchMaterials();
  }

  @override
  void dispose() {
    _listController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredMaterials = _materials
          .where((mat) =>
              (mat['subject'] ?? '').toString().toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> _fetchMaterials() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _materials = [];
    });

    try {
      final data = await supabase
          .from('questions')
          .select('id, subject, file_url, department, year, created_at')
          .eq('department', widget.department)
          .eq('year', widget.year)
          .order('created_at', ascending: false);

      _materials = (data as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      _filteredMaterials = _materials; // initialize filtered list

      _listController.forward(from: 0); // start animation
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /* Future<void> _openMaterial(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the material.')),
      );
    }
  } */
 Future<void> _openMaterial(String url, String title) async {
  final uri = Uri.tryParse(url);

  if (uri == null) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invalid material link')),
    );
    return;
  }

  // 👇 Open in-app PDF viewer
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PDFViewerPage(
        pdfUrl: url,
        title: title,
      ),
    ),
  );
}

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
            title: Text(title,
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.black87)),
            content: Text(
              message,
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
            ),
            actionsPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            actions: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: confirmColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirmText,
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        )) ??
        false;
  }

  Future<void> _confirmAndDownload(String url, String filename) async {
    final confirm = await _showModernConfirmDialog(
      title: "Download Question Bank",
      message: "Do you want to download this file to your Downloads folder?",
      confirmText: "Download",
    );

    if (confirm) await _downloadMaterial(url, filename);
  }

  Future<void> _downloadMaterial(String url, String filename) async {
  try {
    // 📂 Get the user's Downloads folder
    final downloadsDir = Directory('/storage/emulated/0/Download');

    // Ensure the directory exists
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    String savePath = "${downloadsDir.path}/$filename";

    // 🧠 Auto-rename if file already exists
    int counter = 1;
    while (await File(savePath).exists()) {
      final nameWithoutExt = filename.split('.').first;
      final ext = filename.contains('.') ? '.${filename.split('.').last}' : '';
      savePath = "${downloadsDir.path}/$nameWithoutExt ($counter)$ext";
      counter++;
    }

    // 📥 Download the file
    await Dio().download(url, savePath);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloaded to: $savePath')),
    );

    // 📂 Open after download
    await OpenFilex.open(savePath);
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Download failed: $e')),
    );
  }
}

  Widget _buildMaterialCard(Map<String, dynamic> material, int index) {
    final blue = Colors.blue;
    final subject = material['subject'] ?? 'Untitled';
    final url = material['file_url'] as String;

    final slideTween =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOut));

    return FadeTransition(
      opacity: _listAnimation,
      child: SlideTransition(
        position: _listAnimation.drive(slideTween),
          child: Card(
            color: Colors.white,
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: InkWell(      // Added InkWell for card tap
              onTap: () => _openMaterial(url, subject),
              splashColor: Color.fromARGB(255, 196, 221, 254),
              borderRadius: BorderRadius.circular(12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              title: Text(subject,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text('${material['department']} • ${material['year']}',
                  style: const TextStyle(color: Colors.grey)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _openMaterial(url, subject),
                    borderRadius: BorderRadius.circular(50),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.open_in_new, color: blue),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _confirmAndDownload(url, "$subject.pdf"),
                    borderRadius: BorderRadius.circular(50),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.download, color: blue),
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
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage != null) {
      return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(_errorMessage!,
            style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
      ),
    );
    }

    if (_filteredMaterials.isEmpty) {
      return const Center(
      child: Text(
        'No materials found for your department and year.',
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredMaterials.length,
      itemBuilder: (context, index) =>
          _buildMaterialCard(_filteredMaterials[index], index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blue = Colors.blue;

    return Scaffold(
      backgroundColor: blue.shade50,
      appBar: AppBar(
        title: const Text('Question Bank',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: blue,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by subject name...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey,),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue.shade100),
                ),
                focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue.shade300, width: 1.5),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchMaterials,
              color: blue,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }
}
