// lib/pages/auth_page.dart
import 'package:flutter/material.dart';

class AuthPage extends StatefulWidget {
  final String languageCode; // 'en' or 'am'

  const AuthPage({super.key, required this.languageCode});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

enum AuthMode { login, signup }

class _AuthPageState extends State<AuthPage> {
  AuthMode _mode = AuthMode.login;

  // simple controllers (logic to be added later)
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscure = true;

  // simple localized strings (expand later)
  String t(String en, String am) => widget.languageCode == 'am' ? am : en;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    // UI-only: show a snackbar to signify "would attempt auth"
    final action = _mode == AuthMode.login ? t('Logging in', 'ይግቡ') : t('Creating account', 'መለያ እየፈጠረ');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$action...')));
    // connect your auth logic here later
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use gentle background gradient for a modern, friendly look
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Text(
                    'ዱቤ',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple.shade700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Segmented control for login / signup
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _buildModeButton(AuthMode.login, t('Login', 'ግባ')),
                        _buildModeButton(AuthMode.signup, t('Sign up', 'መመዝገብ')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Card with form
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _emailController,
                            hint: t('Email', 'ኢሜይል'),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _passwordController,
                            hint: t('Password', 'የይለፍ ቃል'),
                            obscure: _obscure,
                            suffix: IconButton(
                              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          if (_mode == AuthMode.signup) ...[
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _confirmController,
                              hint: t('Confirm password', 'የይለፍ ቃልን ያረጋግጡ'),
                              obscure: _obscure,
                            ),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(_mode == AuthMode.login ? t('Login', 'ግባ') : t('Create account', 'መግባት')),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.grey.shade300)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(t('or', 'ወይም'), style: TextStyle(color: Colors.black54)),
                              ),
                              Expanded(child: Divider(color: Colors.grey.shade300)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Social / placeholder button(s)
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(t('Google sign-in placeholder', 'Google ግንኙነት'))));
                              },
                              icon: Image.network(
                                'https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg',
                                width: 20,
                                height: 20,
                                errorBuilder: (_, __, ___) => const Icon(Icons.login, size: 20),
                              ),
                              label: Text(t('Continue with Google', 'ከGoogle ይክናቸው')),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // small hint
                          Text(
                            t('By continuing you agree to our Terms & Privacy.', 'በመቀጠል የተግባር መመሪያዎቻችንን ታረጋግጣሉ።'),
                            style: const TextStyle(fontSize: 12, color: Colors.black45),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(AuthMode mode, String label) {
    final active = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              color: active ? Colors.deepPurple.shade700 : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }
}
