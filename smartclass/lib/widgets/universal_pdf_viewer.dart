import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'pdf_runtime_stub.dart' if (dart.library.io) 'pdf_runtime_io.dart' as runtime;

class UniversalPdfViewer extends StatefulWidget {
  final String pdfUrl;
  final String? filePath;

  const UniversalPdfViewer({
    super.key,
    required this.pdfUrl,
    this.filePath,
  });

  @override
  State<UniversalPdfViewer> createState() => _UniversalPdfViewerState();
}

class _UniversalPdfViewerState extends State<UniversalPdfViewer> {
  PdfControllerPinch? _mobileController;
  final PdfViewerController _desktopController = PdfViewerController();

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = 'Failed to load PDF';
  int _currentPage = 0;
  int _totalPages = 0;
  Uint8List? _desktopFileBytes;

  bool get _useMobilePdfx =>
      !kIsWeb && (runtime.isAndroidPlatform || runtime.isIOSPlatform);

  bool get _useFileSource =>
      widget.filePath != null && widget.filePath!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  @override
  void didUpdateWidget(covariant UniversalPdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pdfUrl != widget.pdfUrl || oldWidget.filePath != widget.filePath) {
      _loadDocument();
    }
  }

  Future<void> _loadDocument() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = 'Failed to load PDF';
      _currentPage = 0;
      _totalPages = 0;
      _desktopFileBytes = null;
    });

    try {
      if (_useMobilePdfx) {
        await _loadMobileDocument();
      } else {
        await _prepareDesktopDocument();
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (error) {
      debugPrint('PDF load error: $error');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _loadMobileDocument() async {
    final bytes = await _resolvePdfBytes();
    final document = await PdfDocument.openData(bytes);

    _mobileController?.dispose();
    _mobileController = PdfControllerPinch(document: Future.value(document));
  }

  Future<void> _prepareDesktopDocument() async {
    if (_useFileSource) {
      _desktopFileBytes = await _resolvePdfBytes();
    }
  }

  Future<Uint8List> _resolvePdfBytes() async {
    if (_useFileSource) {
      final bytes = await runtime.readPdfFileBytes(widget.filePath!);
      if (bytes == null) {
        throw Exception('File access is not supported on this platform.');
      }
      return bytes;
    }

    final uri = Uri.tryParse(widget.pdfUrl);
    if (uri == null) {
      throw Exception('Invalid PDF URL');
    }

    return http.readBytes(uri);
  }

  void _handleDesktopLoaded(PdfDocumentLoadedDetails details) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasError = false;
      _totalPages = details.document.pages.count;
      _currentPage = _desktopController.pageNumber == 0
          ? 1
          : _desktopController.pageNumber;
    });
  }

  void _handleDesktopLoadFailed(PdfDocumentLoadFailedDetails details) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasError = true;
      _errorMessage = details.error;
    });
  }

  @override
  void dispose() {
    _mobileController?.dispose();
    _desktopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorView();
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: _useMobilePdfx ? _buildMobileViewer() : _buildDesktopViewer(),
              ),
              if (_isLoading)
                Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
            ],
          ),
        ),
        _buildBottomToolbar(),
      ],
    );
  }

  Widget _buildMobileViewer() {
    if (_mobileController == null) {
      return const SizedBox.shrink();
    }

    return PdfViewPinch(
      controller: _mobileController!,
      onDocumentLoaded: (details) {
        if (!mounted) return;
        setState(() {
          _totalPages = details.pagesCount;
          _currentPage = 1;
          _isLoading = false;
        });
      },
      onPageChanged: (page) {
        if (!mounted) return;
        setState(() => _currentPage = page);
      },
    );
  }

  Widget _buildDesktopViewer() {
    if (_desktopFileBytes != null) {
      return SfPdfViewer.memory(
        _desktopFileBytes!,
        controller: _desktopController,
        onDocumentLoaded: _handleDesktopLoaded,
        onDocumentLoadFailed: _handleDesktopLoadFailed,
        onPageChanged: (details) {
          if (!mounted) return;
          setState(() => _currentPage = details.newPageNumber);
        },
      );
    }

    return SfPdfViewer.network(
      widget.pdfUrl,
      controller: _desktopController,
      onDocumentLoaded: _handleDesktopLoaded,
      onDocumentLoadFailed: _handleDesktopLoadFailed,
      onPageChanged: (details) {
        if (!mounted) return;
        setState(() => _currentPage = details.newPageNumber);
      },
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1 ? _goToPreviousPage : null,
          ),
          Text(
            _totalPages == 0 ? 'Loading...' : '$_currentPage / $_totalPages',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _totalPages > 0 && _currentPage < _totalPages
                ? _goToNextPage
                : null,
          ),
        ],
      ),
    );
  }

  void _goToPreviousPage() {
    if (_useMobilePdfx) {
      _mobileController?.previousPage(
        curve: Curves.ease,
        duration: const Duration(milliseconds: 200),
      );
      return;
    }

    _desktopController.previousPage();
  }

  void _goToNextPage() {
    if (_useMobilePdfx) {
      _mobileController?.nextPage(
        curve: Curves.ease,
        duration: const Duration(milliseconds: 200),
      );
      return;
    }

    _desktopController.nextPage();
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
          const SizedBox(height: 10),
          const Text(
            'Failed to load PDF',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loadDocument,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
