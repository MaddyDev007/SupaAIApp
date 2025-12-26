import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartclass/screens/student_screen/view_image.dart';

/// ---------------- PORTRAIT LOCK WRAPPER ----------------
/// Use this only for pages that must stay portrait
class PortraitOnly extends StatefulWidget {
  final Widget child;

  const PortraitOnly({
    super.key,
    required this.child,
  });

  @override
  State<PortraitOnly> createState() => _PortraitOnlyState();
}

class _PortraitOnlyState extends State<PortraitOnly> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  void dispose() {
    // Restore global orientation support
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// ---------------- VIEW NOTE PAGE (STUDENT) ----------------
class ViewNotePage extends StatelessWidget {
  final String title;
  final String content;
  final int noteId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Color color;
  final String? imageUrl;

  const ViewNotePage({
    super.key,
    required this.title,
    required this.content,
    required this.noteId,
    required this.color,
    required this.onEdit,
    required this.onDelete,
    this.imageUrl,
  });
  

  // ---------------- NAV ANIMATION ----------------
  static const _curve = Cubic(0.22, 0.61, 0.36, 1.0);
  static final _slideTween = Tween<Offset>(
    begin: const Offset(1, 0),
    end: Offset.zero,
  );

  void pushWithAnimation(BuildContext context, Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(parent: animation, curve: _curve);
          return SlideTransition(
            position: _slideTween.animate(curved),
            child: child,
          );
        },
      ),
    );
  }


  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    final heroTag = 'note_image_$noteId';
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "View Note",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------------- IMAGE ----------------
                if (imageUrl != null)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ViewImage(imageUrl: imageUrl!,
                          heroTag: heroTag),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Hero(
                        tag: heroTag, // ✅ MATCHES view image page
                        child: Image.network(
                          imageUrl!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder:
                              (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return SizedBox(
                              height: 180,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color:
                                      Theme.of(context).primaryColor,
                                  value: loadingProgress
                                              .expectedTotalBytes !=
                                          null
                                      ? loadingProgress
                                              .cumulativeBytesLoaded /
                                          loadingProgress
                                              .expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            height: 180,
                            color: Colors.grey.shade300,
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // ---------------- TITLE ----------------
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 12),
                Divider(color: Colors.grey[300]),
                const SizedBox(height: 12),

                // ---------------- CONTENT ----------------
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Text(
                      content,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ---------------- ACTIONS ----------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: Icon(
                        Icons.edit,
                        color: Theme.of(context).primaryColor,
                      ),
                      label: const Text("Edit"),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).primaryColor,
                      ),
                      onPressed: onEdit,
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                      ),
                      label: const Text("Delete"),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
