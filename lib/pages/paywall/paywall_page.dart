import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dube/pages/homepage/homepage.dart';
import 'package:dube/services/payment_verifier.dart';

class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key});

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  final _refCtrl = TextEditingController();
  final _suffixCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  PaymentMethod _method = PaymentMethod.telebirr;
  bool _loading = false;
  final _verifier = const PaymentVerifierService();

  @override
  void dispose() {
    _refCtrl.dispose();
    _suffixCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyAndActivate() async {
    final reference = _refCtrl.text.trim();
    final suffix = _suffixCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (reference.isEmpty && _method != PaymentMethod.image) {
      _showSnack('Please enter a reference/receipt number');
      return;
    }

    setState(() => _loading = true);
    try {
      // Prevent re-use: build a normalized key and check if already used
      final refKey = _buildRefKey(
        method: _method,
        reference: reference,
        suffix: suffix,
        phone: phone,
      );

      if (refKey != null) {
        final refDoc = await FirebaseFirestore.instance
            .collection('paymentRefs')
            .doc(refKey)
            .get();
        if (refDoc.exists) {
          _showSnack('This payment reference appears to be already used');
          setState(() => _loading = false);
          return;
        }
      }

      Map<String, dynamic> payload = {};
      switch (_method) {
        case PaymentMethod.telebirr:
          payload = {"reference": reference};
          break;
        case PaymentMethod.cbe:
          if (suffix.isEmpty) {
            _showSnack('Please enter CBE account suffix');
            setState(() => _loading = false);
            return;
          }
          payload = {"reference": reference, "suffix": suffix};
          break;
        case PaymentMethod.dashen:
          payload = {"reference": reference};
          break;
        case PaymentMethod.abyssinia:
          if (suffix.isEmpty) {
            _showSnack('Please enter Abyssinia account suffix');
            setState(() => _loading = false);
            return;
          }
          payload = {"reference": reference, "suffix": suffix};
          break;
        case PaymentMethod.cbebirr:
          if (phone.isEmpty) {
            _showSnack('Please enter phone number for CBE Birr');
            setState(() => _loading = false);
            return;
          }
          payload = {"receiptNumber": reference, "phoneNumber": phone};
          break;
        case PaymentMethod.image:
          _showSnack('Image verification not implemented yet');
          setState(() => _loading = false);
          return;
      }

      final result = await _verifier.verify(method: _method, payload: payload);
      if (!result.success) {
        _showSnack(result.message ?? 'Verification failed');
        setState(() => _loading = false);
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnack('No user signed in');
        setState(() => _loading = false);
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'paymentStatus': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Mark reference as used (idempotent). If this fails due to race, next runs will see it.
      if (refKey != null) {
        await FirebaseFirestore.instance
            .collection('paymentRefs')
            .doc(refKey)
            .set({
              'usedBy': user.uid,
              'method': _method.name,
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: false));
      }

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Create a unique, normalized key for a payment reference per method.
  // Includes suffix or phone when required so keys are method-specific.
  String? _buildRefKey({
    required PaymentMethod method,
    required String reference,
    String? suffix,
    String? phone,
  }) {
    if (method == PaymentMethod.image)
      return null; // image flow not implemented
    String norm(String s) => s.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final parts = <String>['m:${method.name}', 'r:${norm(reference)}'];
    if (method == PaymentMethod.cbe || method == PaymentMethod.abyssinia) {
      if (suffix != null && suffix.isNotEmpty) parts.add('s:${norm(suffix)}');
    }
    if (method == PaymentMethod.cbebirr) {
      if (phone != null && phone.isNotEmpty) parts.add('p:${norm(phone)}');
    }
    return parts.join('|');
  }

  @override
  Widget build(BuildContext context) {
    final color = Colors.deepPurple;
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.85)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.workspace_premium_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Go Premium',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your free access has ended. Unlock unlimited access with a yearly plan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    children: [
                      // Price card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Yearly',
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.lock_outline,
                                    color: Colors.grey.shade600,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: const [
                                  Text('', style: TextStyle(fontSize: 0)),
                                ],
                              ),
                              // Placeholder for future price; keeping layout clean
                              const Text(
                                '1 year full access',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 14),
                              _FeatureRow(
                                icon: Icons.check_circle,
                                text: 'Unlimited people and dubes',
                              ),
                              _FeatureRow(
                                icon: Icons.check_circle,
                                text: 'Cloud backup & restore',
                              ),
                              _FeatureRow(
                                icon: Icons.check_circle,
                                text: 'Priority updates',
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Benefits list
                      Card(
                        elevation: 0,
                        color: Colors.grey.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Why upgrade?',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 10),
                              _Bullet(
                                text:
                                    'Keep your history safe with cloud backups',
                              ),
                              _Bullet(
                                text: 'Track without limits all year long',
                              ),
                              _Bullet(text: 'Support ongoing development'),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Method selection and inputs
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Choose payment method',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<PaymentMethod>(
                                value: _method,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: PaymentMethod.telebirr,
                                    child: Text('Telebirr (reference)'),
                                  ),
                                  DropdownMenuItem(
                                    value: PaymentMethod.cbe,
                                    child: Text(
                                      'CBE (reference + account suffix)',
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: PaymentMethod.dashen,
                                    child: Text('Dashen (reference)'),
                                  ),
                                  DropdownMenuItem(
                                    value: PaymentMethod.abyssinia,
                                    child: Text(
                                      'Abyssinia (reference + suffix)',
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: PaymentMethod.cbebirr,
                                    child: Text(
                                      'CBE Birr (receipt + phone number)',
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: PaymentMethod.image,
                                    child: Text(
                                      'Upload receipt image (coming soon)',
                                    ),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => _method = v);
                                },
                              ),
                              const SizedBox(height: 14),
                              if (_method != PaymentMethod.image) ...[
                                TextField(
                                  controller: _refCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Reference / Receipt number',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (_method == PaymentMethod.cbe ||
                                  _method == PaymentMethod.abyssinia) ...[
                                TextField(
                                  controller: _suffixCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Account suffix',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (_method == PaymentMethod.cbebirr) ...[
                                TextField(
                                  controller: _phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: 'Phone number',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton.icon(
                                  onPressed: _loading
                                      ? null
                                      : _verifyAndActivate,
                                  icon: _loading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.verified),
                                  label: Text(
                                    _loading
                                        ? 'Verifying...'
                                        : 'Verify payment',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      Text(
                        'Verification powered by Verify API',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
