import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/app_user.dart';
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
    if (onlyActive) query = query.where('isActive', isEqualTo: true);
    if (city != 'All') query = query.where('city', isEqualTo: city);
    query = query.orderBy('dateTime').limit(limit);
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    final snapshot = await query.get();
    return PagedEvents(
      events: snapshot.docs.map(NightlifeEvent.fromDoc).toList(),
      lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
    );
  }

  Stream<List<NightlifeEvent>> adminEventsStream() {
    return _db
        .collection('events')
        .orderBy('dateTime', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map(NightlifeEvent.fromDoc).toList());
  }

  Stream<List<AppUser>> usersStream() {
    return _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map(AppUser.fromDoc).toList());
  }

  Stream<List<Promoter>> promotersStream() {
    return _db
        .collection('promoters')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map(Promoter.fromDoc).toList());
  }

  Stream<List<Rsvp>> allRsvpsStream() {
    return _db
        .collection('rsvps')
        .orderBy('createdAt', descending: true)
        .limit(150)
        .snapshots()
        .map((snap) => snap.docs.map(Rsvp.fromDoc).toList());
  }

  Stream<List<Rsvp>> userRsvpsStream(String userId) {
    return _db
        .collection('rsvps')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(Rsvp.fromDoc).toList());
  }

  Stream<List<Rsvp>> promoterRsvpsStream(String promoterId) {
    return _db
        .collection('rsvps')
        .where('promoterId', isEqualTo: promoterId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map(Rsvp.fromDoc).toList());
  }

  Stream<Promoter?> promoterForUserStream(String userId) {
    return _db
        .collection('promoters')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return Promoter.fromDoc(snap.docs.first);
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
    final code = promoterCode == null || promoterCode.trim().isEmpty
        ? null
        : ReferralService.normalize(promoterCode);
    Promoter? promoter;
    if (code != null) {
      final promoterSnap = await _db
          .collection('promoters')
          .where('referralCode', isEqualTo: code)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      if (promoterSnap.docs.isEmpty) {
        throw FirestoreAppException('Promoter code not found.');
      }
      promoter = Promoter.fromDoc(promoterSnap.docs.first);
    }

    final rsvpId = '${user.uid}_${event.id}';
    final rsvpRef = _db.collection('rsvps').doc(rsvpId);
    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(rsvpRef);
      if (existing.exists) {
        throw FirestoreAppException('You have already RSVP’d for this event.');
      }
      transaction.set(rsvpRef, {
        'userId': user.uid,
        'userName': user.name,
        'userPhone': user.phone,
        'eventId': event.id,
        'eventTitle': event.title,
        'promoterId': promoter?.id,
        'promoterCode': code,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (promoter != null) {
        transaction.update(_db.collection('promoters').doc(promoter.id), {
          'totalRsvps': FieldValue.increment(1),
        });
      }
    });
  }

  Future<void> updateUserRole(AppUser user, String role) async {
    await _db.collection('users').doc(user.uid).update({
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (role == 'promoter') {
      await _ensurePromoter(user, isActive: true);
    } else {
      final existing = await _db
          .collection('promoters')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();
      for (final doc in existing.docs) {
        await doc.reference.update({'isActive': false});
      }
    }
  }

  Future<void> setUserActive(String userId, bool isActive) async {
    await _db.collection('users').doc(userId).update({
      'isActive': isActive,
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
      ),
    ];
    for (final event in examples) {
      batch.set(_db.collection('events').doc(), event.toCreateMap());
    }
    await batch.commit();
  }

  Future<void> _ensurePromoter(AppUser user, {required bool isActive}) async {
    final ref = _db.collection('promoters').doc(user.uid);
    final existing = await ref.get();
    if (existing.exists) {
      await ref.update({'isActive': isActive});
      return;
    }
    await ref.set({
      'userId': user.uid,
      'name': user.name,
      'phone': user.phone,
      'email': user.email,
      'referralCode': _makeReferralCode(user),
      'totalRsvps': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': isActive,
    });
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
