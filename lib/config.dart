// lib/config.dart
/// Replace with your Web client ID (OAuth 2.0 client ID for "Web application")
/// Example: 123456789012-abcdefg.apps.googleusercontent.com
const String kGoogleWebClientId =
    '1015181780334-m6kehremhnkksika9asiahfjikbup7r1.apps.googleusercontent.com';

// Verify API (https://verify.leul.et/docs)
// Set your API key here or load it from secure storage/remote config.
const String kVerifyApiBase = 'https://verifyapi.leulzenebe.pro';
const String kVerifyApiKey = String.fromEnvironment(
  'VERIFY_API_KEY',
  defaultValue: '',
);
