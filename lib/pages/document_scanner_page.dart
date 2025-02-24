import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import 'login_page.dart';

class DocumentScannerPage extends StatefulWidget {
  const DocumentScannerPage({Key? key}) : super(key: key);

  @override
  State<DocumentScannerPage> createState() => _DocumentScannerPageState();
}

class _DocumentScannerPageState extends State<DocumentScannerPage> {
  List<String> _scannedImages = [];

  // Function to scan documents
  Future<void> scanDocuments() async {
    try {
      List<String>? pictures = await CunningDocumentScanner.getPictures();
      if (pictures != null && pictures.isNotEmpty) {
        setState(() {
          _scannedImages.addAll(pictures);
        });
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error scanning document: $error")),
      );
    }
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
                child: const Text("Clear"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
        ],
      ),
    );
  }
}
