import 'package:flutter/material.dart';

import '../auth/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false; // Added missing variable
  String? _message;
  Color? _messageColor;
  int _failedAttempts = 0; // Tracks failed login attempts

  void signIn() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        throw Exception("All fields are required");
      }

      if (!_isValidEmail(email)) {
        throw Exception("Invalid Email Format");
      }

      await authService.signInWithEmailPassword(email, password);

      if (mounted) {
        _failedAttempts = 0;
        _showMessage("Login successful!", Colors.greenAccent);
        Navigator.pushReplacementNamed(context, '/drive');
      }
    } catch (e) {
      if (mounted) {
        _failedAttempts++;
        _showMessage(e.toString(), Colors.redAccent);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      await authService.signInWithGoogle();
      // Call handleAuthChange after OAuth sign-in
      await authService.handleAuthChange();

      if (mounted) {
        _showMessage("Google Sign-In Successful!", Colors.greenAccent);
        Navigator.pushReplacementNamed(context, '/drive');
      }
    } catch (e) {
      if (mounted) {
        _showMessage("Google Sign-In Failed: $e", Colors.redAccent);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  void _showMessage(String message, Color color) {
    setState(() {
      _message = message;
      _messageColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final Color backgroundColor =
        isDarkMode ? const Color(0xFF2E2E2E) : Colors.grey[50]!;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color hintColor = isDarkMode ? Colors.grey[300]! : Colors.grey[700]!;
    final Color inputFieldColor = isDarkMode ? Colors.grey[800]! : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Logo & Title
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.cloud, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                "Orocloud",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Text(
                "Secure cloud storage for everyone",
                style: TextStyle(fontSize: 14, color: hintColor),
              ),
              const SizedBox(height: 32),

              // Email Input
              _buildInputField(
                controller: _emailController,
                hintText: "Enter your email",
                icon: Icons.mail_outline,
                isDarkMode: isDarkMode,
                inputFieldColor: inputFieldColor,
                textColor: textColor,
              ),
              const SizedBox(height: 16),

              // Password Input
              _buildInputField(
                controller: _passwordController,
                hintText: "Enter your password",
                icon: Icons.lock_outline,
                isDarkMode: isDarkMode,
                inputFieldColor: inputFieldColor,
                textColor: textColor,
                obscureText: _obscurePassword,
                onToggle:
                    () => setState(() => _obscurePassword = !_obscurePassword),
              ),

              const SizedBox(height: 8),

              // Success/Error Message
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _message!,
                    style: TextStyle(color: _messageColor, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Forgot Password (Only shown after 3 failed attempts)
              if (_failedAttempts >= 3)
                TextButton(
                  onPressed: () {
                    _showMessage(
                      "Password reset email sent",
                      Colors.greenAccent,
                    );
                    try {
                      authService.resetPassword(_emailController.text.trim());
                    } catch (e) {
                      _showMessage(
                        "Failed to send password reset email",
                        Colors.redAccent,
                      );
                    }
                  },
                  child: const Text(
                    "Forgot Password?",
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Sign In Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : signIn, // Disable when loading
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    disabledBackgroundColor: Colors.blue.withOpacity(0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 5,
                    shadowColor: Colors.blue.withOpacity(0.3),
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            "Sign In",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                ),
              ),
              const SizedBox(height: 16),

              // Divider Line with Text
              Row(
                children: [
                  Expanded(child: Divider(color: hintColor)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      "Or continue with",
                      style: TextStyle(color: hintColor, fontSize: 14),
                    ),
                  ),
                  Expanded(child: Divider(color: hintColor)),
                ],
              ),
              const SizedBox(height: 16),

              // Google Sign-In Button
              _buildGoogleSignInButton(),

              const SizedBox(height: 24),

              // Sign Up Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account?",
                    style: TextStyle(color: hintColor),
                  ),
                  TextButton(
                    onPressed:
                        () => Navigator.pushNamed(context, '/register_page'),
                    child: const Text(
                      "Sign Up",
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required bool isDarkMode,
    required Color inputFieldColor,
    required Color textColor,
    bool obscureText = false,
    VoidCallback? onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      cursorColor: Colors.blue,
      decoration: InputDecoration(
        labelText: hintText,
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.white70 : Colors.black54,
        ),
        prefixIcon: Icon(icon, color: textColor),
        suffixIcon:
            onToggle != null
                ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: textColor,
                  ),
                  onPressed: onToggle,
                )
                : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: inputFieldColor,
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blue, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      style: TextStyle(color: textColor),
    );
  }

  Widget _buildGoogleSignInButton() {
    return ElevatedButton.icon(
      onPressed: signInWithGoogle,
      icon: Image.asset('assets/google_logo.png', height: 24),
      label: const Text("Continue with Google", style: TextStyle(fontSize: 16)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        minimumSize: const Size(double.infinity, 50),
      ),
    );
  }
}
