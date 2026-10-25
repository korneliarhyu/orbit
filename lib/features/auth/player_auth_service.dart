import 'package:firebase_auth/firebase_auth.dart';

class PlayerAuthService {
  PlayerAuthService._();
  
  static final instance = PlayerAuthService._();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  //Temporary username mapping
  String _emailFromUsername(String username){
    final clean = username.trim().toLowerCase();
    
    if (!RegExp(r'^[a-z0-9_]{5,12}$').hasMatch(clean)) {
      throw FormatException(
        'Username must be 5-12 characters, using letters, numbers or _.'
      );
    }
    return '$clean@users.orbit.example';
  }
  
  // REGISTER
  Future<UserCredential> register({
    required String username,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
        email: _emailFromUsername(username), 
        password: password
    );
    await credential.user?.updateDisplayName(username.trim());
    
    return credential;
  }
  
  // LOGIN
  Future<UserCredential> login({
    required String username,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
        email: _emailFromUsername(username),
        password: password
    );
  }

  // LOGOUT
  Future<void> logout() => _auth.signOut();

  // CURRENT USER
  User? get currentUser => _auth.currentUser;
  
}