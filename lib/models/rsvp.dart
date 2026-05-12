import 'package:cloud_firestore/cloud_firestore.dart';

class Rsvp {
  const Rsvp({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.eventId,
    required this.eventTitle,
    required this.clubId,
    required this.promoterId,
    required this.promoterCode,
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
  final String? clubId;
  final String? promoterId;
  final String? promoterCode;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Rsvp.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Rsvp(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      userPhone: data['userPhone'] as String? ?? '',
      eventId: data['eventId'] as String? ?? '',
      eventTitle: data['eventTitle'] as String? ?? '',
      clubId: data['clubId'] as String?,
      promoterId: data['promoterId'] as String?,
      promoterCode: data['promoterCode'] as String?,
      status: data['status'] as String? ?? 'pending',
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
