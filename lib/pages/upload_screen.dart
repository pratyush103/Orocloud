// lib/pages/upload_screen.dart

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
// Import the viewer screens or place them in this file
import 'package:orocloud/pages/image_viewer_screen.dart';
import 'package:orocloud/pages/pdf_viewer_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({Key? key}) : super(key: key);

  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  // File size & allowed types
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10MB
  static const List<String> allowedExtensions = [
    'pdf',
    'png',
    'svg',
    'jpeg',
    'jpg',
  ];

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final session = supabase.auth.currentSession;
    if (session == null && mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  Future<void> pickAndUploadFile() async {
    if (_isUploading) return;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.size > maxFileSizeBytes) {
        _showError('File size exceeds 10MB limit');
        return;
      }

      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });

      final String userId = supabase.auth.currentUser!.id;
      final String fileName =
          "${DateTime.now().millisecondsSinceEpoch}_${file.name}";
      final String filePath = "uploads/$userId/$fileName";

      // Upload file to Supabase Storage
      await supabase.storage
          .from('user_files')
          .uploadBinary(
            filePath,
            file.bytes!,
            fileOptions: FileOptions(
              contentType: _getContentType(file.extension ?? ''),
            ),
          );

      // Get Public URL
      final String publicUrl = supabase.storage
          .from('user_files')
          .getPublicUrl(filePath);

      // Save file metadata to database
      await supabase.from('files').insert({
        'user_id': userId,
        'name': file.name,
        'size': file.size,
        'file_type': file.extension,
        'bucket_path': filePath,
        'created_at': DateTime.now().toIso8601String(),
        'modified_at': DateTime.now().toIso8601String(),
        'shared_link': publicUrl,
      });

      _showSuccess('File uploaded successfully!');
      setState(() {});
    } catch (e) {
      _showError('Upload failed: ${e.toString()}');
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserFiles() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await supabase
          .from('files')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _showError('Error fetching files: ${e.toString()}');
      return [];
    }
  }

  Future<void> openFile(String url, String fileType) async {
    try {
      if (['png', 'jpg', 'jpeg', 'svg'].contains(fileType.toLowerCase())) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ImageViewerScreen(imageUrl: url),
          ),
        );
      } else if (fileType.toLowerCase() == 'pdf') {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => PDFViewerScreen(pdfUrl: url)),
        );
      } else {
        await OpenFile.open(url);
      }
    } catch (e) {
      _showError('Error opening file: ${e.toString()}');
    }
  }

  Future<void> deleteFile(int fileId, String bucketPath) async {
    try {
      await supabase.storage.from('user_files').remove([bucketPath]);
      await supabase.from('files').delete().match({'id': fileId});
      _showSuccess('File deleted successfully');
      setState(() {});
    } catch (e) {
      _showError('Error deleting file: ${e.toString()}');
    }
  }

  Future<void> downloadFile(String fileUrl, String fileName) async {
    try {
      final directory = await getExternalStorageDirectory();
      final downloadPath = '${directory?.path}/$fileName';

      Dio dio = Dio();
      await dio.download(fileUrl, downloadPath);

      _showSuccess('Downloaded to $downloadPath');
    } catch (e) {
      _showError('Download failed: ${e.toString()}');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'svg':
        return 'image/svg+xml';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Files'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            onPressed: pickAndUploadFile,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 8),
                  Text(
                    'Uploading... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                  ),
                ],
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: fetchUserFiles(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final files = snapshot.data ?? [];
                if (files.isEmpty) {
                  return const Center(child: Text('No files uploaded yet'));
                }

                return ListView.separated(
                  itemCount: files.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final file = files[index];
                    return ListTile(
                      title: Text(file['name']),
                      trailing: PopupMenuButton(
                        itemBuilder:
                            (context) => [
                              PopupMenuItem(
                                child: const Text('Preview'),
                                onTap:
                                    () => openFile(
                                      file['shared_link'],
                                      file['file_type'],
                                    ),
                              ),
                              PopupMenuItem(
                                child: const Text('Share Link'),
                                onTap:
                                    () => Share.share(
                                      'Check out this file: ${file['shared_link']}',
                                    ),
                              ),
                              PopupMenuItem(
                                child: const Text('Download'),
                                onTap:
                                    () => downloadFile(
                                      file['shared_link'],
                                      file['name'],
                                    ),
                              ),
                              PopupMenuItem(
                                child: const Text('Delete'),
                                onTap:
                                    () => deleteFile(
                                      file['id'],
                                      file['bucket_path'],
                                    ),
                              ),
                            ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
