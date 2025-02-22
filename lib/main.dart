import 'package:flutter/material.dart';
import 'package:orocloud/pages/document_scanner_page.dart';
import 'package:orocloud/pages/login_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orocloud/pages/document_scanner_page.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://rkeubgdoirploxifyjmn.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJrZXViZ2RvaXJwbG94aWZ5am1uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk2OTE4ODQsImV4cCI6MjA1NTI2Nzg4NH0.uwUz7nlwtPtVoVRpv7US-1PFTdjh3y_QCvw8Hi6Ky-g',
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthGate(),
    );
  }
}

// Authentication Check
class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return user == null ? LoginPage() : DocumentScannerPage();
  }
}
