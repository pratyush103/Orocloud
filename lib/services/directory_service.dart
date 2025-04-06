import 'package:supabase_flutter/supabase_flutter.dart';

class DirectoryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> getDirectoryContents(int? directoryId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Fix: Query syntax for Supabase Flutter
      final directories = await _supabase
          .from('directories')
          .select()
          .eq('user_id', userId)
          .eq(
            directoryId != null ? 'parent_id' : 'parent_id',
            (directoryId ?? null) as Object,
          )
          .order('created_at')
          .then((data) => data as List<dynamic>);

      // Fix: Query syntax for Supabase Flutter
      final files = await _supabase
          .from('files')
          .select()
          .eq('user_id', userId)
          .eq(
            directoryId != null ? 'parent_id' : 'parent_id',
            (directoryId ?? null) as Object,
          )
          .order('created_at', ascending: false)
          .then((data) => data as List<dynamic>);

      return {'directories': directories, 'files': files};
    } catch (e) {
      throw Exception('Failed to fetch directory contents: $e');
    }
  }

  Future<void> createDirectory(String name, int? parentId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Fix: Insert syntax for Supabase Flutter
      await _supabase.from('directories').insert({
        'user_id': userId,
        'parent_id': parentId,
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
        'modified_at': DateTime.now().toIso8601String(),
        'author': userId,
        'starred': false,
        'sharing': 'private',
        'file_count': 0,
        'total_size': 0,
      });

      // Fix: RPC call syntax for Supabase Flutter
      await _supabase.rpc(
        'update_user_directory_count',
        params: {'uid': userId, 'count_change': 1},
      );
    } catch (e) {
      throw Exception('Failed to create directory: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getBreadcrumbPath(int? directoryId) async {
    if (directoryId == null) {
      return [
        {"name": "My Files", "id": null},
      ];
    }

    try {
      List<Map<String, dynamic>> breadcrumbs = [];
      int? currentDirId = directoryId;

      while (currentDirId != null) {
        // Fix: Query syntax for Supabase Flutter
        final response =
            await _supabase
                .from('directories')
                .select('id, name, parent_id')
                .eq('id', currentDirId)
                .single();

        final directory = response as Map<String, dynamic>;

        breadcrumbs.insert(0, {
          "name": directory['name'],
          "id": directory['id'],
        });

        currentDirId = directory['parent_id'] as int?;
      }

      breadcrumbs.insert(0, {"name": "My Files", "id": null});
      return breadcrumbs;
    } catch (e) {
      throw Exception('Failed to get breadcrumb path: $e');
    }
  }
}
