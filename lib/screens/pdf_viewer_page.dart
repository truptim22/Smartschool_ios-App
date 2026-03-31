import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class PDFViewerPage extends StatefulWidget {
  final String filePath;
  final String title;
  final bool isLocalFile;

  const PDFViewerPage({
    Key? key,
    required this.filePath,
    required this.title,
    this.isLocalFile = false,
  }) : super(key: key);

  @override
  State<PDFViewerPage> createState() => _PDFViewerPageState();
}

class _PDFViewerPageState extends State<PDFViewerPage> {
  PdfController? _pdfController;
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadPDF();
  }
 Future<void> _loadPDF() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      print('📄 === PDF VIEWER: Loading PDF ===');
      print('   Is Local: ${widget.isLocalFile}');
      print('   Path: ${widget.filePath}');

      String localFilePath;
      
      if (widget.isLocalFile) {
        // Use the local file directly
        localFilePath = widget.filePath;
        final file = File(localFilePath);
        if (!await file.exists()) {
          throw Exception('File not found: ${widget.filePath}');
        }
        print('✅ Local file exists');
      } else {
        // ✅ FIX: Handle both full URLs and relative paths
        String downloadUrl;
        
        if (widget.filePath.startsWith('http://') || widget.filePath.startsWith('https://')) {
          // It's already a full URL (S3 or backend)
          downloadUrl = widget.filePath;
          print('✅ Using full URL directly: $downloadUrl');
        } else {
          // It's a relative path - prepend backend URL
          final cleanPath = widget.filePath.startsWith('/') 
              ? widget.filePath.substring(1) 
              : widget.filePath;
          downloadUrl = 'https://lantechschools.org/$cleanPath';
          print('✅ Constructed URL: $downloadUrl');
        }

        print('📥 Downloading from: $downloadUrl');

        final response = await http.get(Uri.parse(downloadUrl));
        
        if (response.statusCode != 200) {
          throw Exception('Failed to download PDF: HTTP ${response.statusCode}');
        }

        print('✅ Downloaded ${response.bodyBytes.length} bytes');

        // Save to temporary file
        final dir = await getTemporaryDirectory();
        final tempFile = File('${dir.path}/temp_pdf_${DateTime.now().millisecondsSinceEpoch}.pdf');
        await tempFile.writeAsBytes(response.bodyBytes);
        
        localFilePath = tempFile.path;
        print('✅ Saved to: $localFilePath');
      }

      // Create PdfController with the file path
final document = PdfDocument.openFile(localFilePath);
_pdfController = PdfController(document: document);

      print('✅ PDF loaded successfully: $_totalPages pages');
      print('📄 === PDF VIEWER: Load complete ===');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('❌ PDF Load Error: $e');
      print('Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _error = 'Failed to load PDF: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title.length > 30 
            ? '${widget.title.substring(0, 30)}...' 
            : widget.title,
        ),
        backgroundColor: const Color(0xFF6200EE),
        foregroundColor: Colors.white,
        actions: [
          if (_totalPages > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _buildPageNavigation(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF6200EE)),
            const SizedBox(height: 16),
            const Text(
              'Loading PDF...',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isLocalFile ? 'Opening local file' : 'Downloading from server',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadPDF,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6200EE),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_pdfController == null) {
      return const Center(child: Text('No PDF available'));
    }

    return PdfView(
      controller: _pdfController!,
      onPageChanged: (page) {
        setState(() {
          _currentPage = page;
        });
      },
      scrollDirection: Axis.vertical,
      pageSnapping: true,
    );
  }

  Widget? _buildPageNavigation() {
    if (_pdfController == null || _totalPages <= 1) return null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_currentPage < _totalPages)
          FloatingActionButton(
            heroTag: 'next',
            onPressed: () {
              _pdfController?.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            backgroundColor: const Color(0xFF6200EE),
                  foregroundColor: Colors.white, // ✅ ADD THIS LINE

            child: const Icon(Icons.arrow_downward),
          ),
        if (_currentPage > 1) ...[
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'prev',
            onPressed: () {
              _pdfController?.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            backgroundColor: const Color(0xFF6200EE),
                  foregroundColor: Colors.white, // ✅ ADD THIS LINE

            child: const Icon(Icons.arrow_upward),
          ),
        ],
      ],
    );
  }
}