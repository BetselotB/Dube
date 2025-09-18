import 'package:dube/config.dart';
import 'package:dube/l10n/app_localizations.dart';
import 'package:dube/pages/homepage/homepage.dart';
import 'package:dube/pages/paywall/paywall_page.dart';
import 'package:dube/services/trial_service.dart';
import 'package:dube/services/auth_services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

enum AuthMode { login, signup }

class _AuthPageState extends State<AuthPage> {
  AuthMode _mode = AuthMode.login;

  final AuthService _authService = AuthService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _submit(AppLocalizations t) async {
    final email = _emailController.text.trim();
    final pass = _passwordController.text;
    final confirm = _confirmController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty ||
        pass.isEmpty ||
        (_mode == AuthMode.signup && (name.isEmpty || confirm.isEmpty))) {
      _showSnack(t.fillAllFields);
      return;
    }
    if (_mode == AuthMode.signup && pass != confirm) {
      _showSnack(t.passwordsDontMatch);
      return;
    }

    setState(() => _loading = true);
    try {
      if (_mode == AuthMode.login) {
        // login
        final userCred = await _authService.signInWithEmail(
          email: email,
          password: pass,
        );
        final user = userCred.user;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'lastLogin': FieldValue.serverTimestamp()});
        }
        _showSnack(t.loginSuccessful);
      } else {
        // signup
        final userCred = await _authService.signUpWithEmail(
          email: email,
          password: pass,
          displayName: name,
        );

        final user = userCred.user;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'uid': user.uid,
                'name': name,
                'email': email,
                'createdAt': FieldValue.serverTimestamp(),
                'lastLogin': FieldValue.serverTimestamp(),
                'provider': 'email',
              });
        }
        _showSnack(t.signupSuccessful);
      }

      // ✅ After successful auth, evaluate trial and route accordingly
      if (!mounted) return;
      final locked = await TrialService.evaluateAndPersist();
      if (!mounted) return;
      if (locked) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PaywallPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Auth error');
    } catch (e) {
      _showSnack('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn(AppLocalizations t) async {
    setState(() => _loading = true);
    try {
      final userCred = await _authService.signInWithGoogle(
        serverClientId: kGoogleWebClientId,
      );

      if (userCred == null) {
        _showSnack(t.googleSignInCancelled);
      } else {
        final user = userCred.user;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'uid': user.uid,
                'name': user.displayName ?? '',
                'email': user.email,
                'photoURL': user.photoURL,
                'createdAt': FieldValue.serverTimestamp(),
                'lastLogin': FieldValue.serverTimestamp(),
                'provider': 'google',
              }, SetOptions(merge: true)); // merge to not overwrite
        }

        _showSnack(t.googleSignInSuccess);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Google sign-in failed');
    } catch (e) {
      _showSnack('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      body: Stack(
        children: [
          Container(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 28,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t.appTitle,
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _buildModeButton(AuthMode.login, t.login),
                            _buildModeButton(AuthMode.signup, t.signup),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              if (_mode == AuthMode.signup) ...[
                                _buildTextField(
                                  controller: _nameController,
                                  hint: t.name,
                                ),
                                const SizedBox(height: 12),
                              ],
                              _buildTextField(
                                controller: _emailController,
                                hint: t.email,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 12),
                              _buildTextField(
                                controller: _passwordController,
                                hint: t.password,
                                obscure: _obscure,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              if (_mode == AuthMode.signup) ...[
                                const SizedBox(height: 12),
                                _buildTextField(
                                  controller: _confirmController,
                                  hint: t.confirmPassword,
                                  obscure: _obscure,
                                ),
                              ],
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : () => _submit(t),
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    _mode == AuthMode.login
                                        ? t.login
                                        : t.createAccount,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(color: Colors.grey.shade300),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Text(
                                      t.or,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(color: Colors.grey.shade300),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: OutlinedButton.icon(
                                  onPressed: _loading
                                      ? null
                                      : () => _googleSignIn(t),
                                  icon: Image.network(
                                    'https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg',
                                    width: 20,
                                    height: 20,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.login, size: 20),
                                  ),
                                  label: Text(t.continueWithGoogle),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                t.termsHint,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black45,
                                ),
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

          if (_loading)
            Container(
              color: const Color.fromRGBO(0, 0, 0, 0.25),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildModeButton(AuthMode mode, String label) {
    final active = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (mounted) setState(() => _mode = mode);
        },
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
