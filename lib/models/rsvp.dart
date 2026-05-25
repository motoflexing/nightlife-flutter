import 'package:cloud_firestore/cloud_firestore.dart';

class Rsvp {
  const Rsvp({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.eventId,
    required this.eventTitle,
    required this.venueId,
    required this.clubId,
    required this.promoterId,
    required this.promoterCode,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.rsvpStatus,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final String eventId;
  final String eventTitle;
  final String venueId;
  final String? clubId;
  final String? promoterId;
  final String? promoterCode;
  final String paymentMethod;
  final String paymentStatus;
  final String rsvpStatus;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Rsvp.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final legacyStatus = data['status'] as String?;
    final rsvpStatus =
        data['rsvpStatus'] as String? ?? legacyStatus ?? 'pending';
    return Rsvp(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      userPhone: data['userPhone'] as String? ?? '',
      eventId: data['eventId'] as String? ?? '',
      eventTitle: data['eventTitle'] as String? ?? '',
      venueId:
          (data['venueId'] as String?) ?? (data['clubId'] as String?) ?? '',
      clubId: data['clubId'] as String?,
      promoterId: data['promoterId'] as String?,
      promoterCode: data['promoterCode'] as String?,
      paymentMethod: data['paymentMethod'] as String? ?? '',
      paymentStatus: data['paymentStatus'] as String? ?? '',
      rsvpStatus: rsvpStatus,
      status: legacyStatus ?? rsvpStatus,
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  static DateTime _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
