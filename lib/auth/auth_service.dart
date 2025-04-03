import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orocloud/services/user_management_service.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final UserManagementService _managementService = UserManagementService();

  // Sign in with Email & Password
  Future<void> signInWithEmailPassword(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.session != null) {
      await _saveSession(response.session!);

      // Retrieve user information
      final userId = response.user!.id;
      final userRecord = await _managementService.getUserRecord(userId);

      // If user record does not exist, create it
      if (userRecord == null) {
        await _managementService.createUserRecord(userId, email);
      }
    }
  }

  // Improved signUpWithEmailPassword method
  Future<void> signUpWithEmailPassword(String email, String password) async {
    try {
      // Check if user already exists by attempting to sign in
      try {
        await _supabase.auth.signInWithOtp(email: email);
        // If we reach here, the user exists
        throw Exception('User with this email already exists');
      } catch (e) {
        // If error is not about existing user, rethrow
        if (!e.toString().contains('Email not confirmed')) {
          rethrow;
        }
      }

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        if (response.session != null) {
          await _saveSession(response.session!);
        }

        // Create user record in the database with delay to ensure auth is complete
        final userId = response.user!.id;
        await Future.delayed(const Duration(milliseconds: 500));
        await _managementService.createUserRecord(userId, email);
      }
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

  // Google Sign-In using Supabase OAuth
  Future<void> signInWithGoogle() async {
    try {
      final response = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo:
            'https://rkeubgdoirploxifyjmn.supabase.co/auth/v1/callback', //` Change this to your deep link
      );

      // Note: For OAuth flows, we need to handle user record creation after redirect
      // This will be managed by checking auth changes
    } catch (e) {
      throw Exception("Google sign-in failed: $e");
    }
  }

  // Handle authentication state changes
  Future<void> handleAuthChange() async {
    final Session? session = _supabase.auth.currentSession;
    final User? user = _supabase.auth.currentUser;

    if (session != null && user != null) {
      await _saveSession(session);

      // Retrieve user information
      final userId = user.id;
      final userRecord = await _managementService.getUserRecord(userId);

      // If user record does not exist, create it
      if (userRecord == null) {
        await _managementService.createUserRecord(userId, user.email ?? '');
      }
    }
  }

  // Improved listenToAuthChanges method
  void listenToAuthChanges() {
    _supabase.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      // Handle different auth events
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.userUpdated) {
        if (session != null) {
          await _saveSession(session);

          // Get user data
          final User? user = data.session?.user ?? _supabase.auth.currentUser;
          if (user != null) {
            try {
              // Check if user record exists
              final userRecord = await _managementService.getUserRecord(
                user.id,
              );

              // Create user record if it doesn't exist
              if (userRecord == null) {
                await _managementService.createUserRecord(
                  user.id,
                  user.email ?? 'unknown@email.com',
                );
                print('Created new user record for ID: ${user.id}');
              }
            } catch (e) {
              print('Error in auth state change handler: $e');
            }
          }
        }
      }
    });
  }

  // Sign Out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    await _clearSession();
  }

  // Get Current User
  String? getUserEmail() {
    return _supabase.auth.currentUser?.email;
  }

  // Save session data to local storage
  Future<void> _saveSession(Session session) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionJson = jsonEncode(session.toJson()); // Convert session to JSON
    await prefs.setString('session', sessionJson);
  }

  // Restore session from local storage
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionString = prefs.getString('session');

    if (sessionString != null) {
      final sessionData = jsonDecode(sessionString);
      final session = Session.fromJson(
        sessionData,
      ); // Convert JSON back to ?Session
      await _supabase.auth.setSession(session?.accessToken ?? '');
    }
  }

  // Clear session from local storage
  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session');
  }
}
