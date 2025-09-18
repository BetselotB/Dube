// lib/services/auth_services.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream of auth state
  Stream<User?> get userChanges => _auth.authStateChanges();

  /// Email / password signup (with displayName)
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // set display name on the user
    await userCredential.user?.updateDisplayName(displayName);
    await userCredential.user?.reload();
    return userCredential;
  }

  /// Email sign in
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Google sign in for google_sign_in v7+
  ///
  /// Notes:
  /// - Uses GoogleSignIn.instance.authenticate() to start the interactive flow.
  /// - googleUser.authentication currently exposes only an idToken by default.
  /// - We supply the idToken to FirebaseAuth via GoogleAuthProvider.credential(...)
  Future<UserCredential?> signInWithGoogle({ String? serverClientId }) async {
    try {
      // get the singleton
      final googleSignIn = GoogleSignIn.instance;

      // Optionally initialize with client IDs (useful on Android for serverClientId or iOS clientId)
      if (serverClientId != null) {
        // initialize is safe to call multiple times
        await googleSignIn.initialize(serverClientId: serverClientId);
      }

      // Start interactive auth (this may open UI). On some platforms you might prefer
      // to try a lightweight auth first via attemptLightweightAuthentication().
      final GoogleSignInAccount googleUser = await googleSignIn.authenticate();

      // Get authentication (idToken). Note: accessToken is part of authorization flows.
      final GoogleSignInAuthentication auth = await googleUser.authentication;

      final idToken = auth.idToken;
      if (idToken == null) {
        // If you absolutely need an access token, you must request scopes/authorization.
        throw FirebaseAuthException(
          code: 'MISSING_GOOGLE_ID_TOKEN',
          message: 'Missing Google ID token. Ensure Google Sign-In configuration is correct.',
        );
      }

      // Create a Firebase credential with the id token (accessToken optional)
      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        // accessToken: null, // not available unless you also request scopes/authorization
      );

      // Sign in with Firebase
      final userCredential = await _auth.signInWithCredential(credential);

      return userCredential;
    } on FirebaseAuthException {
      rethrow;
    } on Exception catch (e) {
      // GoogleSignIn may throw a GoogleSignInException or other exceptions
      // We rethrow as a FirebaseAuthException-like wrapper for upstream handling.
      throw FirebaseAuthException(
        code: 'GOOGLE_SIGN_IN_FAILED',
        message: e.toString(),
      );
    }
  }

  /// Sign out
  Future<void> signOut() async {
    // sign out of the GoogleSignIn plugin if used
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // ignore plugin sign-out errors
    }
    await _auth.signOut();
  }
}
