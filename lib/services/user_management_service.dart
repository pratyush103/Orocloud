// lib/services/user_management_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class UserManagementService {
  final SupabaseClient supabase = Supabase.instance.client;

  // Create a user entry in the users table when a new user registers
  Future<void> createUserRecord(String userId, String email) async {
    try {
      // Make sure your users table is using uuid type for user_id, not bigint
      await Supabase.instance.client.from('users').insert({
        'id': userId, // Changed from user_id to id if that's your column name
        'email': email,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'username': email.split('@')[0], // Default username from email
        'storage_used': 0,
        'storage_limit': 10 * 1024 * 1024 * 1024, // 10GB default
        'premium': false,
      });

      // Create root directory for user
      await createRootDirectory(userId);
    } catch (e) {
      print('Error creating user record: $e');
      throw Exception('Failed to create user record: $e');
    }
  }

  // Create root directory for a new user
  Future<void> createRootDirectory(String userId) async {
    try {
      await supabase.from('directories').insert({
        'user_id': userId,
        'parent_id': null, // Root has no parent
        'name': 'My Files',
        'created_at': DateTime.now().toIso8601String(),
        'modified_at': DateTime.now().toIso8601String(),
        'author': userId,
        'starred': false,
        'sharing': 'private',
      });

      // Update directory count
      await supabase.rpc(
        'increment_directory_count',
        params: {'user_id': userId},
      );
    } catch (e) {
      throw Exception('Failed to create root directory: $e');
    }
  }

  // Update user stats when a file is added
  Future<void> updateUserFileStats(String userId, int fileSize) async {
    try {
      // Get current stats
      final result =
          await supabase
              .from('users')
              .select('used_space, file_count')
              .eq('id', userId)
              .single();

      // Calculate new values
      final currentUsedSpace = int.parse(result['used_space'] ?? '0');
      final newUsedSpace = currentUsedSpace + fileSize;
      final newFileCount = (result['file_count'] ?? 0) + 1;

      // Update user record
      await supabase
          .from('users')
          .update({
            'used_space': newUsedSpace.toString(),
            'file_count': newFileCount,
            'last_login': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to update user stats: $e');
    }
  }

  // Retrieve a user record from the users table
  Future<Map<String, dynamic>?> getUserRecord(String userId) async {
    try {
      final result =
          await supabase.from('users').select().eq('id', userId).single();

      return result;
    } catch (e) {
      // Return null if the user record does not exist
      return null;
    }
  }
}
