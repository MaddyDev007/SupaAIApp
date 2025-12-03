import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SemResultPage extends StatefulWidget {
  final Map<String, dynamic> profile;
  const SemResultPage({super.key, required this.profile});
  @override
  State<SemResultPage> createState() => _SemResultPageState();
}

class _SemResultPageState extends State<SemResultPage> {
  final _reg = TextEditingController();
  final _dob = TextEditingController();
  final _search = TextEditingController();

  bool _showSearch = false;
  bool _asc = true;
  bool _loading = false;

  String _key = "Semester";
  String _query = "";
  Map<String, dynamic>? result;

  @override
  void initState() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.initState();
    _reg.text = widget.profile["reg_no"];
  }
  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _reg.dispose();
    _dob.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> fetchResult() async {
    if (_reg.text.isEmpty || _dob.text.isEmpty) {
      return _err("Fill inputs", "Please fill all fields.");
    }

    setState(() => _loading = true);

    try {
      final r = await http.post(
        Uri.parse("https://supaaiapp-1.onrender.com/results/getResult"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "register_number": _reg.text.trim(),
          "dob": _dob.text.trim().replaceAll("/", "-"),
        }),
      );

      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        final subs = data["subjects"] as List?;

        if (subs == null || subs.isEmpty) {
          _err("No Result Found", "No results found.");
        } else {
          setState(() {
            result = data;
            _query = "";
            _search.clear();
          });
        }
      } else {
        _err("No Result Found", "Invalid Register No or DOB.");
      }
    } catch (_) {
      _err("Network Error", "Please check your Internet.");
    }

    if (mounted) setState(() => _loading = false);
  }

  void _err(String t, String m) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(m),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  List _filterSort(List subs) {
    final q = _query;
    final f = subs.where((s) {
      final n = s["course_name"].toString().toLowerCase();
      final c = s["code"].toString().toLowerCase();
      return q.isEmpty || n.contains(q) || c.contains(q);
    }).toList();

    int toInt(v) {
      final x = v.toString().replaceAll(RegExp(r'[^0-9]'), "");
      return int.tryParse(x) ?? 0;
    }

    int gp(v) => double.tryParse(v.toString())?.round() ?? 0;

    f.sort((a, b) {
      final cmp = _key == "Grade"
          ? gp(a["grade_point"]).compareTo(gp(b["grade_point"]))
          : toInt(a["semester"]).compareTo(toInt(b["semester"]));
      return _asc ? cmp : -cmp;
    });

    return f;
  }

  Widget _txt(String t, TextEditingController c) => TextField(
    controller: c,
    cursorColor: Colors.blue,
    decoration: InputDecoration(
      filled: true,
      fillColor: Colors.white,
      labelText: t,
      floatingLabelStyle: const TextStyle(color: Colors.blueAccent),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade100, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade300, width: 2),
      ),
    ),
  );

  Future<Uint8List> _buildPdf(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    final subs = _filterSort(data["subjects"]);

    pw.Widget table = pw.TableHelper.fromTextArray(
      headers: const ["Sem", "Course", "Code", "Cr", "Grade", "GP", "Result"],
      data: subs.map((s) {
        return [
          s["semester"].toString(),
          s["course_name"],
          s["code"],
          s["credits"].toString(),
          s["grade"],
          s["grade_point"].toString(),
          s["result"],
        ];
      }).toList(),
      cellStyle: const pw.TextStyle(fontSize: 10),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFE0E0E0),
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Text(
            "TEC Semester Result",
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Text("Register Number: ${data["register_number"]}"),
          pw.Text("Name: ${data["name"]}"),
          pw.Text("Degree: ${data["degree"]}"),
          pw.Text("Exam Month: ${data["exam_month"]}"),
          pw.SizedBox(height: 20),
          pw.Text(
            "Subjects",
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          table,
        ],
      ),
    );

    return pdf.save();
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
            title: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            content: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
              ),
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
                style: FilledButton.styleFrom(
                  backgroundColor: confirmColor,
                ),
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

  Future<void> _confirmAndDownload(data) async {
    final confirm = await _showModernConfirmDialog(
      title: "Download Question Bank",
      message: "Do you want to download this file to your Downloads folder?",
      confirmText: "Download",
    );

    if (confirm) await _download(data);
  }

  Future<void> _download(Map<String, dynamic> data) async {
    try {
      final bytes = await _buildPdf(data);
      final dir = Directory("/storage/emulated/0/Download");
      if (!await dir.exists()) await dir.create(recursive: true);

      String file = "TEC_Result_${data["register_number"]}.pdf";
      String path = "${dir.path}/$file";
      int c = 1;

      while (await File(path).exists()) {
        final n = file.split(".").first;
        final ext = file.contains(".") ? ".${file.split(".").last}" : "";
        path = "${dir.path}/$n ($c)$ext";
        c++;
      }

      await File(path).writeAsBytes(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Saved to: $path"),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      await OpenFilex.open(path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed: $e"),
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
    final data = result;

    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text(
          "Semester Results",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _txt("Register Number", _reg),
            const SizedBox(height: 15),
            _txt("Date of Birth (DD-MM-YYYY)", _dob),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : fetchResult,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Fetching...",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        "Fetch Result",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            if (data != null) _buildResult(data),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(Map<String, dynamic> data) {
    final subs = data["subjects"];
    final list = _filterSort(subs);

    final pass = subs
        .where(
          (s) => (s["result"] ?? "").toString().toUpperCase().contains("PASS"),
        )
        .length;
    final fail = subs.length - pass;

    final sgpa = double.tryParse(data["sgpa"].toString()) ?? 0;
    final bg = sgpa >= 8
        ? Colors.green.shade100
        : sgpa >= 6
        ? Colors.orange.shade100
        : Colors.red.shade100;
    final tx = sgpa >= 8
        ? Colors.green.shade800
        : sgpa >= 6
        ? Colors.orange.shade800
        : Colors.red.shade800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row("Register Number:", data["register_number"]),
                _row("Name:", data["name"]),
                _row("Degree:", data["degree"]),
                _row("Exam Month:", data["exam_month"]),
                const SizedBox(height: 10),

                Row(
                  children: [
                    const Text(
                      "GPA:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        data["sgpa"].toString(),
                        style: TextStyle(
                          color: tx,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    _badge(
                      "Total: ${subs.length}",
                      Colors.blue.shade100,
                      Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _badge("Pass: $pass", Colors.green.shade100, Colors.green),
                    const SizedBox(width: 8),
                    _badge("Fail: $fail", Colors.red.shade100, Colors.red),
                  ],
                ),

                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _btn(
                      () =>
                          Printing.layoutPdf(onLayout: (_) => _buildPdf(data)),
                      Colors.green,
                      Icons.print_rounded,
                      "Print",
                    ),
                    
                    _btn(
                      () => _confirmAndDownload(data),
                      Colors.blue,
                      Icons.download,
                      "Download",
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Subjects",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                PopupMenuButton(
                  onSelected: (v) {
                    setState(() {
                      if (v == "sem") _key = "Semester";
                      if (v == "grade") _key = "Grade";
                      if (v == "toggle") _asc = !_asc;
                    });
                  },
                  itemBuilder: (_) => [
                    CheckedPopupMenuItem(
                      value: "sem",
                      checked: _key == "Semester",
                      child: const Text("Sort by Semester"),
                    ),
                    CheckedPopupMenuItem(
                      value: "grade",
                      checked: _key == "Grade",
                      child: const Text("Sort by Grade"),
                    ),
                    const PopupMenuItem(
                      value: "toggle",
                      child: Text("Toggle Asc/Desc"),
                    ),
                  ],
                  icon: const Icon(Icons.sort),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() => _showSearch = !_showSearch);
                    if (!_showSearch) {
                      setState(() {
                        _query = "";
                        _search.clear();
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        ),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: !_showSearch
              ? const SizedBox()
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: TextField(
                    controller: _search,
                    autofocus: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      hintText: "Search name / code",
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
                          color: Colors.blue.shade300,
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (v) => setState(() => _query = v.toLowerCase()),
                  ),
                ),
        ),

        ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: list.length,
          itemBuilder: (_, i) {
            final s = list[i];
            final pass = s["result"].toString().toUpperCase().contains("PASS");
            final c = pass ? Colors.green : Colors.red;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: pass ? Colors.green.shade300 : Colors.red.shade300,
                  width: pass ? .5 : 1.2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s["course_name"],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: c.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _row("Code:", s["code"]),
                    _row("Semester:", s["semester"]),
                    _row("Credits:", s["credits"]),
                    _row("Grade:", s["grade"]),
                    _row("Grade Point:", s["grade_point"]),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: c.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        s["result"],
                        style: TextStyle(color: c, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _row(String a, b) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Text(a, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 6),
        Expanded(child: Text(b.toString())),
      ],
    ),
  );

  Widget _badge(String t, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      t,
      style: TextStyle(color: fg, fontWeight: FontWeight.bold),
    ),
  );

  Widget _btn(VoidCallback f, Color c, IconData i, String t) => SizedBox(
    
    child: ElevatedButton.icon(
      onPressed: f,
      icon: Icon(i, color: Colors.white),
      style: ElevatedButton.styleFrom(
        backgroundColor: c,
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      label: Text(
        t,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
