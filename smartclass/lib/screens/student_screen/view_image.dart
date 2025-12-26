import 'package:flutter/material.dart';

class ViewImage extends StatelessWidget {
  final String imageUrl;      // ✅ strong typing
  final Object heroTag;       // ✅ hero tag passed explicitly

  const ViewImage({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'View Image',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        elevation: 0,
      ),
      body: InteractiveViewer(
        maxScale: 6.0,
        minScale: 0.6,
        child: Center(
          child: Hero(
            tag: heroTag, // ✅ MATCHES note page
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.grey.shade200,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                      strokeWidth: 2.5,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image,
                color: Colors.grey,
                size: 100,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
