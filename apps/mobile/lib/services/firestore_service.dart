import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/app_user.dart';
import '../models/club.dart';
import '../models/event.dart';
import '../models/promoter.dart';
import '../models/rsvp.dart';
import 'referral_service.dart';

class PagedEvents {
  const PagedEvents({required this.events, required this.lastDocument});

  final List<NightlifeEvent> events;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
}

class FirestoreService {
  FirestoreService._();

  static final instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<PagedEvents> fetchEvents({
    String city = 'All',
    bool onlyActive = true,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = AppConstants.eventPageSize,
  }) async {
    Query<Map<String, dynamic>> query = _db.collection('events');

    if (onlyActive) {
      query = query.where('isActive', isEqualTo: true);
    }

    if (city != 'All' && city.isNotEmpty) {
      query = query.where('city', isEqualTo: city);
    }

    query = query.limit(50);

    final snapshot = await query.get();

    final events =
        snapshot.docs
            .map(NightlifeEvent.fromDoc)
            .toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return PagedEvents(events: events, lastDocument: null);
  }

  Stream<List<NightlifeEvent>> adminEventsStream() {
    return _db
        .collection('events')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(NightlifeEvent.fromDoc).toList()
                ..sort((a, b) => b.dateTime.compareTo(a.dateTime)),
        );
  }

  Stream<List<AppUser>> usersStream() {
    return _db
        .collection('users')
        .limit(100)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(AppUser.fromDoc).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<List<AppUser>> pendingApprovalsStream() {
    return _db
        .collection('users')
        .where('status', isEqualTo: 'pending_review')
        .limit(100)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map(AppUser.fromDoc)
                  .where((user) => user.isClubAdmin)
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<List<Club>> clubsStream() {
    return _db
        .collection('clubs')
        .limit(100)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(Club.fromDoc).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<Club?> clubForOwnerStream(String ownerId) {
    return _db
        .collection('clubs')
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .snapshots()
        .map(
          (snap) => snap.docs.isEmpty ? null : Club.fromDoc(snap.docs.first),
        );
  }

  Stream<List<Promoter>> promotersStream() {
    return _db
        .collection('promoters')
        .limit(100)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(Promoter.fromDoc).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<List<Rsvp>> allRsvpsStream() {
    return _db
        .collection('rsvps')
        .limit(100)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(Rsvp.fromDoc).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<List<Rsvp>> userRsvpsStream(String userId) {
    return _db
        .collection('rsvps')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(Rsvp.fromDoc).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<List<Rsvp>> promoterRsvpsStream(String promoterCode) {
    // Query by promoterCode (not promoterId): the rsvps read rule authorizes a
    // promoter only via `promoterCode == currentPromoterCode()`, so the query
    // filter must constrain promoterCode for Firestore to prove access. The code
    // passed in must equal users/{uid}.promoterCode byte-for-byte (it does:
    // both derive from the same _makePromoterCode() value at signup, untrimmed).
    return _db
        .collection('rsvps')
        .where('promoterCode', isEqualTo: promoterCode)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(Rsvp.fromDoc).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<List<NightlifeEvent>> activeEventsStream() {
    return _db
        .collection('events')
        .where('isActive', isEqualTo: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(NightlifeEvent.fromDoc).toList()
                ..sort((a, b) => a.dateTime.compareTo(b.dateTime)),
        );
  }

  Stream<NightlifeEvent?> eventStream(String eventId) {
    return _db.collection('events').doc(eventId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return NightlifeEvent.fromDoc(doc);
    });
  }

  Stream<List<NightlifeEvent>> clubEventsStream(AppUser user) {
    final clubId = user.clubId;
    if (clubId == null) return Stream.value(const <NightlifeEvent>[]);

    return _db
        .collection('events')
        .where('clubId', isEqualTo: clubId)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(NightlifeEvent.fromDoc).toList()
                ..sort((a, b) => b.dateTime.compareTo(a.dateTime)),
        );
  }

  Stream<List<Rsvp>> clubRsvpsStream(AppUser user) {
    final clubId = user.clubId;
    if (clubId == null) return Stream.value(const <Rsvp>[]);

    return _db
        .collection('rsvps')
        .where('clubId', isEqualTo: clubId)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(Rsvp.fromDoc).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<Promoter?> promoterForUserStream(String userId) {
    return _db
        .collection('promoters')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .asyncMap((snap) async {
          if (snap.docs.isEmpty) return null;
          final promoter = Promoter.fromDoc(snap.docs.first);
          try {
            await _ensureReferralCode(
              promoterId: promoter.id,
              referralCode: promoter.referralCode,
              isActive: promoter.isActive,
            );
          } catch (_) {
            // Existing profiles should still load even if the referral index needs
            // a privileged backfill.
          }
          return promoter;
        });
  }

  Future<void> createOrUpdateEvent(NightlifeEvent event) async {
    final isNew = event.id.isEmpty;
    String logId = event.id;
    if (isNew) {
      final ref = await _db.collection('events').add(event.toCreateMap());
      logId = ref.id;
    } else {
      await _db.collection('events').doc(event.id).update(event.toUpdateMap());
    }
    await _logAudit(
      action: isNew ? 'event_created' : 'event_updated',
      targetId: logId,
      targetType: 'event',
      metadata: {'title': event.title, 'venueName': event.venueName},
    );
  }

  Future<void> deactivateEvent(String eventId) async {
    await _db.collection('events').doc(eventId).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteEvent(String eventId) async {
    final cleanEventId = eventId.trim();
    if (cleanEventId.isEmpty) {
      throw const FirestoreAppException('Event id is required.');
    }

    await _runFirestoreWrite(() async {
      final rsvps = await _db
          .collection('rsvps')
          .where('eventId', isEqualTo: cleanEventId)
          .get();
      var batch = _db.batch();
      var writes = 0;

      Future<void> flushIfFull() async {
        if (writes < 499) return;
        await batch.commit();
        batch = _db.batch();
        writes = 0;
      }

      batch.delete(_db.collection('events').doc(cleanEventId));
      writes += 1;
      for (final doc in rsvps.docs) {
        await flushIfFull();
        batch.delete(doc.reference);
        writes += 1;
      }

      if (writes > 0) await batch.commit();
    });
    await _logAudit(
      action: 'event_deleted',
      targetId: cleanEventId,
      targetType: 'event',
      metadata: {},
    );
  }

  Future<void> setEventFeatured(String eventId, bool isFeatured) async {
    final cleanEventId = eventId.trim();
    if (cleanEventId.isEmpty) {
      throw const FirestoreAppException('Event id is required.');
    }

    await _runFirestoreWrite(() async {
      await _db.collection('events').doc(cleanEventId).set({
        'isFeatured': isFeatured,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> updateRsvpStatus(String rsvpId, String status) async {
    await _db.collection('rsvps').doc(rsvpId).update({
      'status': status,
      'rsvpStatus': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createRsvp({
    required NightlifeEvent event,
    required AppUser user,
    String? promoterCode,
  }) async {
    const collectionPath = 'rsvps';
    final currentUserId = user.uid.trim();
    final authUserId = _auth.currentUser?.uid.trim();
    final userId = authUserId ?? currentUserId;
    final eventId = event.id.trim();
    final eventTitle = event.title.trim();


    if (authUserId == null || authUserId.isEmpty) {
      throw const FirestoreAppException('Please sign in again to RSVP.');
    }
    if (currentUserId.isNotEmpty && currentUserId != authUserId) {
    }
    if (!user.isUser || !user.isApproved) {
      throw const FirestoreAppException('Only approved users can RSVP.');
    }
    if (eventId.isEmpty) {
      throw const FirestoreAppException(
        'This event is not ready for RSVP yet.',
      );
    }
    if (eventTitle.isEmpty) {
      throw const FirestoreAppException(
        'This event is missing a title. Please try another event.',
      );
    }

    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw const FirestoreAppException(
          'Your profile could not be found. Please sign in again.',
        );
      }
      final profile = AppUser.fromDoc(userDoc);
      if (profile.uid.trim() != authUserId) {
        throw const FirestoreAppException(
          'Your session profile does not match. Please sign in again.',
        );
      }
      if (!profile.isUser || !profile.isApproved) {
        throw const FirestoreAppException('Only approved users can RSVP.');
      }

      final eventDoc = await _db.collection('events').doc(eventId).get();
      final eventData = eventDoc.data();
      if (!eventDoc.exists || eventData == null) {
        throw FirestoreAppException(
          'missing-event-id: This event could not be found.',
          debugMessage: 'missing-event-id: events/$eventId does not exist',
        );
      }
      if (eventData['isActive'] != true) {
        throw FirestoreAppException(
          'inactive-event: This event is no longer accepting RSVPs.',
          debugMessage: 'inactive-event: events/$eventId isActive is not true',
        );
      }

      final code = promoterCode == null || promoterCode.trim().isEmpty
          ? null
          : ReferralService.normalize(promoterCode);
      String? promoterId;
      String? resolvedCode;

      if (code != null) {
        final referralDoc = await _db
            .collection('referralCodes')
            .doc(code)
            .get();
        final referral = referralDoc.data();
        if (!referralDoc.exists ||
            referral == null ||
            referral['isActive'] != true) {
          throw const FirestoreAppException('Referral code is not active.');
        }
        promoterId = (referral['promoterId'] as String?)?.trim();
        resolvedCode = (referral['referralCode'] as String?)?.trim();
        if (promoterId == null || promoterId.isEmpty) {
          throw const FirestoreAppException('Referral code is not active.');
        }
        if (resolvedCode == null || resolvedCode.isEmpty) {
          resolvedCode = code;
        }
      }

      final rsvpId = '${userId}_$eventId';
      final rsvpRef = _db.collection(collectionPath).doc(rsvpId);
      final selectedEventVenueId = event.venueId?.trim();
      final firestoreVenueId = _stringValue(eventData['venueId']);
      final eventClubId = _stringValue(eventData['clubId']);
      final clubId = eventClubId?.trim().isNotEmpty == true
          ? eventClubId!.trim()
          : event.clubId?.trim();
      final createdByVenueId =
          (eventData['createdBy'] as String?)?.trim() ?? event.createdBy.trim();
      final venueId = _firstNonEmpty([
        selectedEventVenueId,
        firestoreVenueId,
        clubId,
        createdByVenueId,
        eventId,
      ])!;
      final userName = profile.name.trim();
      final userPhone = profile.phone.trim();
      final rsvpClientData = _cleanFirestorePayload({
        'userId': userId,
        'userName': userName.isEmpty ? 'Guest' : userName,
        'userPhone': userPhone,
        'eventId': eventId,
        'venueId': venueId,
        'eventTitle': eventTitle,
        'clubId': clubId,
        'promoterId': promoterId,
        'promoterCode': resolvedCode,
        'paymentMethod': 'pay_at_venue',
        'paymentStatus': 'pending_at_venue',
        'rsvpStatus': 'confirmed',
        'status': 'confirmed',
      });

      if (!_isValidRsvpClientPayload(rsvpClientData)) {
        throw FirestoreAppException(
          'invalid-payload: RSVP details are incomplete.',
          debugMessage: 'invalid-payload: $rsvpClientData',
        );
      }

      final rsvpWriteData = <String, dynamic>{
        ...rsvpClientData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      try {
        final existingRsvp = await rsvpRef.get();
        if (existingRsvp.exists) {
          throw const FirestoreAppException(
            'duplicate-rsvp: You have already RSVPed for this event.',
            debugMessage: 'duplicate-rsvp: RSVP document already exists',
          );
        }
      } on FirestoreAppException {
        rethrow;
      } on FirebaseException catch (error, stackTrace) {
        debugPrintStack(stackTrace: stackTrace);
      }


      await rsvpRef.set(rsvpWriteData);
    } on FirestoreAppException {
      rethrow;
    } on FirebaseException catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      throw FirestoreAppException(
        _friendlyFirestoreError(error),
        debugMessage:
            'FirebaseException code=${error.code} message=${error.message}',
      );
    } on Exception catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      throw FirestoreAppException(
        'Unable to create RSVP right now. Please try again.',
        debugMessage: error.toString(),
      );
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      throw FirestoreAppException(
        'Unable to create RSVP right now. Please try again.',
        debugMessage: error.toString(),
      );
    }
  }

  Future<void> updateUserRole(AppUser user, String role) async {
    final approvedImmediately = role != 'clubAdmin';
    final referralCode = role == 'promoter'
        ? user.promoterCode ?? _makeReferralCode(user)
        : null;

    await _db.collection('users').doc(user.uid).update({
      'role': role,
      'status': approvedImmediately ? 'approved' : 'pending',
      'promoterCode': ?referralCode,
      if (role != 'promoter') 'promoterCode': null,
      if (role == 'promoter') 'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (role == 'promoter') {
      await _ensurePromoter(user, isActive: true, referralCode: referralCode);
    } else {
      final existing = await _db
          .collection('promoters')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      for (final doc in existing.docs) {
        await doc.reference.update({'isActive': false});
      }
      await _deactivateReferralCode(user.promoterCode);
    }
  }

  Future<void> setUserActive(String userId, bool isActive) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    final user = userDoc.exists ? AppUser.fromDoc(userDoc) : null;

    await _db.collection('users').doc(userId).update({
      'isActive': isActive,
      'status': isActive ? 'approved' : 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (user != null && user.isPromoter) {
      await _ensurePromoter(user, isActive: isActive);
      if (!isActive) await _deactivateReferralCode(user.promoterCode);
    }
  }

  Future<void> updateUserProfile({
    required String userId,
    required String name,
    required String phone,
    required String city,
    String? profilePhotoUrl,
  }) async {
    final cleanUserId = userId.trim();
    final cleanName = name.trim();
    if (cleanUserId.isEmpty) {
      throw const FirestoreAppException('User id is required.');
    }
    if (cleanName.isEmpty) {
      throw const FirestoreAppException('Name cannot be empty.');
    }

    final updates = <String, dynamic>{
      'name': cleanName,
      'phone': phone.trim(),
      'lastKnownCity': city.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final cleanPhotoUrl = profilePhotoUrl?.trim();
    if (cleanPhotoUrl != null && cleanPhotoUrl.isNotEmpty) {
      updates['profilePhotoUrl'] = cleanPhotoUrl;
      updates['profileImageUrl'] = cleanPhotoUrl;
      updates['photoUrl'] = cleanPhotoUrl;
    }

    await _runFirestoreWrite(() async {
      await _db
          .collection('users')
          .doc(cleanUserId)
          .set(updates, SetOptions(merge: true))
          .timeout(const Duration(seconds: 20));
    });
  }

  Future<void> updateUserProfilePhoto({
    required String userId,
    required String profilePhotoUrl,
  }) async {
    final cleanUserId = userId.trim();
    final cleanPhotoUrl = profilePhotoUrl.trim();
    if (cleanUserId.isEmpty) {
      throw const FirestoreAppException('User id is required.');
    }
    if (cleanPhotoUrl.isEmpty) {
      throw const FirestoreAppException('Profile photo URL is required.');
    }

    await _runFirestoreWrite(() async {
      await _db
          .collection('users')
          .doc(cleanUserId)
          .set({
            'profileImageUrl': cleanPhotoUrl,
            'profilePhotoUrl': cleanPhotoUrl,
            'photoUrl': cleanPhotoUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 20));
    });
  }

  Future<void> setPromoterActive(Promoter promoter, bool isActive) async {
    final promoterId = promoter.id.trim();
    final userId = promoter.userId.trim().isEmpty
        ? promoterId
        : promoter.userId.trim();
    if (promoterId.isEmpty && userId.isEmpty) {
      throw const FirestoreAppException('Promoter id is required.');
    }

    await _runFirestoreWrite(() async {
      final batch = _db.batch();
      if (promoterId.isNotEmpty) {
        batch.set(_db.collection('promoters').doc(promoterId), {
          'isActive': isActive,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      if (userId.isNotEmpty) {
        batch.set(_db.collection('users').doc(userId), {
          'isActive': isActive,
          'status': isActive ? 'approved' : 'rejected',
          'verificationStatus': isActive ? 'approved' : 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
      await _ensureReferralCode(
        promoterId: promoterId.isEmpty ? userId : promoterId,
        referralCode: promoter.referralCode,
        isActive: isActive,
      );
    });
    await _logAudit(
      action: isActive ? 'promoter_activated' : 'promoter_deactivated',
      targetId: promoter.id,
      targetType: 'promoter',
      metadata: {'name': promoter.name},
    );
  }

  Future<void> approveUser(AppUser user) async {
    final updates = <String, dynamic>{
      'status': 'approved',
      'verificationStatus': 'approved',
      'isActive': true,
      'onboardingCompleted': true,
      'rejectionReason': '',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (user.isPromoter) {
      final code = user.promoterCode ?? _makeReferralCode(user);
      updates['promoterCode'] = code;
      await _ensurePromoter(user, isActive: true, referralCode: code);
    }

    if (user.isClubAdmin && user.clubId != null) {
      await _db.collection('clubs').doc(user.clubId).update({
        'verificationStatus': 'approved',
        'rejectionReason': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else if (user.isClubAdmin) {
      throw const FirestoreAppException(
        'Club onboarding must be completed first.',
      );
    }

    await _db.collection('users').doc(user.uid).update(updates);
    await _logAudit(
      action: 'user_approved',
      targetId: user.uid,
      targetType: 'user',
      metadata: {'role': user.role, 'name': user.name},
    );
  }

  Future<void> rejectUser(AppUser user) async {
    await _db.collection('users').doc(user.uid).update({
      'status': 'rejected',
      'verificationStatus': 'rejected',
      'isActive': false,
      'rejectionReason': 'Rejected by admin',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _logAudit(
      action: 'user_rejected',
      targetId: user.uid,
      targetType: 'user',
      metadata: {'role': user.role, 'name': user.name},
    );

    if (user.isClubAdmin && user.clubId != null) {
      await _db.collection('clubs').doc(user.clubId).update({
        'verificationStatus': 'rejected',
      });
    }

    if (user.isPromoter) {
      await _ensurePromoter(user, isActive: false);
      await _deactivateReferralCode(user.promoterCode);
    }
  }

  Future<void> rejectUserReview(AppUser user, {String? rejectionReason}) async {
    await _runFirestoreWrite(() async {
      final reason = rejectionReason?.trim() ?? '';
      final batch = _db.batch();
      batch.set(_db.collection('users').doc(user.uid), {
        'status': 'rejected',
        'verificationStatus': 'rejected',
        'isActive': false,
        'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (user.isClubAdmin && user.clubId != null) {
        batch.set(_db.collection('clubs').doc(user.clubId), {
          'verificationStatus': 'rejected',
          'rejectionReason': reason,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
      if (user.isPromoter) {
        await _ensurePromoter(user, isActive: false);
        await _deactivateReferralCode(user.promoterCode);
      }
    });
    await _logAudit(
      action: 'user_rejected',
      targetId: user.uid,
      targetType: 'user',
      metadata: {'role': user.role, 'name': user.name, 'reason': rejectionReason ?? ''},
    );
  }

  Future<void> approveClubReview(Club club) async {
    final clubId = club.id.trim();
    if (clubId.isEmpty) {
      throw const FirestoreAppException('Club id is required.');
    }

    await _runFirestoreWrite(() async {
      final batch = _db.batch();
      batch.set(_db.collection('clubs').doc(clubId), {
        'verificationStatus': 'approved',
        'rejectionReason': '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (club.ownerId.trim().isNotEmpty) {
        batch.set(_db.collection('users').doc(club.ownerId), {
          'clubId': clubId,
          'status': 'approved',
          'verificationStatus': 'approved',
          'isActive': true,
          'onboardingCompleted': true,
          'rejectionReason': '',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
    });
    await _logAudit(
      action: 'club_approved',
      targetId: club.id,
      targetType: 'club',
      metadata: {'clubName': club.clubName},
    );
  }

  Future<void> rejectClubReview(Club club, {String? rejectionReason}) async {
    final clubId = club.id.trim();
    if (clubId.isEmpty) {
      throw const FirestoreAppException('Club id is required.');
    }

    await _runFirestoreWrite(() async {
      final reason = rejectionReason?.trim() ?? '';
      final batch = _db.batch();
      batch.set(_db.collection('clubs').doc(clubId), {
        'verificationStatus': 'rejected',
        'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (club.ownerId.trim().isNotEmpty) {
        batch.set(_db.collection('users').doc(club.ownerId), {
          'clubId': clubId,
          'status': 'rejected',
          'verificationStatus': 'rejected',
          'isActive': false,
          'rejectionReason': reason,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
    });
    await _logAudit(
      action: 'club_rejected',
      targetId: club.id,
      targetType: 'club',
      metadata: {'clubName': club.clubName, 'reason': rejectionReason ?? ''},
    );
  }

  Future<void> submitClubOnboarding({
    required AppUser user,
    required String clubName,
    required String ownerName,
    required String businessEmail,
    required String phone,
    required String city,
    required String address,
    required String instagram,
    required String googleMapsLink,
    required String documentUrl,
  }) async {
    final clubRef = user.clubId == null
        ? _db.collection('clubs').doc()
        : _db.collection('clubs').doc(user.clubId);

    await clubRef.set({
      'ownerId': user.uid,
      'clubName': clubName.trim(),
      'ownerName': ownerName.trim(),
      'businessEmail': businessEmail.trim().toLowerCase(),
      'phone': phone.trim(),
      'city': city.trim(),
      'address': address.trim(),
      'instagram': instagram.trim(),
      'googleMapsLink': googleMapsLink.trim(),
      'documentUrl': documentUrl.trim(),
      'verificationStatus': 'pending_review',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _db.collection('users').doc(user.uid).update({
      'role': 'clubAdmin',
      'status': 'pending_review',
      'clubId': clubRef.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitVerificationDetails({
    required AppUser user,
    required String businessName,
    required String gstNumber,
    required String ownerName,
    required String businessPhone,
    required String businessAddress,
    required String city,
    required String instagramLink,
    required String documentUploadStatus,
  }) async {
    if (!user.isClubAdmin) {
      throw const FirestoreAppException(
        'Only venue admin accounts can submit verification details.',
      );
    }

    final cleanBusinessName = businessName.trim();
    final cleanOwnerName = ownerName.trim();
    final cleanBusinessPhone = businessPhone.trim();
    final cleanBusinessAddress = businessAddress.trim();
    if (cleanBusinessName.isEmpty ||
        cleanOwnerName.isEmpty ||
        cleanBusinessPhone.isEmpty ||
        cleanBusinessAddress.isEmpty ||
        city.trim().isEmpty) {
      throw const FirestoreAppException(
        'Complete all required verification details.',
      );
    }

    await _runFirestoreWrite(() async {
      final clubRef = user.clubId == null || user.clubId!.trim().isEmpty
          ? _db.collection('clubs').doc()
          : _db.collection('clubs').doc(user.clubId);
      final cleanCity = city.trim();
      final cleanInstagram = instagramLink.trim();
      final cleanDocumentStatus = documentUploadStatus.trim().isEmpty
          ? 'pending_upload'
          : documentUploadStatus.trim();

      final batch = _db.batch();
      batch.set(_db.collection('users').doc(user.uid), {
        'role': 'clubAdmin',
        'status': 'pending_review',
        'verificationStatus': 'pending_review',
        'documentUploadStatus': cleanDocumentStatus,
        'onboardingCompleted': true,
        'rejectionReason': '',
        'clubId': clubRef.id,
        'businessName': cleanBusinessName,
        'venueName': cleanBusinessName,
        'gstNumber': gstNumber.trim(),
        'ownerName': cleanOwnerName,
        'businessPhone': cleanBusinessPhone,
        'businessAddress': cleanBusinessAddress,
        'city': cleanCity,
        'instagramLink': cleanInstagram,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(clubRef, {
        'ownerId': user.uid,
        'clubName': cleanBusinessName,
        'ownerName': cleanOwnerName,
        'businessEmail': user.email.trim().toLowerCase(),
        'phone': cleanBusinessPhone,
        'city': cleanCity,
        'address': cleanBusinessAddress,
        'instagram': cleanInstagram,
        'documentUploadStatus': cleanDocumentStatus,
        'verificationStatus': 'pending_review',
        'rejectionReason': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await batch.commit();
    });
  }

  Future<void> updateUserLastKnownLocation({
    required String userId,
    required double latitude,
    required double longitude,
    required String city,
    required String fullAddress,
  }) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return;

    await _runFirestoreWrite(() async {
      await _db.collection('users').doc(cleanUserId).set({
        'lastLatitude': latitude,
        'lastLongitude': longitude,
        'lastKnownCity': city.trim(),
        'lastKnownAddress': fullAddress.trim(),
        'lastLocationAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> setMaintenanceMode(bool enabled) async {
    await _runFirestoreWrite(() async {
      await _db.collection('platform').doc('settings').set({
        'maintenanceMode': enabled,
        'maintenanceModeUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<Map<String, dynamic>> userRecordData(String userId) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return const <String, dynamic>{};

    return _runFirestoreRead(() async {
      final doc = await _db.collection('users').doc(cleanUserId).get();
      final data = _docData(doc, fallbackIdKey: 'uid');
      if (data.isEmpty) return {'uid': cleanUserId};

      final clubId = data['clubId'] as String?;
      if (clubId != null && clubId.trim().isNotEmpty) {
        final clubDoc = await _db.collection('clubs').doc(clubId).get();
        final clubData = _docData(clubDoc, fallbackIdKey: 'clubId');
        if (clubData.isNotEmpty) data['club'] = clubData;
      }

      return _withRecordDefaults(data);
    }, const <String, dynamic>{});
  }

  Future<Map<String, dynamic>> promoterRecordData(String promoterId) async {
    final cleanPromoterId = promoterId.trim();
    if (cleanPromoterId.isEmpty) return const <String, dynamic>{};

    return _runFirestoreRead(() async {
      var promoterDoc = await _db
          .collection('promoters')
          .doc(cleanPromoterId)
          .get();
      if (!promoterDoc.exists) {
        final query = await _db
            .collection('promoters')
            .where('userId', isEqualTo: cleanPromoterId)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) promoterDoc = query.docs.first;
      }

      final promoterData = _docData(promoterDoc, fallbackIdKey: 'promoterId');
      if (promoterData.isEmpty) return {'promoterId': cleanPromoterId};

      final userId = promoterData['userId'] as String? ?? cleanPromoterId;
      final userDoc = await _db.collection('users').doc(userId).get();
      final userData = _docData(userDoc, fallbackIdKey: 'uid');

      return _withRecordDefaults({
        ...userData,
        ...promoterData,
        'uid': userId,
        'promoterId': promoterDoc.id,
      });
    }, const <String, dynamic>{});
  }

  Future<Map<String, dynamic>> clubRecordData(String clubId) async {
    final cleanClubId = clubId.trim();
    if (cleanClubId.isEmpty) return const <String, dynamic>{};

    return _runFirestoreRead(() async {
      final clubDoc = await _db.collection('clubs').doc(cleanClubId).get();
      final clubData = _docData(clubDoc, fallbackIdKey: 'clubId');
      if (clubData.isEmpty) return {'clubId': cleanClubId};

      final ownerId = clubData['ownerId'] as String?;
      final userData = <String, dynamic>{};
      if (ownerId != null && ownerId.trim().isNotEmpty) {
        final userDoc = await _db.collection('users').doc(ownerId).get();
        userData.addAll(_docData(userDoc, fallbackIdKey: 'uid'));
      }

      return _withRecordDefaults({
        ...userData,
        ...clubData,
        'clubId': cleanClubId,
      });
    }, const <String, dynamic>{});
  }

  Future<void> seedDemoEvents(String adminId) async {
    final batch = _db.batch();

    final examples = [
      NightlifeEvent.empty(createdBy: adminId).copyWith(
        title: 'Neon Friday Social',
        city: 'Guwahati',
        venueName: 'The Electric Room',
        address: 'GS Road, Guwahati',
        dateTime: DateTime.now().add(const Duration(days: 4, hours: 5)),
        musicType: 'Commercial, Hip-Hop, Afro',
        crowdType: 'College, young professionals',
        entryRules: 'Couples and guestlist preferred. Valid ID required.',
        description:
            'A high-energy Friday night built for RSVP-driven discovery.',
        priceText: 'Guestlist entry before 10 PM',
        posterUrl: '',
        isActive: true,
      ),
      NightlifeEvent.empty(createdBy: adminId).copyWith(
        title: 'Delhi Bassline Sessions',
        city: 'Delhi',
        venueName: 'Warehouse 27',
        address: 'Mehrauli, New Delhi',
        dateTime: DateTime.now().add(const Duration(days: 6, hours: 4)),
        musicType: 'House, Techno',
        crowdType: 'Premium club crowd',
        entryRules: 'Smart casuals. Stags subject to door policy.',
        description:
            'Underground sounds, RSVP credits, and promoter-led distribution.',
        priceText: 'Cover starts at INR 999',
        posterUrl: '',
        isActive: true,
      ),
    ];

    for (final event in examples) {
      batch.set(_db.collection('events').doc(), event.toCreateMap());
    }

    await batch.commit();
  }

  Future<void> _logAudit({
    required String action,
    required String targetId,
    String? targetType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _db.collection('audit_logs').add({
        'action': action,
        'targetId': targetId,
        'targetType': targetType ?? '',
        'performedBy': _auth.currentUser?.uid ?? 'system',
        'performedByEmail': _auth.currentUser?.email ?? 'system',
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Audit log failure must never crash the app
    }
  }

  Future<void> _ensurePromoter(
    AppUser user, {
    required bool isActive,
    String? referralCode,
  }) async {
    final ref = _db.collection('promoters').doc(user.uid);
    final existing = await ref.get();

    if (existing.exists) {
      await ref.update({'isActive': isActive, 'referralCode': ?referralCode});
      final existingReferralCode = existing.data()?['referralCode'] as String?;
      await _ensureReferralCode(
        promoterId: user.uid,
        referralCode: referralCode ?? existingReferralCode,
        isActive: isActive,
      );
      return;
    }

    final code = referralCode ?? _makeReferralCode(user);
    await ref.set({
      'userId': user.uid,
      'name': user.name,
      'phone': user.phone,
      'email': user.email,
      'referralCode': code,
      'totalRsvps': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': isActive,
    });
    await _ensureReferralCode(
      promoterId: user.uid,
      referralCode: code,
      isActive: isActive,
    );
  }

  Future<void> _ensureReferralCode({
    required String promoterId,
    required String? referralCode,
    required bool isActive,
  }) async {
    if (referralCode == null || referralCode.trim().isEmpty) return;
    final code = ReferralService.normalize(referralCode);
    await _db.collection('referralCodes').doc(code).set({
      'promoterId': promoterId,
      'referralCode': code,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _deactivateReferralCode(String? referralCode) async {
    if (referralCode == null || referralCode.trim().isEmpty) return;
    await _db
        .collection('referralCodes')
        .doc(ReferralService.normalize(referralCode))
        .set({
          'isActive': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  String _makeReferralCode(AppUser user) {
    final base = user.name
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .padRight(4, 'X')
        .substring(0, 4);

    return '$base${user.uid.substring(0, 4).toUpperCase()}';
  }

  Map<String, dynamic> _docData(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String fallbackIdKey,
  }) {
    final data = doc.data();
    if (!doc.exists || data == null) return <String, dynamic>{};
    return {fallbackIdKey: data[fallbackIdKey] ?? doc.id, ...data};
  }

  Map<String, dynamic> _withRecordDefaults(Map<String, dynamic> data) {
    return {
      'name': '',
      'email': '',
      'phone': '',
      'role': '',
      'status': '',
      'verificationStatus': '',
      'documentUploadStatus': '',
      'onboardingCompleted': false,
      'isActive': false,
      'isApproved':
          data['status'] == 'approved' && (data['isActive'] as bool? ?? false),
      'rejectionReason': '',
      'documentUrl': '',
      'validIdUrl': '',
      ...data,
    };
  }

  Map<String, dynamic> _cleanFirestorePayload(Map<String, dynamic> payload) {
    final clean = <String, dynamic>{};
    for (final entry in payload.entries) {
      final value = entry.value;
      if (value == null) continue;
      clean[entry.key] = value;
    }
    return clean;
  }

  bool _isValidRsvpClientPayload(Map<String, dynamic> payload) {
    return _stringValue(payload['userId'])?.isNotEmpty == true &&
        _stringValue(payload['userName'])?.isNotEmpty == true &&
        payload['userPhone'] is String &&
        _stringValue(payload['eventId'])?.isNotEmpty == true &&
        _stringValue(payload['venueId'])?.isNotEmpty == true &&
        _stringValue(payload['eventTitle'])?.isNotEmpty == true &&
        payload['paymentMethod'] == 'pay_at_venue' &&
        payload['paymentStatus'] == 'pending_at_venue' &&
        payload['rsvpStatus'] == 'confirmed' &&
        payload['status'] == 'confirmed' &&
        payload.values.every(_isFirestoreSerializableValue);
  }

  bool _isFirestoreSerializableValue(Object? value) {
    if (value == null) return false;
    if (value is String ||
        value is num ||
        value is bool ||
        value is Timestamp) {
      return true;
    }
    if (value is GeoPoint || value is DocumentReference) {
      return true;
    }
    if (value is Iterable) {
      return value.every(_isFirestoreSerializableValue);
    }
    if (value is Map) {
      return value.keys.every((key) => key is String) &&
          value.values.every(_isFirestoreSerializableValue);
    }
    return false;
  }

  String? _stringValue(Object? value) {
    if (value is String) return value.trim();
    return null;
  }

  String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  Future<T> _runFirestoreRead<T>(
    Future<T> Function() action,
    T fallback,
  ) async {
    try {
      return await action();
    } on FirebaseException {
      return fallback;
    }
  }

  Future<void> _runFirestoreWrite(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseException catch (error) {
      throw FirestoreAppException(
        error.message ?? 'Unable to update Firestore right now.',
      );
    }
  }

  String _friendlyFirestoreError(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' =>
        'You do not have permission to RSVP for this event.',
      'unavailable' =>
        'RSVP service is temporarily unavailable. Please try again.',
      'deadline-exceeded' =>
        'RSVP request timed out. Please check your connection and try again.',
      'not-found' => 'This event or profile could not be found.',
      'already-exists' => 'You have already RSVPed for this event.',
      _ =>
        error.message == null || error.message!.trim().isEmpty
            ? 'Unable to create RSVP right now. Please try again.'
            : 'Unable to create RSVP: ${error.message}',
    };
  }
}

class FirestoreAppException implements Exception {
  const FirestoreAppException(this.message, {this.debugMessage});

  final String message;
  final String? debugMessage;

  @override
  String toString() => message;
}
