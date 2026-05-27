import 'package:cloud_firestore/cloud_firestore.dart';

class Promoter {
  const Promoter({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.email,
    required this.referralCode,
    required this.totalRsvps,
    required this.createdAt,
    required this.isActive,
  });

  final String id;
  final String userId;
  final String name;
  final String phone;
  final String email;
  final String referralCode;
  final int totalRsvps;
  final DateTime createdAt;
  final bool isActive;

  factory Promoter.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Promoter(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String? ?? '',
      referralCode: data['referralCode'] as String? ?? '',
      totalRsvps: (data['totalRsvps'] as num?)?.toInt() ?? 0,
      createdAt: _readDate(data['createdAt']),
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  static DateTime _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
