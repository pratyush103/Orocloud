import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Sign in with Email & Password
  Future<void> signInWithEmailPassword(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.session != null) {
      await _saveSession(response.session!);
    }
  }

  // Sign Up with Email & Password
  Future<void> signUpWithEmailPassword(String email, String password) async {
    await _supabase.auth.signUp(email: email, password: password);
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
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo:
          'https://rkeubgdoirploxifyjmn.supabase.co/auth/v1/callback', //` Change this to your deep link
    );
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
