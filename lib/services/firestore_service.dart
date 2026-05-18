import 'package:cloud_firestore/cloud_firestore.dart';

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

    final snapshot = await query.get();

    final events = snapshot.docs
        .map(NightlifeEvent.fromDoc)
        .where((event) => city == 'All' || event.city == city)
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return PagedEvents(
      events: events,
      lastDocument: null,
    );
  }

  Stream<List<NightlifeEvent>> adminEventsStream() {
    return _db.collection('events').snapshots().map(
          (snap) => snap.docs.map(NightlifeEvent.fromDoc).toList()
            ..sort((a, b) => b.dateTime.compareTo(a.dateTime)),
        );
  }

  Stream<List<AppUser>> usersStream() {
    return _db.collection('users').snapshots().map(
          (snap) => snap.docs.map(AppUser.fromDoc).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<List<AppUser>> pendingApprovalsStream() {
    return _db
        .collection('users')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(AppUser.fromDoc)
              .where((user) => user.isClubAdmin)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<List<Club>> clubsStream() {
    return _db.collection('clubs').snapshots().map(
          (snap) => snap.docs.map(Club.fromDoc).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<Club?> clubForOwnerStream(String ownerId) {
    return _db
        .collection('clubs')
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty ? null : Club.fromDoc(snap.docs.first));
  }

  Stream<List<Promoter>> promotersStream() {
    return _db.collection('promoters').snapshots().map(
          (snap) => snap.docs.map(Promoter.fromDoc).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<List<Rsvp>> allRsvpsStream() {
    return _db.collection('rsvps').snapshots().map(
          (snap) => snap.docs.map(Rsvp.fromDoc).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<List<Rsvp>> userRsvpsStream(String userId) {
    return _db
        .collection('rsvps')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snap) => snap.docs.map(Rsvp.fromDoc).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<List<Rsvp>> promoterRsvpsStream(String promoterId) {
    return _db
        .collection('rsvps')
        .where('promoterId', isEqualTo: promoterId)
        .snapshots()
        .map(
          (snap) => snap.docs.map(Rsvp.fromDoc).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<List<NightlifeEvent>> activeEventsStream() {
    return _db
        .collection('events')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map(NightlifeEvent.fromDoc).toList()
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
          (snap) => snap.docs.map(NightlifeEvent.fromDoc).toList()
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
          (snap) => snap.docs.map(Rsvp.fromDoc).toList()
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
    if (event.id.isEmpty) {
      await _db.collection('events').add(event.toCreateMap());
    } else {
      await _db.collection('events').doc(event.id).update(event.toUpdateMap());
    }
  }

  Future<void> deactivateEvent(String eventId) async {
    await _db.collection('events').doc(eventId).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateRsvpStatus(String rsvpId, String status) async {
    await _db.collection('rsvps').doc(rsvpId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createRsvp({
    required NightlifeEvent event,
    required AppUser user,
    String? promoterCode,
  }) async {
    if (!user.isUser || !user.isApproved) {
      throw const FirestoreAppException('Only approved user accounts can RSVP.');
    }

    final code = promoterCode == null || promoterCode.trim().isEmpty
        ? null
        : ReferralService.normalize(promoterCode);
    String? promoterId;
    String? resolvedCode;

    if (code != null) {
      final referralDoc = await _db.collection('referralCodes').doc(code).get();
      final referral = referralDoc.data();
      if (!referralDoc.exists ||
          referral == null ||
          referral['isActive'] != true) {
        throw const FirestoreAppException('Referral code is not active.');
      }
      promoterId = referral['promoterId'] as String?;
      resolvedCode = referral['referralCode'] as String? ?? code;
      if (promoterId == null || promoterId.trim().isEmpty) {
        throw const FirestoreAppException('Referral code is not active.');
      }
    }

    final rsvpId = '${user.uid}_${event.id}';
    final rsvpRef = _db.collection('rsvps').doc(rsvpId);

    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(rsvpRef);

      if (existing.exists) {
        throw FirestoreAppException('You have already RSVPed for this event.');
      }

      transaction.set(rsvpRef, {
        'userId': user.uid,
        'userName': user.name,
        'userPhone': user.phone,
        'eventId': event.id,
        'eventTitle': event.title,
        'clubId': event.clubId,
        'promoterId': promoterId,
        'promoterCode': resolvedCode,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> updateUserRole(AppUser user, String role) async {
    final approvedImmediately = role != 'clubAdmin';
    final referralCode = role == 'promoter'
        ? user.promoterCode ?? _makeReferralCode(user)
        : null;

    await _db.collection('users').doc(user.uid).update({
      'role': role,
      'status': approvedImmediately ? 'approved' : 'pending',
      if (referralCode != null) 'promoterCode': referralCode,
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

  Future<void> approveUser(AppUser user) async {
    final updates = <String, dynamic>{
      'status': 'approved',
      'isActive': true,
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
      });
    } else if (user.isClubAdmin) {
      throw const FirestoreAppException(
        'Club onboarding must be completed first.',
      );
    }

    await _db.collection('users').doc(user.uid).update(updates);
  }

  Future<void> rejectUser(AppUser user) async {
    await _db.collection('users').doc(user.uid).update({
      'status': 'rejected',
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });

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
      'verificationStatus': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _db.collection('users').doc(user.uid).update({
      'role': 'clubAdmin',
      'status': 'pending',
      'clubId': clubRef.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

  Future<void> _ensurePromoter(
    AppUser user, {
    required bool isActive,
    String? referralCode,
  }) async {
    final ref = _db.collection('promoters').doc(user.uid);
    final existing = await ref.get();

    if (existing.exists) {
      await ref.update({
        'isActive': isActive,
        if (referralCode != null) 'referralCode': referralCode,
      });
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
}

class FirestoreAppException implements Exception {
  const FirestoreAppException(this.message);

  final String message;

  @override
  String toString() => message;
}
