import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class ViewQNBankTeacherPage extends StatefulWidget {
  const ViewQNBankTeacherPage({super.key});

  @override
  State<ViewQNBankTeacherPage> createState() => _ViewQNBankTeacherPageState();
}

class _ViewQNBankTeacherPageState extends State<ViewQNBankTeacherPage>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _materials = [];

  late final AnimationController _listController;
  late final Animation<double> _listAnimation;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _listAnimation =
        CurvedAnimation(parent: _listController, curve: Curves.easeOut);
    _fetchMaterials();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<void> _fetchMaterials() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _materials = [];
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception("Not logged in");
      }

      // 👇 Fetch only the question banks uploaded by this teacher
      final data = await supabase
          .from('questions')
          .select('id, subject, file_url, department, year, created_at')
          .eq('teacher_id', user.id) // must have this column in "questions" table
          .order('created_at', ascending: false);

      _materials = (data as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      _listController.forward(from: 0);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openMaterial(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the file.')),
      );
    }
  }

  Future<void> _downloadMaterial(String url, String filename) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = "${dir.path}/$filename";

      await Dio().download(url, savePath);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded to $savePath')),
      );

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
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            title: Text(
              subject,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              '${material['department']} • ${material['year']}',
              style: const TextStyle(color: Colors.grey),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _openMaterial(url),
                  borderRadius: BorderRadius.circular(50),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.open_in_new, color: blue),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _downloadMaterial(url, "$subject.pdf"),
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
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_materials.isEmpty) {
      return const Center(
        child: Text(
          'You have not uploaded any question banks yet.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _materials.length,
      itemBuilder: (context, index) =>
          _buildMaterialCard(_materials[index], index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blue = Colors.blue;

    return Scaffold(
      backgroundColor: blue.shade50,
      appBar: AppBar(
        title: const Text('My Uploaded QN Banks',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
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
        child: RefreshIndicator(
          onRefresh: _fetchMaterials,
          color: blue,
          child: _buildContent(),
        ),
      ),
    );
  }
}
