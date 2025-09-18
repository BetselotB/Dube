import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dube/components/step_instruction.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dube/l10n/app_localizations.dart';
import 'package:dube/pages/homepage/homepage.dart';
import 'package:dube/services/payment_verifier.dart' show PaymentVerifierService, PaymentMethod;

// Image picker instance
final ImagePicker _picker = ImagePicker();

class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key});

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  final _refCtrl = TextEditingController();
  final _suffixCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _verifier = const PaymentVerifierService();
  
  PaymentMethod _method = PaymentMethod.telebirr;
  File? _selectedImage;
  bool _loading = false;
  bool _extracting = false;
  String? _extractedReference;
  
  static const double _requiredEtb = 1.0;
  static const String _requiredTelebirrLastTwoDigits = '53'; // Last 2 digits of your Telebirr number
  static const String _requiredTelebirrReceiverName = 'Betselot Bekele Yenesu'; // Your full name as registered with Telebirr

  @override
  void dispose() {
    _refCtrl.dispose();
    _suffixCtrl.dispose();
    _phoneCtrl.dispose();
    // Ignore any errors when deleting the temporary image file
    _selectedImage?.delete().catchError((_) => Future<FileSystemEntity>.value(File('')));
    super.dispose();
  }


  Future<void> _verifyAndActivate() async {
    final reference = _refCtrl.text.trim();
    
    if (reference.isEmpty) {
      _showSnack(AppLocalizations.of(context)!.enterReferenceNumber);
      return;
    }
    
    // Use the reference to verify payment
    await _verifyPaymentWithReference(reference);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Save payment details to Firestore and update user status
  Future<void> _savePaymentAndUpdateUser(Map<String, dynamic> normalized, String? reference) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack(AppLocalizations.of(context)!.noUserSignedIn);
      return;
    }

    setState(() => _loading = true);
    
    try {
      // 1. Prevent re-use of payment references
      final refKey = _buildRefKey(
        method: _method,
        reference: reference ?? '',
        suffix: _suffixCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );

      if (refKey != null) {
        final refDoc = await FirebaseFirestore.instance
            .collection('paymentRefs')
            .doc(refKey)
            .get();
            
        if (refDoc.exists) {
          _showSnack(AppLocalizations.of(context)!.paymentReferenceAlreadyUsed);
          setState(() => _loading = false);
          return;
        }
      }

      // 2. Update user's payment status
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'paymentStatus': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Mark reference as used (idempotent)
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

      // 4. Save normalized payment details under the user for auditing
      final paymentId = refKey ?? 
          (normalized['reference']?.toString() ?? 
           DateTime.now().millisecondsSinceEpoch.toString());
           
      final paymentData = {
        'method': _method.name,
        'reference': normalized['reference'],
        'provider': normalized['provider'],
        'payerName': normalized['payerName'],
        'payerAccountOrPhone': normalized['payerAccountOrPhone'],
        'receiverName': normalized['receiverName'],
        'receiverAccountOrPhone': normalized['receiverAccountOrPhone'],
        'amount': normalized['amount'],
        'currency': normalized['currency'] ?? 'ETB',
        'date': normalized['date'] ?? FieldValue.serverTimestamp(),
        'status': normalized['status'] ?? 'completed',
        'raw': normalized,
        'createdAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
      };

      // Save to both global payments and user's payments subcollection
      await FirebaseFirestore.instance
          .collection('payments')
          .add(paymentData);
          
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('payments')
          .doc(paymentId)
          .set(paymentData, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage())
      );
    } catch (e) {
      debugPrint('Error saving payment: $e');
      _showSnack('${AppLocalizations.of(context)!.errorProcessingPayment} $e');
      rethrow;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
}

  // Create a unique reference key for tracking payments
  String? _buildRefKey({
    required PaymentMethod method,
    required String reference,
    String? suffix,
    String? phone,
  }) {
    if (method == PaymentMethod.image) return null;
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

  // Helper method to extract and clean amount from various string formats
  String _extractAmount(String amountStr) {
    if (amountStr.isEmpty) return '';
    
    debugPrint('_extractAmount input: "$amountStr"');
    
    // Try to match common currency formats:
    // 1. "3,000.00 ETB" or "3,000.00 Birr"
    // 2. "3000.00"
    // 3. "3,000"
    // 4. "ETB 3,000.00"
    final currencyRegex = RegExp(
      r'([-+]?\s*[0-9]{1,3}(?:,?[0-9]{3})*(?:\.[0-9]{2})?)\s*(?:ETB|Birr|birr|Br)?',
      caseSensitive: false,
    );
    
    final match = currencyRegex.firstMatch(amountStr);
    if (match != null && match.group(1) != null) {
      String number = match.group(1)!.replaceAll(',', '');
      debugPrint('Extracted number using currency regex: $number');
      return number;
    }
    
    // Fallback: Extract any sequence of digits with optional decimal point
    final digitRegex = RegExp(r'([0-9]+(?:\.[0-9]+)?)');
    final digitMatch = digitRegex.firstMatch(amountStr);
    if (digitMatch != null) {
      debugPrint('Extracted number using digit regex: ${digitMatch.group(0)}');
      return digitMatch.group(0)!;
    }
    
    debugPrint('Could not extract amount from: $amountStr');
    return amountStr; // Return original and let parsing handle it
  }
  
  // Parse ETB amount across string formats (e.g., "101.00 Birr", "3,000.00 ETB", 73000)
  double? _parseEtbAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      debugPrint('Amount is null or empty');
      return null;
    }
    
    try {
      debugPrint('Parsing amount: "$value"');
      
      // First clean and normalize the input
      String normalized = value.trim();
      
      // Handle negative numbers
      bool isNegative = normalized.startsWith('-');
      if (isNegative) {
        normalized = normalized.substring(1).trim();
      }
      
      // Extract the numeric part using the helper
      final extracted = _extractAmount(normalized);
      debugPrint('After _extractAmount: "$extracted"');
      
      if (extracted.isEmpty) {
        debugPrint('Extracted amount is empty');
        return null;
      }
      
      // Try parsing directly first (handles simple numbers)
      var amount = double.tryParse(extracted);
      
      // If that fails, try cleaning up the string
      if (amount == null) {
        // Remove all non-numeric characters except decimal point and minus
        String cleaned = extracted
            .replaceAll(RegExp(r'[^\d.-]'), '')
            .replaceAll(RegExp(r'(?<=\d)\.(?=\d*\.)'), '') // Remove extra decimal points
            .replaceAll(RegExp(r'(?<=\d),(?=\d)'), ''); // Remove thousand separators
        
        debugPrint('Cleaned amount string: $cleaned');
        
        // Try parsing again
        amount = double.tryParse(cleaned);
        
        // If still null, try replacing comma with decimal point
        if (amount == null && cleaned.contains(',')) {
          amount = double.tryParse(cleaned.replaceAll(',', '.'));
        }
      }
      
      // Apply negative sign if needed
      if (isNegative && amount != null) {
        amount = -amount;
      }
      
      debugPrint('Final parsed amount: $amount');
      return amount;
    } catch (e) {
      debugPrint('Error parsing amount "$value": $e');
      return null;
    }
  }

  Map<String, dynamic> _normalizePaymentDetails(
    PaymentMethod method,
    Map<String, dynamic>? body,
  ) {
    debugPrint('Normalizing payment details for method: $method');
    debugPrint('Raw response data: $body');
    
    final data = body?['data'] ?? body ?? <String, dynamic>{};
    String provider = method.name;

    String? payerName;
    String? payerAccountOrPhone;
    String? receiverName;
    String? receiverAccountOrPhone;
    String? amount;
    String? currency = 'ETB';
    String? date;
    String? reference;
    String status = 'completed';

    try {
      // Handle different response formats based on payment method
      switch (method) {
        case PaymentMethod.telebirr:
          // Format 1: Direct Telebirr response
          payerName = data['payerName']?.toString();
          payerAccountOrPhone = data['payerTelebirrNo']?.toString();
          receiverName = data['creditedPartyName']?.toString();
          receiverAccountOrPhone = data['creditedPartyAccountNo']?.toString();
          amount = _extractAmount(data['totalPaidAmount']?.toString() ?? '');
          reference = data['receiptNo']?.toString();
          date = data['paymentDate']?.toString();
          status = data['transactionStatus']?.toString()?.toLowerCase() ?? 'completed';
          break;
          
        case PaymentMethod.dashen:
          // Format 2: Dashen Bank response
          payerName = data['senderName']?.toString();
          payerAccountOrPhone = data['senderAccountNumber']?.toString();
          receiverName = 'Dashen Bank Customer';
          amount = data['transactionAmount']?.toString();
          reference = data['transactionReference']?.toString();
          date = data['transactionDate']?.toString();
          status = 'completed';
          break;
          
        case PaymentMethod.abyssinia:
          // Format 3: Abyssinia Bank response
          final innerData = data['data'] ?? data;
          payerName = innerData['payer']?.toString();
          payerAccountOrPhone = innerData['payerAccount']?.toString();
          receiverName = innerData['receiver']?.toString();
          amount = innerData['amount']?.toString();
          reference = innerData['reference']?.toString();
          date = innerData['date']?.toString();
          status = 'completed';
          break;
          
        case PaymentMethod.cbebirr:
          // Format 4: CBE Birr response
          payerName = data['customerName']?.toString();
          payerAccountOrPhone = data['debitAccount']?.toString();
          receiverName = data['receiverName']?.toString();
          receiverAccountOrPhone = data['creditAccount']?.toString();
          amount = _extractAmount(data['paidAmount']?.toString() ?? data['amount']?.toString() ?? '');
          reference = data['receiptNumber']?.toString() ?? data['reference']?.toString();
          date = data['transactionDate']?.toString();
          status = data['transactionStatus']?.toString()?.toLowerCase() ?? 'completed';
          break;
          
        case PaymentMethod.image:
          // Handle image upload response format
          if (data['type'] == 'telebirr') {
            provider = 'telebirr';
            final details = data['details'] as Map<String, dynamic>? ?? {};
            payerName = details['payer']?.toString();
            payerAccountOrPhone = details['payerAccount']?.toString();
            receiverName = details['receiverName']?.toString() ?? details['receiver']?.toString();
            receiverAccountOrPhone = details['receiverAccount']?.toString();
            amount = _extractAmount(details['amount']?.toString() ?? '');
            reference = details['reference']?.toString();
            status = details['status']?.toString() ?? 'completed';
            date = details['date']?.toString();
          }
          break;
          
        default:
          // Fallback for other methods
          payerName = data['payerName'] ?? data['senderName'] ?? data['customerName'];
          payerAccountOrPhone = data['payerAccount'] ?? data['senderAccount'] ?? data['debitAccount'];
          receiverName = data['receiverName'] ?? data['creditedPartyName'];
          receiverAccountOrPhone = data['receiverAccount'] ?? data['creditedPartyAccountNo'];
          amount = _extractAmount(data['amount']?.toString() ?? 
                                 data['totalPaidAmount']?.toString() ?? 
                                 data['transactionAmount']?.toString() ?? '');
          reference = data['reference'] ?? data['receiptNumber'] ?? data['transactionReference'];
          date = data['date'] ?? data['transactionDate'] ?? data['paymentDate'];
          status = (data['status'] ?? data['transactionStatus'] ?? 'completed').toString().toLowerCase();
      }
      
      // Special handling for Dashen Bank amount
      if (method == PaymentMethod.dashen && amount == null) {
        final txAmount = data['transactionAmount'];
        if (txAmount is int || txAmount is double) {
          amount = txAmount.toString();
        }
      }
      
      debugPrint('Normalized payment details:');
      debugPrint('- Provider: $provider');
      debugPrint('- Payer: $payerName ($payerAccountOrPhone)');
      debugPrint('- Receiver: $receiverName ($receiverAccountOrPhone)');
      debugPrint('- Amount: $amount $currency');
      debugPrint('- Reference: $reference');
      debugPrint('- Date: $date');
      debugPrint('- Status: $status');
      
    } catch (e) {
      debugPrint('Error normalizing payment details: $e');
      rethrow;
    }

    // Parse and format the date
    String? dateIso;
    if (date != null) {
      try {
        final parsedDate = DateTime.tryParse(date);
        if (parsedDate != null) {
          dateIso = parsedDate.toIso8601String();
        }
      } catch (e) {
        debugPrint('Error parsing date "$date": $e');
      }
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

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _extracting = true;
          _extractedReference = null;
        });
        
        // Extract reference from image
        await _extractReferenceFromImage();
      }
    } catch (e) {
      _showSnack('${AppLocalizations.of(context)!.errorSelectingImage} $e');
      setState(() => _extracting = false);
    }
  }
  
  Future<void> _extractReferenceFromImage() async {
    if (_selectedImage == null) return;
    
    setState(() => _extracting = true);
    
    try {
      // First, just extract the reference number from the image
      final result = await _verifier.verify(
        method: PaymentMethod.image,
        imageFile: _selectedImage,
        payload: {'extractOnly': 'true'}, // Tell the API to only extract reference
      );
      
      if (result.success && result.data != null) {
        // The API should return just the reference number in the 'reference' field
        final reference = result.data?['reference']?.toString();
        
        if (reference != null && reference.isNotEmpty) {
          setState(() {
            _extractedReference = reference;
            _refCtrl.text = reference;
            _method = PaymentMethod.telebirr; // Default to Telebirr for verification
          });
          
          // Automatically trigger verification with the extracted reference
          await _verifyPaymentWithReference(reference);
        } else {
          _showSnack(AppLocalizations.of(context)!.couldNotExtractReference);
        }
      } else {
        _showSnack(AppLocalizations.of(context)!.failedToProcessImage);
      }
    } catch (e) {
      debugPrint('Error extracting reference: $e');
      _showSnack('${AppLocalizations.of(context)!.errorProcessingImage} ${e.toString()}');
    } finally {
      setState(() => _extracting = false);
    }
  }
  
  Future<void> _processVerificationResult(Map<String, dynamic>? data) async {
    if (data == null) {
      _showSnack(AppLocalizations.of(context)!.invalidVerificationResponse);
      return;
    }
    
    try {
      debugPrint('Verification response data: $data');
      
      // First normalize the payment details
      final normalized = _normalizePaymentDetails(_method, data);
      debugPrint('Normalized payment details: $normalized');
      
      // Get the amount from the normalized data
      final amountStr = normalized['amount']?.toString() ?? '';
      final paidAmount = _parseEtbAmount(amountStr);
      debugPrint('Parsed amount: $paidAmount from "$amountStr"');
      
      // Check if amount is valid and meets minimum requirement
      if (paidAmount == null) {
        _showSnack(AppLocalizations.of(context)!.couldNotVerifyPaymentAmount);
        return;
      }
      
      if (paidAmount < _requiredEtb) {
        _showSnack('${AppLocalizations.of(context)!.paymentMustBeAtLeast} ${_requiredEtb.toInt()} ETB. ${AppLocalizations.of(context)!.found}: $amountStr');
        return;
      }
      
      // For Telebirr, verify the recipient
      if (_method == PaymentMethod.telebirr) {
        final rcvRaw = (normalized['receiverAccountOrPhone'] ?? '').toString();
        final receiverName = (normalized['receiverName'] ?? '').toString();
        final lastTwoDigits = rcvRaw.length >= 2 ? rcvRaw.substring(rcvRaw.length - 2) : '';
        
        debugPrint('Verifying recipient - Last 2 digits: $lastTwoDigits, Name: $receiverName');
        
        bool isCorrectReceiver = lastTwoDigits == _requiredTelebirrLastTwoDigits ||
            receiverName.toLowerCase().contains(_requiredTelebirrReceiverName.toLowerCase());
            
        if (!isCorrectReceiver) {
          _showSnack(AppLocalizations.of(context)!.paymentVerificationFailed);
          return;
        }
      }
      
      // Get the reference from normalized data or fallback to the text field
      final reference = normalized['reference']?.toString() ?? _refCtrl.text.trim();
      if (reference.isEmpty) {
        _showSnack(AppLocalizations.of(context)!.couldNotDetermineTransactionReference);
        return;
      }
      
      // If we get here, all validations passed
      await _savePaymentAndUpdateUser(normalized, reference);
    } catch (e) {
      _showSnack('${AppLocalizations.of(context)!.errorProcessingPayment} ${e.toString()}');
      debugPrint('Error in _processVerificationResult: $e');
      rethrow;
    }
  }
  
  Future<void> _verifyPaymentWithReference(String reference) async {
    if (reference.isEmpty) {
      _showSnack(AppLocalizations.of(context)!.enterValidReferenceNumber);
      return;
    }
    
    setState(() => _loading = true);
    
    try {
      debugPrint('Verifying payment with reference: $reference');
      
      // First check if this reference has already been used
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final existingPayment = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('payments')
            .where('reference', isEqualTo: reference)
            .limit(1)
            .get();
            
        if (existingPayment.docs.isNotEmpty) {
          _showSnack(AppLocalizations.of(context)!.paymentReferenceAlreadyUsed);
          return;
        }
      }
      
      // Verify the payment using the reference number
      final result = await _verifier.verify(
        method: _method,
        payload: {'reference': reference},
      );
      
      if (!result.success) {
        _showSnack(result.message ?? AppLocalizations.of(context)!.verificationFailed);
        return;
      }
      
      // Process the verification result with the original reference
      await _processVerificationResult({
        ...?result.data,
        'reference': reference, // Ensure reference is preserved
        'verifiedAt': DateTime.now().toIso8601String(),
      });
      
    } catch (e) {
      debugPrint('Error in _verifyPaymentWithReference: $e');
      _showSnack('${AppLocalizations.of(context)!.errorVerifyingPayment} ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  
  Widget _buildReferenceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _refCtrl,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.referenceNumber,
            hintText: 'CE12345678',
            prefixIcon: const Icon(Icons.receipt),
            suffixIcon: _extracting
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          readOnly: _extracting,
          validator: (value) => value?.isEmpty ?? true ? AppLocalizations.of(context)!.enterReferenceNumber : null,
        ),
        if (_extractedReference != null) ...[
          const SizedBox(height: 8),
          Text(
            '${AppLocalizations.of(context)!.extractedFromReceipt}: $_extractedReference',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVerifyButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_loading || _extracting) ? null : _verifyAndActivate,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(AppLocalizations.of(context)!.verifyPayment),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
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
                    Text(
                      AppLocalizations.of(context)!.goPremium,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.freeAccessEnded,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
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
                                      AppLocalizations.of(context)!.yearly,
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
                              Text(
                                AppLocalizations.of(context)!.oneYearFullAccess,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 14),
                              _FeatureRow(
                                icon: Icons.check_circle,
                                text: AppLocalizations.of(context)!.unlimitedPeopleAndDubes,
                              ),
                              _FeatureRow(
                                icon: Icons.check_circle,
                                text: AppLocalizations.of(context)!.cloudBackupAndRestore,
                              ),
                              _FeatureRow(
                                icon: Icons.check_circle,
                                text: AppLocalizations.of(context)!.priorityUpdates,
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
      children: [
        Text(
          AppLocalizations.of(context)!.payStepsTitle,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        StepInstruction(
          stepNumber: 1,
          text: AppLocalizations.of(context)!.payStep1,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 24.0, top: 4.0, bottom: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('• Telebirr: 251900647953', style: TextStyle(fontSize: 15)),
              SizedBox(height: 2),
              Text('• Commercial Bank: 1000711023015', style: TextStyle(fontSize: 15)),
            ],
          ),
        ),
        StepInstruction(
          stepNumber: 2,
          text: AppLocalizations.of(context)!.payStep2,
        ),
        StepInstruction(
          stepNumber: 3,
          text: AppLocalizations.of(context)!.payStep3,
        ),
        StepInstruction(
          stepNumber: 4,
          text: AppLocalizations.of(context)!.payStep4,
        ),
        StepInstruction(
          stepNumber: 5,
          text: AppLocalizations.of(context)!.payStep5,
        ),
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
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.choosePaymentMethod,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<PaymentMethod>(
                                      value: _method,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                      ),
                                      isExpanded: true,
                                      icon: const Icon(Icons.arrow_drop_down),
                                      items: [
                                        DropdownMenuItem(
                                          value: PaymentMethod.telebirr,
                                          child: Text(AppLocalizations.of(context)!.telebirr),
                                        ),
                                        DropdownMenuItem(
                                          value: PaymentMethod.cbe,
                                          child: Text(AppLocalizations.of(context)!.cbeRefSuffix),
                                        ),
                                        DropdownMenuItem(
                                          value: PaymentMethod.abyssinia,
                                          child: Text(AppLocalizations.of(context)!.abyssiniaRefSuffix),
                                        ),
                                        DropdownMenuItem(
                                          value: PaymentMethod.cbebirr,
                                          child: Text(AppLocalizations.of(context)!.cbeBirrReceiptPhone),
                                        ),
                                      ],
                                      onChanged: _loading
                                          ? null
                                          : (value) {
                                              if (value != null) {
                                                setState(() => _method = value);
                                              }
                                            },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Tooltip(
                                    message: AppLocalizations.of(context)!.uploadReceiptImage,
                                    child: IconButton.filledTonal(
                                      onPressed: _loading ? null : _pickImage,
                                      icon: _extracting
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.camera_alt),
                                      style: IconButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.all(16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              if (_method != PaymentMethod.image) ...[
                                _buildReferenceField(),
                                const SizedBox(height: 12),
                              ],
                              if (_method == PaymentMethod.cbe ||
                                  _method == PaymentMethod.abyssinia) ...[
                                TextField(
                                  controller: _suffixCtrl,
                                  enabled: !_loading,
                                  decoration: InputDecoration(
                                    labelText: AppLocalizations.of(context)!.accountSuffix,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (_method == PaymentMethod.cbebirr) ...[
                                TextField(
                                  controller: _phoneCtrl,
                                  enabled: !_loading,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: AppLocalizations.of(context)!.phoneNumber,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (_selectedImage != null) ...[
                                const SizedBox(height: 16),
                                Stack(
                                  children: [
                                    Container(
                                      height: 200,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade300),
                                        image: DecorationImage(
                                          image: FileImage(_selectedImage!),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.close, size: 20),
                                          onPressed: () {
                                            setState(() {
                                              _selectedImage = null;
                                              _extractedReference = null;
                                            });
                                          },
                                          style: IconButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (_extractedReference != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Text(
                                      '${AppLocalizations.of(context)!.extractedReference}: $_extractedReference',
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                              _buildVerifyButton(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(context)!.needHelpContactSupport,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
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
