import 'package:supabase_flutter/supabase_flutter.dart';

class UserManagementService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<void> createUserRecord(String email) async {
    try {
      // Get the current authenticated user's UUID
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('No authenticated user');

      // Create user record
      await supabase.from('users').insert({
        'id': userId, // Supabase auth UUID
        'name': email.split('@')[0],
        'email': email,
        'member_type': 'free',
        'total_space': (10 * 1024 * 1024 * 1024), // 10GB in bytes
        'used_space': 0,
        'file_count': 0,
        'directory_count': 0,
      });

      await createRootDirectory(userId);
    } catch (e) {
      throw Exception('Failed to create user record: $e');
    }
  }

  Future<void> createRootDirectory(String userId) async {
    try {
      await supabase.from('directories').insert({
        'user_id': userId,
        'parent_id': null,
        'name': 'My Files',
        'author': userId,
        'starred': false,
        'sharing': 'private',
        'file_count': 0,
        'total_size': 0,
      });
    } catch (e) {
      throw Exception('Failed to create root directory: $e');
    }
  }

  Future<void> updateUserFileStats(String userId, int fileSize) async {
    try {
      final result =
          await supabase
              .from('users')
              .select('used_space, file_count')
              .eq('id', userId)
              .single();

      final int currentUsedSpace = result['used_space'] ?? 0;
      final int newUsedSpace = currentUsedSpace + fileSize;
      final int newFileCount = (result['file_count'] ?? 0) + 1;

      await supabase
          .from('users')
          .update({'used_space': newUsedSpace, 'file_count': newFileCount})
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to update user stats: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserRecord(String email) async {
    try {
      return await supabase.from('users').select().eq('email', email).single();
    } catch (e) {
      return null;
    }
  }
}
