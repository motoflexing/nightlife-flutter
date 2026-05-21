import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

class AuthService {
  AuthService._();

  static final instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _requestedRole;
  bool _superAdminUnlockArmed = false;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentFirebaseUser => _auth.currentUser;

  String? get requestedRole => _requestedRole;

  bool get isSuperAdminUnlockArmed => _superAdminUnlockArmed;

  void armSuperAdminUnlock() {
    _superAdminUnlockArmed = true;
    _requestedRole = 'superAdmin';
  }

  Future<bool> verifyCurrentUserIsSuperAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _db.collection('users').doc(user.uid).get();
    final role = doc.data()?['role'] as String?;
    return doc.exists && role == 'superAdmin';
  }

  Future<AppUser?> getCurrentProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return getProfile(user.uid);
  }

  Future<AppUser?> getProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromDoc(doc);
  }

  Stream<AppUser?> profileStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromDoc(doc);
    });
  }

  Future<void> signIn({
    required String email,
    required String password,
    required String requestedRole,
  }) async {
    try {
      _requestedRole = requestedRole;

      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(_friendlyAuthError(error));
    }
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String requestedRole,

    // Extra signup fields
    String title = '',
    String gender = '',
    String dob = '',
    String instagramId = '',
    String snapchatId = '',
    String validIdUrl = '',
  }) async {
    try {
      _requestedRole = requestedRole;

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw const AuthException('Unable to create your account right now.');
      }

      final cleanName = name.trim();
      final cleanEmail = email.trim().toLowerCase();
      final cleanPhone = phone.trim();
      final cleanTitle = title.trim();
      final cleanGender = gender.trim();
      final cleanDob = dob.trim();
      final cleanInstagramId = instagramId.trim();
      final cleanSnapchatId = snapchatId.trim();
      final cleanValidIdUrl = validIdUrl.trim();

      final role = _safeRequestedRole(requestedRole);
      final status = role == 'clubAdmin' ? 'pending' : 'approved';

      final promoterCode = role == 'promoter'
          ? _makePromoterCode(cleanName, user.uid)
          : null;

      await user.updateDisplayName(cleanName);

      final userData = {
        'uid': user.uid,

        // Basic details
        'title': cleanTitle,
        'name': cleanName,
        'email': cleanEmail,
        'phone': cleanPhone,
        'gender': cleanGender,
        'dob': cleanDob,

        // Social IDs
        'instagramId': cleanInstagramId,
        'snapchatId': cleanSnapchatId,

        // Verification
        'validIdUrl': cleanValidIdUrl,
        'verificationStatus': cleanValidIdUrl.isEmpty
            ? 'not_uploaded'
            : 'pending',

        // Role details
        'role': role,
        'status': status,
        'clubId': null,
        'promoterCode': promoterCode,

        // System fields
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      await _db.collection('users').doc(user.uid).set(userData);

      if (role == 'promoter') {
        await _db.collection('promoters').doc(user.uid).set({
          'userId': user.uid,
          'name': cleanName,
          'email': cleanEmail,
          'phone': cleanPhone,
          'referralCode': promoterCode,
          'totalRsvps': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });

        await _db.collection('referralCodes').doc(promoterCode).set({
          'promoterId': user.uid,
          'referralCode': promoterCode,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch (error) {
      throw AuthException(_friendlyAuthError(error));
    } catch (error) {
      throw AuthException(error.toString());
    }
  }

  Future<AppUser> ensureSafeProfile(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final doc = await ref.get();

    if (doc.exists) return AppUser.fromDoc(doc);

    await ref.set({
      'uid': user.uid,

      // Basic details
      'title': '',
      'name': user.displayName ?? 'Nightlife User',
      'email': user.email ?? '',
      'phone': user.phoneNumber ?? '',
      'gender': '',
      'dob': '',

      // Social IDs
      'instagramId': '',
      'snapchatId': '',

      // Verification
      'validIdUrl': '',
      'verificationStatus': 'not_uploaded',

      // Role details
      'role': 'user',
      'status': 'approved',
      'clubId': null,
      'promoterCode': null,

      // System fields
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive': true,
    });

    final next = await ref.get();
    return AppUser.fromDoc(next);
  }

  Future<void> signOut() {
    _requestedRole = null;
    _superAdminUnlockArmed = false;
    return _auth.signOut();
  }

  String _safeRequestedRole(String role) {
    return switch (role) {
      'promoter' => 'promoter',
      'clubAdmin' => 'clubAdmin',
      _ => 'user',
    };
  }

  String _makePromoterCode(String name, String uid) {
    final cleanBase = name
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .padRight(4, 'X')
        .substring(0, 4);

    return '$cleanBase${uid.substring(0, 4).toUpperCase()}';
  }

  String _friendlyAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Use a stronger password with at least 6 characters.';
      case 'network-request-failed':
        return 'Network issue. Check your connection and try again.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
