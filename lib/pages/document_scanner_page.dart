import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

import '../auth/auth_service.dart';
import 'login_page.dart';

class DocumentScannerPage extends StatefulWidget {
  const DocumentScannerPage({Key? key}) : super(key: key);

  @override
  State<DocumentScannerPage> createState() => _DocumentScannerPageState();
}

class _DocumentScannerPageState extends State<DocumentScannerPage> {
  List<String> _scannedImages = [];

  // Function to scan multiple pages in one session
  Future<void> scanDocuments() async {
    try {
      List<String>? pictures = await CunningDocumentScanner.getPictures();
      if (pictures != null && pictures.isNotEmpty) {
        setState(() {
          _scannedImages = pictures; // Store only the latest session's images
        });
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error scanning document: $error")),
      );
    }
  }

  // Function to save scanned pages as a PDF file
  Future<void> saveAsPDF() async {
    if (_scannedImages.isEmpty) return;

    final pdf = pw.Document();
    for (var imagePath in _scannedImages) {
      final imageFile = File(imagePath);
      final image = pw.MemoryImage(imageFile.readAsBytesSync());
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Center(child: pw.Image(image));
          },
        ),
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/scanned_document.pdf');
    await file.writeAsBytes(await pdf.save());

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("PDF saved: ${file.path}")));

    OpenFile.open(file.path); // Open the saved PDF
  }

  // Function to save individual scanned images
  Future<void> saveAsImages() async {
    if (_scannedImages.isEmpty) return;

    final dir = await getApplicationDocumentsDirectory();
    for (int i = 0; i < _scannedImages.length; i++) {
      final imageFile = File(_scannedImages[i]);
      final newFile = File('${dir.path}/scanned_image_$i.jpg');
      await imageFile.copy(newFile.path);
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Images saved in ${dir.path}")));
  }

  // Function to clear scanned images
  void clearScannedImages() {
    setState(() {
      _scannedImages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Document Scanner"),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              final authService = AuthService();
              await authService.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (_) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: scanDocuments,
                child: const Text("Scan Document"),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: clearScannedImages,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Clear"),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child:
                _scannedImages.isEmpty
                    ? const Center(child: Text("No scanned documents yet."))
                    : GridView.builder(
                      padding: const EdgeInsets.all(10),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: _scannedImages.length,
                      itemBuilder: (context, index) {
                        return Image.file(
                          File(_scannedImages[index]),
                          fit: BoxFit.cover,
                        );
                      },
                    ),
          ),
          if (_scannedImages.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: saveAsPDF,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text("Save as PDF"),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: saveAsImages,
                  icon: const Icon(Icons.image),
                  label: const Text("Save as Images"),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}
