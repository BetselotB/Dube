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
  static const double _requiredEtb = 1.0;
  static const String _requiredTelebirrLastTwoDigits = '53'; // Last 2 digits of your Telebirr number
  static const String _requiredTelebirrReceiverName = 'Betselot Bekele Yenesu'; // Your full name as registered with Telebirr

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

      // Validate amount and (for Telebirr) receiver account/phone
      final normalized = _normalizePaymentDetails(_method, result.data);
      final paidAmount = _parseEtbAmount(normalized['amount']?.toString());
      if (paidAmount == null || paidAmount < _requiredEtb) {
        _showSnack('Payment must be at least 200 ETB');
        setState(() => _loading = false);
        return;
      }
      if (_method == PaymentMethod.telebirr) {
        final rcvRaw = normalized['receiverAccountOrPhone']?.toString() ?? '';
        final receiverName = normalized['receiverName']?.toString() ?? '';
      
        // Check last 2 digits of phone number
        final lastTwoDigits = rcvRaw.length >= 2 
            ? rcvRaw.substring(rcvRaw.length - 2) 
            : '';
          
        // Check if payment was made to the correct receiver
        if (lastTwoDigits != _requiredTelebirrLastTwoDigits ||
            !receiverName.toLowerCase().contains(_requiredTelebirrReceiverName.toLowerCase())) {
          _showSnack('Payment verification failed. Please ensure you sent to the correct recipient.');
          setState(() => _loading = false);
          return;
        }  
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

      // Save normalized payment details under the user for auditing
      final paymentId =
          refKey ??
          (normalized['reference']?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString());
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('payments')
          .doc(paymentId)
          .set({
            'method': _method.name,
            'reference': normalized['reference'],
            'provider': normalized['provider'],
            'payerName': normalized['payerName'],
            'payerAccountOrPhone': normalized['payerAccountOrPhone'],
            'receiverName': normalized['receiverName'],
            'receiverAccountOrPhone': normalized['receiverAccountOrPhone'],
            'amount': normalized['amount'],
            'currency': normalized['currency'],
            'date': normalized['date'],
            'status': normalized['status'],
            'raw': result.data,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

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

  Map<String, dynamic> _normalizePaymentDetails(
    PaymentMethod method,
    Map<String, dynamic>? body,
  ) {
    final data = body ?? <String, dynamic>{};
    String provider = method.name;

    String? payerName;
    String? payerAccountOrPhone;
    String? receiverName;
    String? receiverAccountOrPhone;
    String? amount;
    String? currency;
    String? dateIso;
    String? reference;
    String? status;

    switch (method) {
      case PaymentMethod.telebirr:
        final d = data['data'] ?? data;
        provider = 'telebirr';
        payerName = d['payerName']?.toString();
        payerAccountOrPhone = d['payerTelebirrNo']?.toString();
        receiverName = d['creditedPartyName']?.toString();
        receiverAccountOrPhone = d['creditedPartyAccountNo']?.toString();
        status = d['transactionStatus']?.toString();
        reference = d['receiptNo']?.toString();
        dateIso = d['paymentDate']?.toString();
        amount = d['totalPaidAmount']?.toString();
        currency = amount?.contains('Birr') == true ? 'ETB' : null;
        break;
      case PaymentMethod.cbe:
        provider = 'cbe';
        payerName = data['payer']?.toString();
        payerAccountOrPhone = data['payerAccount']?.toString();
        receiverName = data['receiver']?.toString();
        receiverAccountOrPhone = data['receiverAccount']?.toString();
        reference = data['reference']?.toString();
        dateIso = data['date']?.toString();
        amount = data['amount']?.toString();
        currency = amount?.contains('ETB') == true ? 'ETB' : null;
        status = 'Completed';
        break;
      case PaymentMethod.dashen:
        provider = 'dashen';
        payerName = data['senderName']?.toString();
        payerAccountOrPhone = data['senderAccountNumber']?.toString();
        receiverName = data['receiverName']?.toString();
        receiverAccountOrPhone = data['creditAccount']?.toString();
        reference =
            data['transactionReference']?.toString() ??
            data['transferReference']?.toString();
        dateIso = data['transactionDate']?.toString();
        amount = data['total']?.toString();
        currency = 'ETB';
        status = 'Completed';
        break;
      case PaymentMethod.abyssinia:
        provider = 'abyssinia';
        final d = data['data'] ?? data;
        payerName = d['payer']?.toString();
        payerAccountOrPhone = d['payerAccount']?.toString();
        receiverName = d['receiver']?.toString();
        receiverAccountOrPhone = d['receiverAccount']?.toString();
        reference = d['reference']?.toString();
        dateIso = d['date']?.toString();
        amount = d['amount']?.toString();
        currency = 'ETB';
        status = d['success'] == true ? 'Completed' : 'Unknown';
        break;
      case PaymentMethod.cbebirr:
        provider = 'cbebirr';
        payerName = data['customerName']?.toString();
        payerAccountOrPhone = data['debitAccount']?.toString();
        receiverName = data['receiverName']?.toString();
        receiverAccountOrPhone = data['creditAccount']?.toString();
        reference =
            data['reference']?.toString() ?? data['orderId']?.toString();
        dateIso = data['transactionDate']?.toString();
        amount = data['paidAmount']?.toString() ?? data['amount']?.toString();
        currency = 'ETB';
        status = data['transactionStatus']?.toString();
        break;
      case PaymentMethod.image:
        provider = 'image';
        final d = data['details'] ?? data;
        payerName = d['payer']?.toString();
        payerAccountOrPhone = d['payerAccount']?.toString();
        receiverName = d['receiver']?.toString();
        receiverAccountOrPhone = d['receiverAccount']?.toString();
        reference = data['reference']?.toString() ?? d['reference']?.toString();
        dateIso = d['date']?.toString();
        amount = d['amount']?.toString();
        currency = 'ETB';
        status = (data['verified'] == true) ? 'Completed' : 'Unknown';
        break;
    }

    return {
      'provider': provider,
      'payerName': payerName,
      'payerAccountOrPhone': payerAccountOrPhone,
      'receiverName': receiverName,
      'receiverAccountOrPhone': receiverAccountOrPhone,
      'amount': amount,
      'currency': currency,
      'date': dateIso,
      'reference': reference,
      'status': status,
    };
  }

  // Parse ETB amount across string formats (e.g., "101.00 Birr", "3,000.00 ETB", 73000)
  double? _parseEtbAmount(String? value) {
    if (value == null || value.isEmpty) return null;
    final asNum = double.tryParse(value);
    if (asNum != null) return asNum;
    final cleaned = value
        .replaceAll('ETB', '')
        .replaceAll('Birr', '')
        .replaceAll(',', '')
        .trim();
    final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(cleaned);
    return match != null ? double.tryParse(match.group(0)!) : null;
  }

  // Normalize Ethiopian phone to 2519XXXXXXXX when possible
  String _normalizeMsisdn(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('251')) return digits;
    if (digits.startsWith('0') && digits.length >= 10)
      return '251${digits.substring(1)}';
    if (digits.startsWith('9') && digits.length == 9) return '251$digits';
    return digits;
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
