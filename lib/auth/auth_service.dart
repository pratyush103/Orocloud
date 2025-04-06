import 'dart:convert';

import 'package:orocloud/services/user_management_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final UserManagementService _managementService = UserManagementService();

  Future<void> signInWithEmailPassword(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Login failed - no user returned');
      }

      if (response.session == null) {
        throw Exception('Login failed - no session created');
      }

      await _saveSession(response.session!);

      final userRecord = await _managementService.getUserRecord(email);

      if (userRecord == null) {
        await _managementService.createUserRecord(email);
      }
    } catch (e) {
      print('Login error: $e');
      throw Exception('Login failed: $e');
    }
  }

  Future<void> signUpWithEmailPassword(String email, String password) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Signup failed - no user returned');
      }

      if (response.session == null) {
        throw Exception('Please check your email to confirm your account');
      }

      await _saveSession(response.session!);
      await _managementService.createUserRecord(email);
    } catch (e) {
      print('Sign up error: $e');
      throw Exception('Sign up failed: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw Exception("Failed to send reset email: $e");
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final response = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'https://rkeubgdoirploxifyjmn.supabase.co/auth/v1/callback',
      );
    } catch (e) {
      throw Exception("Google sign-in failed: $e");
    }
  }

  Future<void> handleAuthChange() async {
    final Session? session = _supabase.auth.currentSession;
    final User? user = _supabase.auth.currentUser;

    if (session != null && user != null) {
      await _saveSession(session);

      final userRecord = await _managementService.getUserRecord(
        user.email ?? '',
      );

      if (userRecord == null) {
        await _managementService.createUserRecord(user.email ?? '');
      }
    }
  }

  void listenToAuthChanges() {
    _supabase.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.userUpdated) {
        if (session != null) {
          await _saveSession(session);

          final User? user = data.session?.user ?? _supabase.auth.currentUser;
          if (user != null) {
            try {
              final userRecord = await _managementService.getUserRecord(
                user.email ?? '',
              );

              if (userRecord == null) {
                await _managementService.createUserRecord(
                  user.email ?? 'unknown@email.com',
                );
                print('Created new user record for email: ${user.email}');
              }
            } catch (e) {
              print('Error in auth state change handler: $e');
            }
          }
        }
      }
    });
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    await _clearSession();
  }

  String? getUserEmail() {
    return _supabase.auth.currentUser?.email;
  }

  Future<void> _saveSession(Session session) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionJson = jsonEncode(session.toJson());
    await prefs.setString('session', sessionJson);
  }

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionString = prefs.getString('session');

    if (sessionString != null) {
      final sessionData = jsonDecode(sessionString);
      final session = Session.fromJson(sessionData);
      await _supabase.auth.setSession(session?.accessToken ?? '');
    }
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session');
  }
}
