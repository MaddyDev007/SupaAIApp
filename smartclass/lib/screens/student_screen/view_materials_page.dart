import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smartclass/screens/common_screen/pdf_view_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smartclass/screens/common_screen/error_page.dart';

class ViewMaterialsPage extends StatefulWidget {
  final String classId; // ✅ NEW

  const ViewMaterialsPage({
    super.key,
    required this.classId,
  });

  @override
  State<ViewMaterialsPage> createState() => _ViewMaterialsPageState();
}

class _ViewMaterialsPageState extends State<ViewMaterialsPage>
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
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _listController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ---------------- SEARCH ----------------
  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredMaterials = _materials
          .where(
            (m) =>
                (m['subject'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(query),
          )
          .toList();
    });
  }

  // ---------------- FETCH MATERIALS (CLASS-BASED) ----------------
  Future<void> _fetchMaterials() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _hasError = false;
      _materials.clear();
      _filteredMaterials.clear();
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      final data = await supabase
          .from('materials')
          .select('id, subject, file_url, created_at')
          .eq('class_id', widget.classId) // ✅ NEW
          .order('created_at', ascending: false)
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () =>
                throw TimeoutException('Materials fetch timed out'),
          );

      final list = (data as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (!mounted) return;

      setState(() {
        _materials = list;
        _filteredMaterials = list;
      });

      _listController.forward(from: 0);
    } on TimeoutException catch (e, st) {
      _setError(e, st);
    } catch (e, st) {
      _setError(e, st);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setError(Object e, StackTrace st) {
    if (!mounted) return;
    setState(() {
      _hasError = true;
      _errorObj = e;
      _errorStack = st;
    });
  }

  // ---------------- OPEN MATERIAL ----------------
  Future<void> _openMaterial(String url, String title) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _snack('Invalid material link');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PDFViewerPage(pdfUrl: url, title: title),
      ),
    );
  }

  Future<void> _openMaterialExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _snack('Invalid URL');
      return;
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      _snack('Could not open the material');
    }
  }

  // ---------------- DOWNLOAD ----------------
  Future<bool> _confirmDownload() async {
    return (await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text("Download Material"),
            content: const Text(
              "Do you want to download this file to your Downloads folder?",
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Download"),
              ),
            ],
          ),
        )) ??
        false;
  }

  Future<void> _downloadMaterial(String url, String filename) async {
    final confirm = await _confirmDownload();
    if (!confirm) return;

    final progress = ValueNotifier<double?>(0);
    final cancelToken = CancelToken();

    Future<void> showProgress() async {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text("Downloading…"),
          content: ValueListenableBuilder<double?>(
            valueListenable: progress,
            builder: (_, p, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: p),
                const SizedBox(height: 12),
                Text(
                  p == null ? "Starting…" : "${(p * 100).toInt()}%",
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => cancelToken.cancel(),
              child: const Text("Cancel"),
            ),
          ],
        ),
      );
    }

    try {
      final dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) await dir.create(recursive: true);

      String savePath = "${dir.path}/$filename";
      int i = 1;

      while (await File(savePath).exists()) {
        savePath = "${dir.path}/$filename ($i).pdf";
        i++;
      }

      progress.value = 0;
      showProgress();

      await Dio().download(
        url,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (r, t) {
          progress.value = t <= 0 ? null : r / t;
        },
      );

      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      _snack("Downloaded to $savePath");
      await OpenFilex.open(savePath);
    } catch (e) {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _snack("Download failed");
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ---------------- MATERIAL CARD ----------------
  Widget _buildMaterialCard(Map<String, dynamic> material) {
    final subject = material['subject'] ?? 'Untitled';
    final url = material['file_url'];

    final slideTween = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOut));

    return FadeTransition(
      opacity: _listAnimation,
      child: SlideTransition(
        position: _listAnimation.drive(slideTween),
        child: Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _openMaterial(url, subject),
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  IconButton(
                    icon: const Icon(Icons.open_in_new),
                    onPressed: () => _openMaterialExternal(url),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: () =>
                        _downloadMaterial(url, "$subject.pdf"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- BODY ----------------
  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return SmartClassErrorPage(
        standalone: false,
        type: SmartClassErrorPage.mapToType(_errorObj),
        error: _errorObj,
        stackTrace: _errorStack,
        onRetry: _fetchMaterials,
      );
    }

    if (_filteredMaterials.isEmpty) {
      return SmartClassErrorPage(
        standalone: false,
        type: SmartErrorType.notFound,
        title: "No materials yet",
        message: "Pull to refresh or check back later.",
        onRetry: _fetchMaterials,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredMaterials.length,
      itemBuilder: (_, i) => _buildMaterialCard(_filteredMaterials[i]),
    );
  }

  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Materials"),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMaterials,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: "Search by subject name…",
                  prefixIcon: Icon(Icons.search),
                  filled: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }
}
