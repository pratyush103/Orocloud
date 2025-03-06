// lib/pages/pdf_viewer_screen.dart

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PDFViewerScreen extends StatefulWidget {
  final String pdfUrl;

  const PDFViewerScreen({Key? key, required this.pdfUrl}) : super(key: key);

  @override
  _PDFViewerScreenState createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  String? localPath;
  bool isLoading = true;
  int totalPages = 0;
  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    downloadPDF();
  }

  Future<void> downloadPDF() async {
    setState(() {
      isLoading = true;
    });

    try {
      if (!Uri.parse(widget.pdfUrl).hasScheme) {
        throw Exception('Invalid URL format: ${widget.pdfUrl}');
      }

      final dir = await getTemporaryDirectory();
      final fileName = 'document_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${dir.path}/$fileName';

      // Create headers for the request
      Map<String, String> headers = {'Accept': 'application/pdf'};

      // Add authentication if required for Supabase Storage
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && widget.pdfUrl.contains('supabase')) {
        headers['Authorization'] = 'Bearer ${session.accessToken}';
      }

      print('Downloading PDF from: ${widget.pdfUrl}');

      final dio = Dio();
      final response = await dio.get(
        widget.pdfUrl,
        options: Options(
          headers: headers,
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus:
              (status) => status! < 500, // Accept status codes < 500
        ),
      );

      if (response.statusCode == 200) {
        final file = await File(filePath).writeAsBytes(response.data);

        setState(() {
          localPath = file.path;
          isLoading = false;
        });

        print('PDF downloaded successfully: $localPath');
      } else {
        throw Exception(
          'Failed to load PDF. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('PDF error: $e');
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Viewer'),
        actions: [
          if (!isLoading && localPath != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                Share.shareXFiles([
                  XFile(localPath!),
                ], text: 'Sharing PDF file');
              },
            ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : localPath != null
              ? Stack(
                children: [
                  PDFView(
                    filePath: localPath!,
                    enableSwipe: true,
                    swipeHorizontal: true,
                    autoSpacing: false,
                    pageFling: false,
                    onRender: (pages) {
                      setState(() {
                        totalPages = pages!;
                      });
                    },
                    onPageChanged: (page, _) {
                      setState(() {
                        currentPage = page!;
                      });
                    },
                    onError: (error) {
                      print('PDF view error: $error');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error rendering PDF: $error'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Page ${currentPage + 1} of $totalPages',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              )
              : const Center(child: Text('Failed to load PDF')),
    );
  }
}
