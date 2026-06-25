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
    required this.lastLatitude,
    required this.lastLongitude,
    required this.lastKnownCity,
    required this.lastKnownAddress,
    required this.profilePhotoUrl,
    required this.coverBannerUrl,
    required this.venueName,
    required this.businessName,
    required this.city,
    required this.businessPhone,
    required this.businessAddress,
    required this.gstNumber,
    required this.businessRegistrationDetails,
    required this.contactEmail,
    required this.verificationStatus,
    required this.documentUploadStatus,
    required this.onboardingCompleted,
    required this.rejectionReason,
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
  final double? lastLatitude;
  final double? lastLongitude;
  final String lastKnownCity;
  final String lastKnownAddress;
  final String profilePhotoUrl;
  final String coverBannerUrl;
  final String venueName;
  final String businessName;
  final String city;
  final String businessPhone;
  final String businessAddress;
  final String gstNumber;
  final String businessRegistrationDetails;
  final String contactEmail;
  final String verificationStatus;
  final String documentUploadStatus;
  final bool onboardingCompleted;
  final String rejectionReason;

  bool get isUser => role == 'user';
  bool get isPromoter => role == 'promoter';
  bool get isClubAdmin => role == 'clubAdmin';
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
      status:
          data['status'] as String? ??
          ((data['isActive'] as bool? ?? true) ? 'approved' : 'rejected'),
      clubId: data['clubId'] as String?,
      promoterCode: data['promoterCode'] as String?,
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
      isActive: data['isActive'] as bool? ?? true,
      lastLatitude: _readDouble(data['lastLatitude']),
      lastLongitude: _readDouble(data['lastLongitude']),
      lastKnownCity: data['lastKnownCity'] as String? ?? '',
      lastKnownAddress: data['lastKnownAddress'] as String? ?? '',
      profilePhotoUrl:
          data['profilePhotoUrl'] as String? ??
          data['profileImageUrl'] as String? ??
          data['photoUrl'] as String? ??
          '',
      coverBannerUrl: data['coverBannerUrl'] as String? ?? '',
      venueName: data['venueName'] as String? ?? '',
      businessName: data['businessName'] as String? ?? '',
      city: data['city'] as String? ?? '',
      businessPhone: data['businessPhone'] as String? ?? '',
      businessAddress: data['businessAddress'] as String? ?? '',
      gstNumber: data['gstNumber'] as String? ?? '',
      businessRegistrationDetails:
          data['businessRegistrationDetails'] as String? ?? '',
      contactEmail: data['contactEmail'] as String? ?? '',
      verificationStatus:
          data['verificationStatus'] as String? ??
          data['status'] as String? ??
          '',
      documentUploadStatus:
          data['documentUploadStatus'] as String? ?? 'not_selected',
      onboardingCompleted:
          data['onboardingCompleted'] as bool? ??
          roleSkipsOnboarding(data['role'] as String?),
      rejectionReason: data['rejectionReason'] as String? ?? '',
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
      'lastLatitude': lastLatitude,
      'lastLongitude': lastLongitude,
      'lastKnownCity': lastKnownCity,
      'lastKnownAddress': lastKnownAddress,
      'profilePhotoUrl': profilePhotoUrl,
      'coverBannerUrl': coverBannerUrl,
      'venueName': venueName,
      'businessName': businessName,
      'city': city,
      'businessPhone': businessPhone,
      'businessAddress': businessAddress,
      'gstNumber': gstNumber,
      'businessRegistrationDetails': businessRegistrationDetails,
      'contactEmail': contactEmail,
      'verificationStatus': verificationStatus,
      'documentUploadStatus': documentUploadStatus,
      'onboardingCompleted': onboardingCompleted,
      'rejectionReason': rejectionReason,
    };
  }

  static bool roleIsUser(String? role) {
    return _normalizeRole(role) == 'user';
  }

  static bool roleSkipsOnboarding(String? role) {
    final normalizedRole = _normalizeRole(role);
    return normalizedRole == 'user' || normalizedRole == 'promoter';
  }

  static String _normalizeRole(String? role) {
    return role ?? 'user';
  }

  static DateTime _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static double? _readDouble(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return null;
  }
}
