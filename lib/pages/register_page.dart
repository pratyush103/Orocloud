import 'package:flutter/material.dart';
import '../auth/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _message;
  Color? _messageColor;

  void signUp() async {
    setState(() {
      _message = null; // Reset message
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showMessage("All fields are required", Colors.redAccent);
      return;
    }
    if (!_isValidEmail(email)) {
      _showMessage("Invalid Email Format", Colors.redAccent);
      return;
    }
    if (password.length < 6) {
      _showMessage("Password must be at least 6 characters", Colors.redAccent);
      return;
    }
    if (password != confirmPassword) {
      _showMessage("Passwords do not match", Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await authService.signUpWithEmailPassword(email, password);
      if (mounted) {
        _showMessage("Registration successful!", Colors.greenAccent);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        _showMessage("An account with this email already exists.", Colors.redAccent);
      }
    }
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
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
    final bool isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final Color backgroundColor = isDarkMode ? const Color(0xFF2E2E2E) : Colors.grey[50]!;
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
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
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
                hintText: "Create a password",
                icon: Icons.lock_outline,
                isDarkMode: isDarkMode,
                inputFieldColor: inputFieldColor,
                textColor: textColor,
                obscureText: _obscurePassword,
                onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              const SizedBox(height: 16),

              // Confirm Password Input
              _buildInputField(
                controller: _confirmPasswordController,
                hintText: "Confirm your password",
                icon: Icons.lock_outline,
                isDarkMode: isDarkMode,
                inputFieldColor: inputFieldColor,
                textColor: textColor,
                obscureText: _obscureConfirmPassword,
                onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
              const SizedBox(height: 16),

              // Success/Error Message
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _message!,
                    style: TextStyle(color: _messageColor, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Sign Up Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 5,
                    shadowColor: Colors.blue.withOpacity(0.3),
                  ),
                  child: const Text(
                    "Sign Up",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Sign In Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Already have an account?", style: TextStyle(color: hintColor)),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Sign In", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
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
      cursorColor: Colors.blue, // Ensures blue cursor color
      decoration: InputDecoration(
        labelText: hintText,
        labelStyle: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
        prefixIcon: Icon(icon, color: textColor),
        suffixIcon: onToggle != null
            ? IconButton(
          icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: textColor),
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
}
