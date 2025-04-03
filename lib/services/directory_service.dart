// lib/services/directory_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class DirectoryService {
  final SupabaseClient supabase = Supabase.instance.client;

  // Create a new directory
  Future<int> createDirectory(String name, String userId, {int? parentId}) async {
    try {
      // If no parent directory specified, find user's root directory
      if (parentId == null) {
        final rootDir = await supabase
            .from('directories')
            .select('id')
            .eq('user_id', userId)
            .filter(
                  'parent_id',
                  'is',
                  null,
                ) 
            .single();
        parentId = rootDir['id'];
      }

      // Create directory
      final response = await supabase.from('directories').insert({
        'user_id': userId,
        'parent_id': parentId,
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
        'modified_at': DateTime.now().toIso8601String(),
        'author': userId,
        'starred': false,
        'sharing': 'private'
      }).select();

      // Update user's directory count
      await supabase.rpc('increment_directory_count', params: {'user_id': userId});

      return response[0]['id'];
    } catch (e) {
      throw Exception('Failed to create directory: $e');
    }
  }

  // Get directories and files in a directory
  Future<Map<String, dynamic>> getDirectoryContents(int directoryId) async {
    try {
      final directories = await supabase
          .from('directories')
          .select()
          .eq('parent_id', directoryId);

      final files = await supabase
          .from('files')
          .select()
          .eq('directory_id', directoryId);

      return {
        'directories': directories,
        'files': files,
      };
    } catch (e) {
      throw Exception('Failed to get directory contents: $e');
    }
  }

  // Move a file to a different directory
  Future<void> moveFile(int fileId, int newDirectoryId) async {
    try {
      await supabase.from('files').update({
        'directory_id': newDirectoryId,
        'modified_at': DateTime.now().toIso8601String(),
      }).eq('id', fileId);
    } catch (e) {
      throw Exception('Failed to move file: $e');
    }
  }
}