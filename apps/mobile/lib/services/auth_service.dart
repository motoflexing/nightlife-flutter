import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import 'notification_service.dart';
import 'referral_service.dart';

class AuthService {
  AuthService._();

  static final instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _requestedRole;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentFirebaseUser => _auth.currentUser;

  String? get requestedRole => _requestedRole;

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

  Future<void> refreshCurrentUserProfileState({
    String? displayName,
    String? photoUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final cleanName = displayName?.trim();
    final cleanPhotoUrl = photoUrl?.trim();
    try {
      if (cleanName != null && cleanName.isNotEmpty) {
        await user
            .updateDisplayName(cleanName)
            .timeout(const Duration(seconds: 10));
      }
      if (cleanPhotoUrl != null && cleanPhotoUrl.isNotEmpty) {
        await user
            .updatePhotoURL(cleanPhotoUrl)
            .timeout(const Duration(seconds: 10));
      }
      await user.reload().timeout(const Duration(seconds: 10));
    } on FirebaseAuthException catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
    } on TimeoutException catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Stream<AppUser?> profileStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().asyncMap((doc) async {
      if (!doc.exists) return null;
      final profile = AppUser.fromDoc(doc);
      if (profile.isPromoter &&
          profile.isActive &&
          !profile.isRejected &&
          profile.status != 'approved') {
        await _approvePromoterProfileIfNeeded(_auth.currentUser);
        final updatedDoc = await doc.reference.get();
        return AppUser.fromDoc(updatedDoc);
      }
      return profile;
    });
  }

