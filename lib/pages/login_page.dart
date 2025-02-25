import 'package:flutter/material.dart';
import '../auth/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  void signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (!_isValidEmail(email)) {
      _showError("Invalid Email Format");
      return;
    }

    if (email.isEmpty || password.isEmpty) {
      _showError("Please fill in all fields");
      return;
    }

    try {
      await authService.signInWithEmailPassword(email, password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login successful!")),
        );
        Navigator.pushReplacementNamed(context, '/profile_page');
      }
    } catch (e) {
      if (mounted) {
        _showError("Incorrect Email or Password");
      }
    }
  }

  void signInWithGoogle() async {
    try {
      await authService.signInWithGoogle();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Google Sign-In Successful!")),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError("Google Sign-In Failed: $e");
      }
    }
  }

  bool _isValidEmail(String email) {
    final emailRegex =
    RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center, // Center align text inside the SnackBar
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating, // Make the snackbar float
        margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 20), // Adjust positioning
      ),
    );
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
            mainAxisAlignment: MainAxisAlignment.center,
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
                style: TextStyle(
                  fontSize: 14,
                  color: hintColor,
                ),
              ),
              const SizedBox(height: 32),

              // Email Input
              _buildTextField(
                controller: _emailController,
                hintText: "Enter your email",
                icon: Icons.mail_outline,
                isDarkMode: isDarkMode,
                inputFieldColor: inputFieldColor,
                textColor: textColor,
              ),
              const SizedBox(height: 16),

              // Password Input
              _buildPasswordField(
                controller: _passwordController,
                hintText: "Enter your password",
                obscureText: _obscurePassword,
                onToggle: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                isDarkMode: isDarkMode,
                inputFieldColor: inputFieldColor,
                textColor: textColor,
              ),
              const SizedBox(height: 24),

              // Sign In Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 5,
                    shadowColor: Colors.blue.withOpacity(0.3),
                  ),
                  child: const Text("Sign In",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),

              // Divider
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
              _buildGoogleSignInButton(isDarkMode),

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
                    onPressed: () {
                      Navigator.pushNamed(context, '/register_page');
                    },
                    child: const Text("Sign Up",
                        style: TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required bool isDarkMode,
    required Color inputFieldColor,
    required Color textColor,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: hintText,
        labelStyle:
        TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
        hintText: hintText,
        hintStyle:
        TextStyle(color: isDarkMode ? Colors.white54 : Colors.black45),
        prefixIcon: Icon(icon, color: textColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: inputFieldColor,
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      keyboardType: TextInputType.emailAddress,
      style: TextStyle(color: textColor),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool obscureText,
    required VoidCallback onToggle,
    required bool isDarkMode,
    required Color inputFieldColor,
    required Color textColor,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: hintText,
        labelStyle:
        TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
        hintText: hintText,
        hintStyle:
        TextStyle(color: isDarkMode ? Colors.white54 : Colors.black45),
        prefixIcon: Icon(Icons.lock_outline, color: textColor),
        suffixIcon: IconButton(
          icon: Icon(
              obscureText ? Icons.visibility_off : Icons.visibility,
              color: textColor),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: inputFieldColor,
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      style: TextStyle(color: textColor),
    );
  }

  Widget _buildGoogleSignInButton(bool isDarkMode) {
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
