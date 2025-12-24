import 'package:flutter/material.dart';

class ViewImage extends StatelessWidget {
  final dynamic imageUrl;

  const ViewImage({super.key, required this.imageUrl});

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'View Image',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
      
        iconTheme: IconThemeData(
          color: Colors.white, // <-- change back arrow color here
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: GestureDetector(
        child: InteractiveViewer(
          maxScale: 6.0,
          minScale: 0.6,
          child: Center(
            child: Hero(
              tag: 'note_image_$imageUrl',
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
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
                // If loading fails
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image, color: Colors.grey, size: 100),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
