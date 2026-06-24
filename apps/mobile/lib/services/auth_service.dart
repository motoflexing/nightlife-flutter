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

  /// True while [signUp] is in flight. createUserWithEmailAndPassword signs the
  /// user in before the profile doc is written, which fires authStateChanges and
  /// can make a mounted listener call [ensureSafeProfile]. While this flag is
  /// set, ensureSafeProfile must not write a default 'user' doc — the signup flow
  /// itself writes the correct role doc.
  bool _isSigningUp = false;

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
    // Hold this flag for the whole signup so a mounted authStateChanges listener
    // (e.g. RoleRouterScreen) cannot write a default 'user' doc via
    // ensureSafeProfile in the window between account creation and the profile
    // write. Cleared in finally so a failed signup never leaves it stuck.
    _isSigningUp = true;
    try {
      _requestedRole = requestedRole;

      final user = await createAuthUser(
        name: name,
        email: email,
        password: password,
      );

      // Write the profile doc FIRST, before any other round-trip, so the correct
      // role lands as early as possible after sign-in. updateDisplayName is moved
      // to after this write (see below) to shrink the race window.
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

      // Auth display name is cosmetic; set it only after the role doc is written.
      await refreshCurrentUserProfileState(displayName: name);
    } on FirebaseAuthException catch (error) {
      // Conservative idempotent retry: if the account already exists, it may be
      // one this same flow just created (a prior attempt that raced/failed before
      // writing the profile). Only auto-recover when the supplied credentials
      // actually sign in — otherwise it's a genuinely taken email, so show the
      // friendly error.
      if (error.code == 'email-already-in-use') {
        final recovered = await _recoverInterruptedSignUp(
          email: email,
          password: password,
          name: name,
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
        if (recovered) return;
      }
      throw AuthException(_friendlyAuthError(error));
    } catch (error) {
      throw AuthException(error.toString());
    } finally {
      _isSigningUp = false;
    }
  }

  /// Attempts to finish a signup whose Auth account already exists but whose
  /// profile doc may be missing/incomplete (e.g. a previous attempt created the
  /// account, then failed before writing the role doc). Returns true only if the
  /// credentials signed in AND the correct profile now exists. Returns false (so
  /// the caller surfaces "email already in use") when the password doesn't match
  /// or a real profile with a different role already exists.
  Future<bool> _recoverInterruptedSignUp({
    required String email,
    required String password,
    required String name,
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
    final User user;
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final signedIn = credential.user;
      if (signedIn == null) return false;
      user = signedIn;
    } on FirebaseAuthException {
      // Wrong password / disabled / etc. — not an account this flow can claim.
      return false;
    }

    // If a real profile already exists, only treat it as "ours" when the role
    // matches what was requested; otherwise leave it untouched and let the
    // friendly error surface (do not clobber another account's role).
    final existing = await _db.collection('users').doc(user.uid).get();
    if (existing.exists) {
      final existingRole = AppUser.fromDoc(existing).role;
      return existingRole == _safeRequestedRole(requestedRole);
    }

    // No profile doc yet: finish the interrupted signup by writing the correct
    // role doc now.
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
    await refreshCurrentUserProfileState(displayName: name);
    return true;
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
    // NOTE: updateDisplayName intentionally NOT called here. signUp sets the
    // display name only after the Firestore profile doc is written, so the role
    // doc lands before any extra Auth round-trip widens the race window.
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

      // SECURITY-CRITICAL ORDERING: the users/{uid} doc (role:'promoter',
      // status:'approved', isActive:true) is written and AWAITED above BEFORE
      // this referralCodes write. The firestore.rules referralCodes create
      // check (isPromoter() + currentPromoterCode()) reads that committed
      // users doc, so it only passes because the write completed first.
      // DO NOT batch, reorder, or run these writes concurrently, or promoter
      // signup will hit permission-denied (the original signup race).
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

    // Never overwrite an existing profile (preserves the real role/status).
    if (doc.exists) return AppUser.fromDoc(doc);

    // A signup is writing the correct role doc right now. Do NOT create a default
    // 'user' doc that would race it. Wait briefly for the real doc to appear and
    // return it; only fall through to the fallback if it never arrives.
    if (_isSigningUp) {
      final pending = await _waitForProfileDoc(ref);
      if (pending != null) return pending;
      // Signup never produced a doc (e.g. it failed). Fall through to the
      // last-resort merge below so the user isn't left with no profile at all.
    }

    // Last-resort fallback for an account that has no profile doc at all. Use
    // merge so that if a role write lands concurrently it is never clobbered:
    // each field is only filled when still missing, and 'role' in particular is
    // written only when absent.
    final fresh = await ref.get();
    if (fresh.exists) return AppUser.fromDoc(fresh);

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

      // Role details — default only because this doc did not exist.
      'role': 'user',
      'status': 'approved',
      'clubId': null,
      'promoterCode': null,

      // System fields
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive': true,
    }, SetOptions(merge: true));

    final next = await ref.get();
    return AppUser.fromDoc(next);
  }

  /// Polls for a profile doc that another flow (signup) is in the process of
  /// writing. Returns the [AppUser] once it exists, or null if it does not
  /// appear within the budget.
  Future<AppUser?> _waitForProfileDoc(
    DocumentReference<Map<String, dynamic>> ref, {
    int attempts = 10,
    Duration interval = const Duration(milliseconds: 300),
  }) async {
    for (var i = 0; i < attempts; i++) {
      await Future<void>.delayed(interval);
      final snapshot = await ref.get();
      if (snapshot.exists) return AppUser.fromDoc(snapshot);
      if (!_isSigningUp) break; // signup finished without writing — stop waiting
    }
    return null;
  }

  Future<void> signOut() async {
    _requestedRole = null;
    ReferralService.instance.clear();
    try {
      await NotificationService.instance.clearFcmToken();
    } catch (_) {
      // Clearing the FCM token is best-effort and must not block sign-out.
    }
    await _auth.signOut();
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
