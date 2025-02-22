import 'package:flutter/material.dart';
        import '../auth/auth_service.dart';
        import 'package:orocloud/pages/login_page.dart';

        class ProfilePage extends StatefulWidget {
          const ProfilePage({super.key});

          @override
          State<ProfilePage> createState() => _ProfilePageState();
        }

        class _ProfilePageState extends State<ProfilePage> {
          String? _userEmail;

          @override
          void initState() {
            super.initState();
            _loadUserEmail();
          }

          Future<void> _loadUserEmail() async {
            final authService = AuthService();
            setState(() {
              _userEmail = authService.getUserEmail();
            });
          }

          @override
          Widget build(BuildContext context) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Profile'),
                actions: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      final authService = AuthService();
                      await authService.signOut();
                      if (mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginPage()),
                          (_) => false,
                        );
                      }
                    },
                  ),
                ],
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (_userEmail != null)
                      Text('Email: $_userEmail', style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        final authService = AuthService();
                        await authService.signOut();
                        if (mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginPage()),
                            (_) => false,
                          );
                        }
                      },
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              ),
            );
          }
        }