  Future<void> signIn({
    required String email,
    required String password,
    required String requestedRole,
  }) async {
    try {
      _requestedRole = requestedRole;

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _approvePromoterProfileIfNeeded(credential.user);
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
    String businessName = '',
    String gstNumber = '',
    String businessPhone = '',
    String businessAddress = '',
    String businessCity = '',
    String businessInstagram = '',
    String documentUploadStatus = 'pending_upload',
  }) async {
    try {
      _requestedRole = requestedRole;

      final user = await createAuthUser(
        name: name,
        email: email,
        password: password,
      );
      await saveCurrentUserProfile(
        user: user,
        name: name,
        email: email,
        phone: phone,
        requestedRole: requestedRole,
        title: title,
        gender: gender,
        dob: dob,
        instagramId: instagramId,
        snapchatId: snapchatId,
        validIdUrl: validIdUrl,
        businessName: businessName,
        gstNumber: gstNumber,
        businessPhone: businessPhone,
        businessAddress: businessAddress,
        businessCity: businessCity,
        businessInstagram: businessInstagram,
        documentUploadStatus: documentUploadStatus,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(_friendlyAuthError(error));
    } catch (error) {
      throw AuthException(error.toString());
    }
  }

  Future<User> createAuthUser({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth
        .createUserWithEmailAndPassword(email: email.trim(), password: password)
        .timeout(const Duration(seconds: 20));
    final user = credential.user;
    if (user == null) {
      throw const AuthException('Unable to create your account right now.');
    }
    await user
        .updateDisplayName(name.trim())
        .timeout(const Duration(seconds: 10));
    return user;
  }

  Future<void> saveCurrentUserProfile({
    required User user,
    required String name,
    required String email,
    required String phone,
    required String requestedRole,
    String title = '',
    String gender = '',
    String dob = '',
    String instagramId = '',
    String snapchatId = '',
    String validIdUrl = '',
    String businessName = '',
    String gstNumber = '',
    String businessPhone = '',
    String businessAddress = '',
    String businessCity = '',
    String businessInstagram = '',
    String documentUploadStatus = 'pending_upload',
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPhone = phone.trim();
    final cleanValidIdUrl = validIdUrl.trim();
    final role = _safeRequestedRole(requestedRole);
    final requiresReview = role == 'clubAdmin';
    final status = requiresReview ? 'pending_review' : 'approved';
    final promoterCode = role == 'promoter'
        ? _makePromoterCode(cleanName, user.uid)
        : null;

    final userData = {
      'uid': user.uid,
      'title': title.trim(),
      'name': cleanName,
      'email': cleanEmail,
      'phone': cleanPhone,
      'gender': gender.trim(),
      'dob': dob.trim(),
      'instagramId': instagramId.trim(),
      'snapchatId': snapchatId.trim(),
      'validIdUrl': cleanValidIdUrl,
      'verificationStatus': requiresReview ? 'pending_review' : 'approved',
      'idVerificationStatus': 'not_selected',
      'documentUploadStatus': requiresReview
          ? documentUploadStatus
          : 'not_required',
      'onboardingCompleted': true,
      'rejectionReason': '',
      if (requiresReview) 'businessName': businessName.trim(),
      if (requiresReview && role == 'clubAdmin')
        'venueName': businessName.trim(),
      if (requiresReview) 'gstNumber': gstNumber.trim(),
      if (requiresReview) 'ownerName': cleanName,
      if (requiresReview) 'businessPhone': businessPhone.trim(),
      if (requiresReview) 'businessAddress': businessAddress.trim(),
      if (requiresReview) 'city': businessCity.trim(),
      if (requiresReview) 'instagramLink': businessInstagram.trim(),
      'role': role,
      'status': status,
      'clubId': null,
      'promoterCode': promoterCode,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive': true,
    };

    await _db
        .collection('users')
        .doc(user.uid)
        .set(userData)
        .timeout(const Duration(seconds: 20));

    if (role == 'promoter') {
      await _db
          .collection('promoters')
          .doc(user.uid)
          .set({
            'userId': user.uid,
            'name': cleanName,
            'email': cleanEmail,
            'phone': cleanPhone,
            'referralCode': promoterCode,
            'totalRsvps': 0,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'isActive': true,
          })
          .timeout(const Duration(seconds: 20));

      await _db
          .collection('referralCodes')
          .doc(promoterCode)
          .set({
            'promoterId': user.uid,
            'referralCode': promoterCode,
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 20));
    }
    if (role == 'clubAdmin') {
      final clubRef = _db.collection('clubs').doc();
      await clubRef
          .set({
            'ownerId': user.uid,
            'clubName': businessName.trim(),
            'ownerName': cleanName,
            'businessEmail': cleanEmail,
            'phone': businessPhone.trim(),
            'city': businessCity.trim(),
            'address': businessAddress.trim(),
            'instagram': businessInstagram.trim(),
            'documentUrl': '',
            'documentUploadStatus': documentUploadStatus,
            'verificationStatus': 'pending_review',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 20));
      await _db
          .collection('users')
          .doc(user.uid)
          .set({
            'clubId': clubRef.id,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 20));
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

  Future<void> signOut() async {
    _requestedRole = null;
    ReferralService.instance.clear();
    await NotificationService.instance.clearFcmToken();
    return _auth.signOut();
  }

  Future<void> _approvePromoterProfileIfNeeded(User? user) async {
    if (user == null) return;
    final ref = _db.collection('users').doc(user.uid);
    final doc = await ref.get();
    final data = doc.data();
    if (!doc.exists || data == null || data['role'] != 'promoter') return;

    final status = data['status'] as String? ?? '';
    final isActive = data['isActive'] as bool? ?? true;
    final onboardingCompleted = data['onboardingCompleted'] as bool? ?? true;
    if (status == 'rejected' || !isActive) return;
    if (status == 'approved' && isActive && onboardingCompleted) return;

    await ref.set({
      'status': 'approved',
      'verificationStatus': 'approved',
      'documentUploadStatus': 'not_required',
      'onboardingCompleted': true,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateCurrentUserValidIdUrl(String validIdUrl) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in is required to upload a valid ID.');
    }
    await _db
        .collection('users')
        .doc(user.uid)
        .set({
          'validIdUrl': validIdUrl,
          'idVerificationStatus': validIdUrl.trim().isEmpty
              ? 'not_selected'
              : 'pending_review',
          'verificationStatus': validIdUrl.trim().isEmpty
              ? 'not_selected'
              : 'pending_review',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true))
        .timeout(const Duration(seconds: 20));
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
