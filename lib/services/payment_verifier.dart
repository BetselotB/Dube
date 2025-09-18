import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dube/config.dart';

enum PaymentMethod { cbe, telebirr, dashen, abyssinia, cbebirr, image }

class PaymentVerificationResult {
  final bool success;
  final Map<String, dynamic>? data;
  final String? message;

  const PaymentVerificationResult({
    required this.success,
    this.data,
    this.message,
  });
}

class PaymentVerifierService {
  final String apiBase;
  final String apiKey;

  const PaymentVerifierService({
    this.apiBase = kVerifyApiBase,
    this.apiKey = kVerifyApiKey,
  });

  Future<PaymentVerificationResult> verify({
    required PaymentMethod method,
    required Map<String, dynamic> payload,
  }) async {
    if (apiKey.isEmpty) {
      return const PaymentVerificationResult(
        success: false,
        message: 'Missing VERIFY API key',
      );
    }

    final endpoint = _endpointFor(method);
    final uri = Uri.parse('$apiBase$endpoint');

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
      body: jsonEncode(payload),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return PaymentVerificationResult(success: true, data: body);
      } catch (_) {
        return PaymentVerificationResult(
          success: true,
          data: {'raw': res.body},
        );
      }
    }

    return PaymentVerificationResult(
      success: false,
      message: 'Verification failed (${res.statusCode}): ${res.body}',
    );
  }

  String _endpointFor(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cbe:
        return '/verify-cbe';
      case PaymentMethod.telebirr:
        return '/verify-telebirr';
      case PaymentMethod.dashen:
        return '/verify-dashen';
      case PaymentMethod.abyssinia:
        return '/verify-abyssinia';
      case PaymentMethod.cbebirr:
        return '/verify-cbebirr';
      case PaymentMethod.image:
        return '/verify-image';
    }
  }
}
