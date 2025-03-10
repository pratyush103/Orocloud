import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:orocloud/models/drive_file.dart';  // Import DriveFile model

final SupabaseClient supabase = Supabase.instance.client;

class FileUploadService {
  static const List<String> allowedExtensions = [
    'jpg', 'jpeg', 'png', 'gif', 'bmp', 'mp4', 'avi', 'mov', 'mkv', 'mp3', 'wav', 'ogg',
    'txt', 'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'zip', 'rar', 'csv', 'json'
  ];

  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10MB

  /// Picks and uploads a file, throwing an error if it already exists.
  static Future<DriveFile?> pickAndUploadFile(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;

      if (file.size > maxFileSizeBytes) {
        throw Exception('File size exceeds 10MB limit');
      }

      final String? userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Check if file already exists in the database
      final existingFiles = await supabase
          .from('files')
          .select('id')
          .eq('user_id', userId)
          .eq('name', file.name);

      if (existingFiles.isNotEmpty) {
        throw Exception('File "${file.name}" is already uploaded.');
      }

      // Generate a unique file name to avoid overwrites
      final String fileName = "${DateTime.now().millisecondsSinceEpoch}_${file.name}";
      final String filePath = "uploads/$userId/$fileName";

      // Upload file to Supabase Storage
      await supabase.storage.from('user_files').uploadBinary(
        filePath,
        file.bytes!,
        fileOptions: FileOptions(contentType: getContentType(file.extension ?? '')),
      );

      // Get Public URL
      final String publicUrl = supabase.storage.from('user_files').getPublicUrl(filePath);

      // Save metadata to database
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

      return DriveFile(
        icon: getFileIcon(file.extension ?? ''),
        iconColor: getFileIconColor(file.extension ?? ''),
        title: file.name,
        date: "Modified Today",
        previewUrl: publicUrl,
      );
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  /// Returns appropriate MIME type for file upload
  static String getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg': case 'jpeg': case 'png': case 'gif': case 'bmp': return 'image/$extension';
      case 'mp4': case 'avi': case 'mov': case 'mkv': return 'video/$extension';
      case 'mp3': case 'wav': case 'ogg': return 'audio/$extension';
      case 'pdf': return 'application/pdf';
      case 'doc': case 'docx': return 'application/msword';
      case 'xls': case 'xlsx': return 'application/vnd.ms-excel';
      case 'ppt': case 'pptx': return 'application/vnd.ms-powerpoint';
      case 'zip': case 'rar': return 'application/zip';
      default: return 'application/octet-stream';
    }
  }

  /// Returns appropriate icon for file type
  static IconData getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'doc': case 'docx': return Icons.description;
      case 'xls': case 'xlsx': return Icons.table_chart;
      case 'ppt': case 'pptx': return Icons.slideshow;
      case 'jpg': case 'jpeg': case 'png': case 'gif': return Icons.image;
      case 'mp4': case 'mov': case 'avi': return Icons.videocam;
      case 'mp3': case 'wav': return Icons.audiotrack;
      case 'zip': case 'rar': return Icons.archive;
      default: return Icons.insert_drive_file;
    }
  }

  /// Returns appropriate color for file type
  static Color getFileIconColor(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf': return Colors.red;
      case 'doc': case 'docx': return Colors.blue;
      case 'xls': case 'xlsx': return Colors.green;
      case 'ppt': case 'pptx': return Colors.orange;
      case 'jpg': case 'jpeg': case 'png': case 'gif': return Colors.purple;
      case 'mp4': case 'mov': case 'avi': return Colors.deepOrange;
      case 'mp3': case 'wav': return Colors.teal;
      case 'zip': case 'rar': return Colors.brown;
      default: return Colors.grey;
    }
  }
}
