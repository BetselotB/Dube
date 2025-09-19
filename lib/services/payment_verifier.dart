import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http_parser/http_parser.dart';
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
    File? imageFile,
  }) async {
    if (apiKey.isEmpty) {
      return const PaymentVerificationResult(
        success: false,
        message: 'Missing VERIFY API key',
      );
    }

    final endpoint = _endpointFor(method);
    final uri = Uri.parse('$apiBase$endpoint');

    try {
      if (method == PaymentMethod.image) {
        if (imageFile == null) {
          return const PaymentVerificationResult(
            success: false,
            message: 'No image provided for verification',
          );
        }
        
        // Create multipart request
        var request = http.MultipartRequest('POST', uri);
        
        // Add headers
        request.headers['x-api-key'] = apiKey;
        
        // Add file
        final fileStream = http.ByteStream(imageFile.openRead());
        final fileLength = await imageFile.length();
        
        final multipartFile = http.MultipartFile(
          'file',
          fileStream,
          fileLength,
          filename: 'receipt.jpg',
          contentType: MediaType('image', 'jpeg'),
        );
        
        request.files.add(multipartFile);
        
        // Add autoVerify and suffix if provided
        request.fields['autoVerify'] = 'true';
        if (payload.containsKey('suffix')) {
          request.fields['suffix'] = payload['suffix'].toString();
        }
        
        // Send the request
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        
        return _handleResponse(response);
      } else {
        // Handle JSON requests for other methods
        final res = await http.post(
          uri,
          headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
          body: jsonEncode(payload),
        );
        
        return _handleResponse(res);
      }
    } catch (e) {
      return PaymentVerificationResult(
        success: false,
        message: 'Network error: $e',
      );
    }
  }
  
  PaymentVerificationResult _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        
        // Handle the new response format
        if (body.containsKey('verified') && body['verified'] == true) {
          // Transform the response to match the expected format
          final details = body['details'] as Map<String, dynamic>? ?? {};
          final transformed = {
            'type': body['type'],
            'reference': body['reference'],
            'details': {
              'success': details['success'] ?? true,
              'payer': details['payer'],
              'payerAccount': details['payerAccount'],
              'receiver': details['receiver'],
              'receiverAccount': details['receiverAccount'],
              'amount': details['amount'],
              'date': details['date'],
              'reference': details['reference'],
              'reason': details['reason'],
            }
          };
          return PaymentVerificationResult(success: true, data: transformed);
        }
        
        return PaymentVerificationResult(success: true, data: body);
      } catch (e) {
        return PaymentVerificationResult(
          success: false,
          message: 'Failed to parse response: $e',
          data: {'raw': response.body},
        );
      }
    }

    return PaymentVerificationResult(
      success: false,
      message: 'Verification failed (${response.statusCode}): ${response.body}',
    );
  }

  String _endpointFor(PaymentMethod method) {
    // All endpoints now use the same base path
    // ignore: prefer_interpolation_to_compose_strings
    return '/verify' + (method == PaymentMethod.image ? '-image' : '-${method.name}');
  }
}
