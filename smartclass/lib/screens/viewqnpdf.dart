//import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class ViewMaterialsQNPage extends StatefulWidget {
  final String department;
  final String year;

  const ViewMaterialsQNPage({
    super.key,
    required this.department,
    required this.year,
  });

  @override
  State<ViewMaterialsQNPage> createState() => _ViewMaterialsPageState();
}

class _ViewMaterialsPageState extends State<ViewMaterialsQNPage> {
  final supabase = Supabase.instance.client;

  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _materials = [];

  @override
  void initState() {
    super.initState();
    _fetchMaterials();
  }

  Future<void> _fetchMaterials() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
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
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openMaterial(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the material.')),
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

      // Open file after download
      await OpenFile.open(savePath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
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
          'No materials found for your department and year.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      itemCount: _materials.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final material = _materials[index];
        final subject = material['subject'] ?? 'Untitled';
        final url = material['file_url'] as String;

        return ListTile(
          title: Text(subject),
          subtitle: Text('${material['department']} • ${material['year']}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.open_in_new),
                onPressed: () => _openMaterial(url),
              ),
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () => _downloadMaterial(url, "$subject.pdf"),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Materials')),
      body: RefreshIndicator(
        onRefresh: _fetchMaterials,
        child: _buildContent(),
      ),
    );
  }
}
