import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/constants/google_scopes.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _initialized = false;
  GoogleSignInAccount? _googleUser;

  static const String _serverClientId =
      '1002306273890-ea7jadjt724q64ubd1ejlcdp5s2g47ec.apps.googleusercontent.com';

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    await GoogleSignIn.instance.initialize(
      serverClientId: _serverClientId,
    );

    _initialized = true;
  }

  Future<UserCredential> signInWithGoogle() async {
    await _ensureInitialized();

    _googleUser = await GoogleSignIn.instance.authenticate();

    final googleAuth = _googleUser!.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  Future<Map<String, String>> getGoogleAuthHeaders() async {
    await _ensureInitialized();

    _googleUser ??= await GoogleSignIn.instance.authenticate();

    await _googleUser!.authorizationClient.authorizeScopes(
      GoogleScopes.classroomScopes,
    );

    final headers = await _googleUser!.authorizationClient.authorizationHeaders(
      GoogleScopes.classroomScopes,
    );

    if (headers == null) {
      throw Exception('Could not get Google authorization headers');
    }

    return headers;
  }

  Future<void> signOut() async {
    await _ensureInitialized();
    _googleUser = null;
    await GoogleSignIn.instance.disconnect();
    await _auth.signOut();
  }
}