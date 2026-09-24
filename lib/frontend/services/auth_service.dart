import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // Lazy access: constructing AuthService must not require a live Firebase
  // app, so widget tests and screens can build safely before Firebase is
  // initialized. Firebase services are only touched when a method runs.
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Phone Authentication
  // ---------------------------------------------------------------------------

  /// Starts phone number verification.
  ///
  /// On **Android** this may auto-resolve via `verificationCompleted`.
  /// On **Web** it triggers the reCAPTCHA flow and calls `codeSent`.
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(PhoneAuthCredential credential)
        verificationCompleted,
    required void Function(FirebaseAuthException error) verificationFailed,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String verificationId) codeAutoRetrievalTimeout,
    int? resendToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      forceResendingToken: resendToken,
    );
  }

  /// Signs in with a [PhoneAuthCredential] built from a verification ID and
  /// SMS code.  Also ensures a Firestore user document exists.
  Future<UserCredential?> signInWithOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final userCredential =
          await _auth.signInWithCredential(credential);
      await _createUserDocIfNeeded(userCredential.user);
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  /// Signs in with an already-completed [PhoneAuthCredential] (typically from
  /// `verificationCompleted` on Android auto-resolve).
  Future<UserCredential?> signInWithPhoneCredential(
      PhoneAuthCredential credential) async {
    try {
      final userCredential =
          await _auth.signInWithCredential(credential);
      await _createUserDocIfNeeded(userCredential.user);
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  /// Creates a `users/{uid}` document if one does not already exist.
  Future<void> _createUserDocIfNeeded(User? user) async {
    if (user == null) return;
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'uid': user.uid,
        'phone': user.phoneNumber ?? '',
        'createdAt': DateTime.now(),
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Email / Password (kept for backward-compat — not used by new auth flow)
  // ---------------------------------------------------------------------------

  Future<UserCredential?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'name': name,
        'email': email,
        'createdAt': DateTime.now(),
      });

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> login({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Common
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (_) {
      return null;
    }
  }
}