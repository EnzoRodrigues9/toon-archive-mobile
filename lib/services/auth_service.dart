import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  // 🔑 LOGIN COM GOOGLE (ANDROID + WEB)
  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // 🌐 WEB LOGIN (mais estável)
        GoogleAuthProvider googleProvider = GoogleAuthProvider();

        final userCredential =
            await _auth.signInWithPopup(googleProvider);

        return userCredential.user;
      } else {
        // 📱 ANDROID / IOS LOGIN
        final GoogleSignInAccount? googleUser =
            await _googleSignIn.signIn();

        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential =
            await _auth.signInWithCredential(credential);

        return userCredential.user;
      }
    } catch (e) {
      print('Erro no login: $e');
      return null;
    }
  }

  // 🚪 LOGOUT
  Future<void> logout() async {
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }

  // 👤 USUÁRIO ATUAL
  User? getUsuarioAtual() {
    return _auth.currentUser;
  }
}