import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_service.dart';
import '../pages/login_page.dart';
import '../pages/profile_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final authService = AuthService();

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  // Restore session on app startup
  Future<void> _restoreSession() async {
    await authService.restoreSession();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      // Listen for auth state changes
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Check if session is valid
        final session = Supabase.instance.client.auth.currentSession;
        return session == null ? const LoginPage() : const ProfilePage();
      },
    );
  }
}
