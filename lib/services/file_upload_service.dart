// lib/services/file_upload_service.dart (updated)
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:orocloud/models/drive_file.dart';
import 'package:orocloud/services/user_management_service.dart';

class FileUploadService {
  static const List<String> allowedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'mp4',
    'avi',
    'mov',
    'mkv',
    'mp3',
    'wav',
    'ogg',
    'txt',
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'zip',
    'rar',
    'csv',
    'json',
  ];

  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10MB

  static final UserManagementService _userService = UserManagementService();

  /// Picks and uploads a file to the specified directory
  static Future<DriveFile?> pickAndUploadFile(
    BuildContext context, {
    int? directoryId,
  }) async {
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

      final String? userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Get user's root directory if no directory specified
      if (directoryId == null) {
        try {
          final rootDirResult = await Supabase.instance.client.rpc(
            'get_root_directory',
            params: {'user_id_param': userId},
          );

          if (rootDirResult.isEmpty) {
            throw Exception('Root directory not found');
          }

          directoryId = rootDirResult[0]['id'];
        } catch (e) {
          // Fallback using direct query
          final rootDirResult =
              await Supabase.instance.client
                  .from('directories')
                  .select('id')
                  .eq('user_id', userId)
                  .filter('parent_id', 'is', null)
                  .single();
          directoryId = rootDirResult['id'];
        }
      }

      // Check if file already exists in this directory
      assert(directoryId != null, 'Directory ID cannot be null');
      final existingFiles = await Supabase.instance.client
          .from('files')
          .select('id')
          .eq('user_id', userId)
          .eq('directory_id', directoryId!)
          .eq('name', file.name);

      if (existingFiles.isNotEmpty) {
        throw Exception('File "${file.name}" already exists in this folder.');
      }

      // Generate a unique file name
      final String fileName =
          "${DateTime.now().millisecondsSinceEpoch}_${file.name}";
      final String filePath = "uploads/$userId/$fileName";

      // Upload file to Supabase Storage
      await Supabase.instance.client.storage
          .from('user_files')
          .uploadBinary(
            filePath,
            file.bytes!,
            fileOptions: FileOptions(
              contentType: getContentType(file.extension ?? ''),
            ),
          );

      // Get Public URL
      final String publicUrl = Supabase.instance.client.storage
          .from('user_files')
          .getPublicUrl(filePath);

      // Save metadata to database
      final fileInsertResponse =
          await Supabase.instance.client.from('files').insert({
            'user_id': userId,
            'directory_id': directoryId,
            'name': file.name,
            'size': file.size.toString(),
            'file_type': file.extension,
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

      // Update directory file count and size
      await Supabase.instance.client.rpc(
        'update_directory_files_count',
        params: {
          'dir_id': directoryId,
          'count_change': 1,
          'size_change': file.size,
        },
      );

      // Update user's file stats
      await Supabase.instance.client.rpc(
        'update_user_file_stats',
        params: {
          'uid': userId,
          'file_count_change': 1,
          'space_change': file.size,
        },
      );

      return DriveFile(
        id: fileInsertResponse[0]['id'],
        icon: getFileIcon(file.extension ?? ''),
        iconColor: getFileIconColor(file.extension ?? ''),
        title: file.name,
        date: "Modified Today",
        size: _formatFileSize(file.size),
        previewUrl: publicUrl,
      );
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  /// Deletes a file and updates directory metadata
  static Future<void> deleteFile(int fileId) async {
    try {
      final String? userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Get file metadata before deletion
      final fileData =
          await Supabase.instance.client
              .from('files')
              .select('id, directory_id, bucket_path, size')
              .eq('id', fileId)
              .eq('user_id', userId) // Security check
              .single();

      if (fileData == null) {
        throw Exception('File not found or access denied');
      }

      // Get file size for stats update
      final int fileSize = int.tryParse(fileData['size'] ?? '0') ?? 0;
      final int directoryId = fileData['directory_id'];
      final String bucketPath = fileData['bucket_path'];

      // 1. Delete file from storage
      await Supabase.instance.client.storage.from('user_files').remove([
        bucketPath,
      ]);

      // 2. Delete file metadata from database
      await Supabase.instance.client
          .from('files')
          .delete()
          .eq('id', fileId)
          .eq('user_id', userId); // Security check

      // 3. Update directory metadata
      await Supabase.instance.client.rpc(
        'update_directory_files_count',
        params: {
          'dir_id': directoryId,
          'count_change': -1, // Remove one file
          'size_change': -fileSize, // Remove file size
        },
      );

      // 4. Update user's file stats
      await Supabase.instance.client.rpc(
        'update_user_file_stats',
        params: {
          'uid': userId,
          'file_count_change': -1,
          'space_change': -fileSize,
        },
      );
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  // Helper method to format file size
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return "$bytes B";
    } else if (bytes < 1024 * 1024) {
      return "${(bytes / 1024).toStringAsFixed(1)} KB";
    } else if (bytes < 1024 * 1024 * 1024) {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    } else {
      return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB";
    }
  }

  /// Get appropriate icon for file type
  static IconData getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'ogg':
        return Icons.audio_file;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'zip':
      case 'rar':
        return Icons.folder_zip;
      case 'txt':
      case 'json':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  /// Get appropriate color for file type icon
  static Color getFileIconColor(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        return Colors.blue;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
        return Colors.red;
      case 'mp3':
      case 'wav':
      case 'ogg':
        return Colors.purple;
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'zip':
      case 'rar':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  /// Get MIME content type based on file extension
  static String getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'mp4':
        return 'video/mp4';
      case 'avi':
        return 'video/x-msvideo';
      case 'mov':
        return 'video/quicktime';
      case 'mkv':
        return 'video/x-matroska';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'csv':
        return 'text/csv';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/x-rar-compressed';
      case 'txt':
        return 'text/plain';
      case 'json':
        return 'application/json';
      default:
        return 'application/octet-stream';
    }
  }
}
