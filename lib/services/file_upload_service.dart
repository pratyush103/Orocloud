import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:orocloud/models/drive_file.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Define the FileUploadService class properly
class FileUploadService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<DriveFile?> uploadFile(File file, {String? directoryId}) async {
    try {
      // Get the user ID
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Upload the file to Supabase Storage
      final String fileName =
          "${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}";
      final String filePath = "uploads/$userId/$fileName";

      await _supabase.storage
          .from('user_files')
          .uploadBinary(
            filePath,
            await file.readAsBytes(),
            fileOptions: FileOptions(
              contentType: getContentType(file.path.split('.').last),
            ),
          );

      final String publicUrl = _supabase.storage
          .from('user_files')
          .getPublicUrl(filePath);

      final fileInsertResponse =
          await _supabase.from('files').insert({
            'user_id': userId,
            'directory_id': directoryId, // UUID or null
            'name': file.path.split('/').last,
            'size': await file.length(),
            'file_type': file.path.split('.').last,
            'bucket_path': filePath,
            'created_at': DateTime.now().toIso8601String(),
            'modified_at': DateTime.now().toIso8601String(),
            'author': userId,
            'starred': false,
            'sharing': 'private',
            'shared_link': publicUrl,
            'access': {
              'owner': true,
              'read': true,
              'write': true,
              'delete': true,
            },
          }).select();

      // Update directory files count
      if (directoryId != null) {
        await _supabase.rpc(
          'update_directory_files_count',
          params: {
            'dir_id': directoryId, // Use the UUID string directly
            'count_change': 1,
            'size_change': await file.length(),
          },
        );
      }

      // Update user file stats
      await _supabase.rpc(
        'update_user_file_stats',
        params: {
          'uid': userId,
          'file_count_change': 1,
          'space_change': await file.length(),
        },
      );

      return DriveFile(
        id: fileInsertResponse[0]['id'],
        icon: Icons.insert_drive_file,
        iconColor: getFileIconColor(file.path.split('.').last),
        title: file.path.split('/').last,
        date: "Modified Today",
        size: formatFileSize(await file.length()),
        previewUrl: publicUrl,
      );
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  static String getContentType(String extension) {
    return lookupMimeType('file.$extension') ?? 'application/octet-stream';
  }

  static String getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'assets/icons/pdf.png';
      case 'doc':
      case 'docx':
        return 'assets/icons/word.png';
      case 'xls':
      case 'xlsx':
        return 'assets/icons/excel.png';
      default:
        return 'assets/icons/file.png';
    }
  }

  static Color getFileIconColor(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
  }

  static Future<bool> updateFileStarred(String fileId, bool isStarred) async {
    try {
      // Get the user ID
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Update the file's starred attribute
      await _supabase
          .from('files')
          .update({'starred': isStarred})
          .eq('id', fileId)
          .eq('user_id', userId); // Ensure we only update the user's own files

      return true;
    } catch (e) {
      throw Exception('Failed to update file: $e');
    }
  }

  static Future<bool> deleteFile(String fileId) async {
    try {
      // Get the user ID
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // First get the file details to know the path and size
      final fileData =
          await _supabase
              .from('files')
              .select('bucket_path, size, directory_id')
              .eq('id', fileId)
              .eq('user_id', userId)
              .single();

      if (fileData == null) {
        throw Exception(
          'File not found or you do not have permission to delete it',
        );
      }

      final String bucketPath = fileData['bucket_path'];
      final int fileSize = fileData['size'];
      final String? directoryId = fileData['directory_id'];

      // Delete file from storage
      await _supabase.storage.from('user_files').remove([bucketPath]);

      // Delete file from database
      await _supabase
          .from('files')
          .delete()
          .eq('id', fileId)
          .eq('user_id', userId);

      // Update directory files count if the file was in a directory
      if (directoryId != null) {
        await _supabase.rpc(
          'update_directory_files_count',
          params: {
            'dir_id': directoryId,
            'count_change': -1, // Decrease count by 1
            'size_change': -fileSize, // Decrease size
          },
        );
      }

      // Update user file stats
      await _supabase.rpc(
        'update_user_file_stats',
        params: {
          'uid': userId,
          'file_count_change': -1, // Decrease count by 1
          'space_change': -fileSize, // Decrease used space
        },
      );

      return true;
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }
}

// Example of how to use this in your widget class
class FileUploadWidget extends StatefulWidget {
  @override
  _FileUploadWidgetState createState() => _FileUploadWidgetState();
}

class _FileUploadWidgetState extends State<FileUploadWidget> {
  bool _isLoading = false;
  String? _currentDirectoryId;
  List<DriveFile> files = [];

  void _handleFileUpload() async {
    setState(() => _isLoading = true);

    try {
      // Pick a file
      final file = await _pickFile();

      if (file != null) {
        // Get current directory ID if viewing a specific directory
        String? directoryId =
            _currentDirectoryId != null ? _currentDirectoryId : null;

        // Upload the file
        DriveFile? newFile = await FileUploadService.uploadFile(
          file,
          directoryId: directoryId,
        );

        if (newFile != null) {
          setState(() {
            files.add(newFile);
          });
          _showMessage("File uploaded successfully", Colors.green);
        }
      }
    } catch (e) {
      _showMessage("Upload error: ${e.toString()}", Colors.redAccent);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<File?> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }
      return null;
    } catch (e) {
      _showMessage("Error picking file: ${e.toString()}", Colors.redAccent);
      return null;
    }
  }

  void _showMessage(String message, Color color) {
    // Implement the function to show a message
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> _fetchUploadedFiles() async {
    // Implement to fetch uploaded files
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('files')
          .select()
          .eq('user_id', userId)
          .eq('directory_id', _currentDirectoryId ?? '')
          .order('created_at', ascending: false);

      setState(() {
        files =
            (response as List)
                .map(
                  (file) => DriveFile(
                    id: file['id'],
                    icon: Icons.insert_drive_file,
                    iconColor: FileUploadService.getFileIconColor(
                      file['file_type'],
                    ),
                    title: file['name'],
                    date: "Modified ${_formatDate(file['modified_at'])}",
                    size: FileUploadService.formatFileSize(file['size']),
                    previewUrl: file['shared_link'],
                  ),
                )
                .toList();
      });
    } catch (e) {
      _showMessage("Error fetching files: ${e.toString()}", Colors.redAccent);
    }
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return "Today";
    }
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    // Your UI implementation
    return Container(); // Placeholder
  }
}
