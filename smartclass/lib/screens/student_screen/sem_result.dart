import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SemResultPage extends StatefulWidget {
  const SemResultPage({super.key});

  @override
  State<SemResultPage> createState() => _SemResultPageState();
}

class _SemResultPageState extends State<SemResultPage> {
  final _regController = TextEditingController();
  final _dobController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStudentDetails();
  }

  Future<void> _fetchStudentDetails() async {
  try {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final profile = await Supabase.instance.client
        .from('profiles')
        .select("reg_no")
        .eq('id', user.id)
        .single();

    // ✅ Auto-fill register number
    if (profile['reg_no'] != null) {
      setState(() {
        _regController.text = profile['reg_no'];
      });
    }

  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Unable to load student details"),
      behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),),
    );
  }
}


  // Search & sort state
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";
  bool _showSearch = false;

  String _sortKey = 'Semester'; // 'Semester' | 'Grade'
  bool _sortAsc = true;

  bool _loading = false;
  Map<String, dynamic>? resultData;

  final String apiUrl = "https://supaaiapp-1.onrender.com/results/getResult";

  // ---------------- API ----------------
  Future<void> fetchResult() async {
    if (_regController.text.isEmpty || _dobController.text.isEmpty) {
      showErrorDialog("Fill inputs", "Please fill all fields.");
      return;
    }

    setState(() => _loading = true);

    final body = jsonEncode({
      "register_number": _regController.text.trim(),
      "dob": _dobController.text.trim().replaceAll("/", "-"),
    });

    try {
      final res = await http.post(
        Uri.parse(apiUrl),
        body: body,
        headers: {"Content-Type": "application/json"},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        if (data["subjects"] == null || (data["subjects"] as List).isEmpty) {
          showErrorDialog("No Result Found", "No results found for this user.");
          setState(() => _loading = false);
          return;
        }

        setState(() {
          resultData = data;
          _searchQuery = "";
          _searchCtrl.clear();
        });
      } else {
        showErrorDialog(
          "No Result Found",
          "Result not found. Check Register No / DOB.",
        );
      }
    } catch (e) {
      showErrorDialog("Error", "Network Error: check your Internet.");
    }

    setState(() => _loading = false);
  }

  void showErrorDialog(String head, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(head, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      cursorColor: Colors.blue,
      obscureText: obscure,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelText: label,
        floatingLabelStyle: TextStyle(
          color: Colors.blueAccent, // 👈 Change label text color here
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade100, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.blue.shade300, // Color when focused
            width: 2,
          ),
        ),
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text(
          "Semester Results",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        iconTheme: IconThemeData(
          color: Colors.white, // <-- change back arrow color here
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTextField(
              label: 'Register Number',
              controller: _regController,
            ),
            const SizedBox(height: 15),

            _buildTextField(
              label: 'Date of Birth (DD-MM-YYYY)',
              controller: _dobController,
            ),
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
                            'Fetching...',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Fetch Result',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            if (resultData != null) buildResultUI(resultData!),
          ],
        ),
      ),
    );
  }

  // ---- Filtering + sorting helpers ----
  List<dynamic> _applyFiltersAndSorting(List<dynamic> subjects) {
    // Filter
    final q = _searchQuery.trim().toLowerCase();
    List<dynamic> filtered = subjects.where((s) {
      final name = s["course_name"].toString().toLowerCase();
      final code = s["code"].toString().toLowerCase();
      //final sem = s["semester"].toString().toLowerCase();
      return q.isEmpty || name.contains(q) || code.contains(q);
    }).toList();

    // Sort
    int toInt(dynamic v) {
      try {
        return int.parse(v.toString().replaceAll(RegExp(r'[^0-9]'), ''));
      } catch (_) {
        return 0;
      }
    }

    int gp(dynamic v) {
      try {
        // grade_point already numeric in your JSON
        return double.parse(v.toString()).round();
      } catch (_) {
        return 0;
      }
    }

    filtered.sort((a, b) {
      int cmp;
      if (_sortKey == 'Grade') {
        // Grade: sort by grade_point (desc default UX for grade)
        cmp = gp(a["grade_point"]).compareTo(gp(b["grade_point"]));
      } else {
        // Semester numeric
        cmp = toInt(a["semester"]).compareTo(toInt(b["semester"]));
      }
      return _sortAsc ? cmp : -cmp;
    });

    return filtered;
  }

  Widget buildResultUI(Map<String, dynamic> data) {
    final subjects = (data["subjects"] as List<dynamic>);
    final filtered = _applyFiltersAndSorting(subjects);

    // Pass / Fail calculation (from original data, not filtered)
    final passCount = subjects
        .where((s) => s["result"].toString().toUpperCase().contains("PASS"))
        .length;
    final failCount = subjects.length - passCount;

    // SGPA color logic
    double sgpaValue = 0.0;
    try {
      sgpaValue = double.parse(data["sgpa"].toString());
    } catch (_) {}
    Color sgpaBg, sgpaText;
    if (sgpaValue >= 8.0) {
      sgpaBg = Colors.green.shade100;
      sgpaText = Colors.green.shade800;
    } else if (sgpaValue >= 6.0) {
      sgpaBg = Colors.orange.shade100;
      sgpaText = Colors.orange.shade800;
    } else {
      sgpaBg = Colors.red.shade100;
      sgpaText = Colors.red.shade800;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // -------- Header Card ----------
        Card(
          elevation: 3,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                rowText("Register Number:", data["register_number"] ?? "-"),
                rowText("Name:", data["name"] ?? "-"),
                rowText("Degree:", data["degree"] ?? "-"),
                rowText("Exam Month:", data["exam_month"] ?? "-"),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text(
                      "GPA:",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: sgpaBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        data["sgpa"].toString(),
                        style: TextStyle(
                          color: sgpaText,
                          fontSize: 14,
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
                      "Total: ${subjects.length}",
                      Colors.blue.shade100,
                      Colors.blue,
                    ),
                    const SizedBox(width: 10),
                    _badge(
                      "Pass: $passCount",
                      Colors.green.shade100,
                      Colors.green,
                    ),
                    const SizedBox(width: 10),
                    _badge("Fail: $failCount", Colors.red.shade100, Colors.red),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => generatePdf(data),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Download as PDF',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // -------- Title row with Search + Sort ----------
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Subjects",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            Row(
              children: [
                // Sort menu
                PopupMenuButton<String>(
                  tooltip: "Sort",
                  onSelected: (value) {
                    if (value == 'by_sem') {
                      setState(() => _sortKey = 'Semester');
                    } else if (value == 'by_grade') {
                      setState(() => _sortKey = 'Grade');
                    } else if (value == 'toggle') {
                      setState(() => _sortAsc = !_sortAsc);
                    }
                  },
                  itemBuilder: (context) => [
                    CheckedPopupMenuItem(
                      value: 'by_sem',
                      checked: _sortKey == 'Semester',
                      child: const Text("Sort by Semester"),
                    ),
                    CheckedPopupMenuItem(
                      value: 'by_grade',
                      checked: _sortKey == 'Grade',
                      child: const Text("Sort by Grade (GP)"),
                    ),
                    const PopupMenuItem(
                      value: 'toggle',
                      child: Text("Toggle Asc/Desc"),
                    ),
                  ],
                  icon: const Icon(Icons.sort),
                ),

                // Search icon
                IconButton(
                  tooltip: "Search",
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() => _showSearch = !_showSearch);
                    if (!_showSearch) {
                      setState(() {
                        _searchQuery = "";
                        _searchCtrl.clear();
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        ),

        // Search box (collapsible)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: !_showSearch
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    cursorColor: Colors.blue,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      hintText: "Search by subject name / code",
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

                    onChanged: (v) =>
                        setState(() => _searchQuery = v.toLowerCase()),
                  ),
                ),
        ),

        // -------- Subjects list (filtered + sorted) ----------
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final sub = filtered[index];
            final isPass = sub["result"].toString().toUpperCase().contains(
              "PASS",
            );

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isPass ? Colors.green.shade300 : Colors.red.shade300,
                  width: isPass ? 0.5 : 1.2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub["course_name"],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isPass
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    rowText("Code:", sub["code"].toString()),
                    rowText("Semester:", sub["semester"].toString()),
                    rowText("Credits:", sub["credits"].toString()),
                    rowText("Grade:", sub["grade"].toString()),
                    rowText("Grade Point:", sub["grade_point"].toString()),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isPass
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          sub["result"].toString(),
                          style: TextStyle(
                            color: isPass ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

  // ---------------- Shared widgets ----------------
  Widget rowText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ---------------- PDF ----------------
  Future<void> generatePdf(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    final subjects = (data["subjects"] as List<dynamic>);
    final filtered = _applyFiltersAndSorting(subjects);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "TEC Semester Result",
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 16),

                pw.Text("Register Number: ${data["register_number"]}"),
                pw.Text("Name: ${data["name"]}"),
                pw.Text("Degree: ${data["degree"]}"),
                pw.Text("Exam Month: ${data["exam_month"]}"),
                pw.Text(
                  "GPA: ${data["sgpa"]}",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 20),

                pw.Text(
                  "Subjects",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),

                // ✅ Auto-paginating table
                pw.TableHelper.fromTextArray(
                  headers: const [
                    "Sem",
                    "Course Name",
                    "Code",
                    "Credits",
                    "Grade",
                    "GP",
                    "Result",
                  ],
                  data: filtered.map((s) {
                    return [
                      s["semester"].toString(),
                      s["course_name"].toString(),
                      s["code"].toString(),
                      s["credits"].toString(),
                      s["grade"].toString(),
                      s["grade_point"].toString(),
                      s["result"].toString(),
                    ];
                  }).toList(),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFE0E0E0),
                  ),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  cellAlignment: pw.Alignment.centerLeft,
                  columnWidths: {
                    0: const pw.FixedColumnWidth(30),
                    1: const pw.FlexColumnWidth(),
                    2: const pw.FixedColumnWidth(60),
                    3: const pw.FixedColumnWidth(40),
                    4: const pw.FixedColumnWidth(40),
                    5: const pw.FixedColumnWidth(40),
                    6: const pw.FixedColumnWidth(40),
                  },
                  rowDecoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(width: .5, color: PdfColors.grey),
                    ),
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
