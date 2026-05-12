import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.status,
    required this.clubId,
    required this.promoterCode,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String status;
  final String? clubId;
  final String? promoterCode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  bool get isUser => role == 'user';
  bool get isPromoter => role == 'promoter';
  bool get isClubAdmin => role == 'clubAdmin';
  bool get isSuperAdmin => role == 'superAdmin';
  bool get isApproved => status == 'approved' && isActive;
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppUser(
      uid: data['uid'] as String? ?? doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      role: _normalizeRole(data['role'] as String?),
      status: data['status'] as String? ?? ((data['isActive'] as bool? ?? true) ? 'approved' : 'rejected'),
      clubId: data['clubId'] as String?,
      promoterCode: data['promoterCode'] as String?,
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'status': status,
      'clubId': clubId,
      'promoterCode': promoterCode,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  static String _normalizeRole(String? role) {
    if (role == 'admin') return 'superAdmin';
    return role ?? 'user';
  }

  static DateTime _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
