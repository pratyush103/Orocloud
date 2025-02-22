import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';

class DocumentScannerPage extends StatefulWidget {
  const DocumentScannerPage({Key? key}) : super(key: key);

  @override
  State<DocumentScannerPage> createState() => _DocumentScannerPageState();
}

class _DocumentScannerPageState extends State<DocumentScannerPage> {
  List<String> _pictures = [];

  Future<void> scanDocument() async {
    try {
      List<String>? pictures = await CunningDocumentScanner.getPictures();
      if (pictures != null && pictures.isNotEmpty) {
        setState(() {
          _pictures = pictures;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning document: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Document')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: scanDocument,
            child: const Text("Scan Document"),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _pictures.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.file(File(_pictures[index])),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
