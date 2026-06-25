import 'package:cloud_firestore/cloud_firestore.dart';

class Club {
  const Club({
    required this.id,
    required this.ownerId,
    required this.clubName,
    required this.ownerName,
    required this.businessEmail,
    required this.phone,
    required this.city,
    required this.address,
    required this.instagram,
    required this.googleMapsLink,
    required this.documentUrl,
    required this.gstNumber,
    required this.businessRegistrationDetails,
    required this.profilePhotoUrl,
    required this.coverBannerUrl,
    required this.verificationStatus,
    required this.createdAt,
  });

  final String id;
  final String ownerId;
  final String clubName;
  final String ownerName;
  final String businessEmail;
  final String phone;
  final String city;
  final String address;
  final String instagram;
  final String googleMapsLink;
  final String documentUrl;
  final String gstNumber;
  final String businessRegistrationDetails;
  final String profilePhotoUrl;
  final String coverBannerUrl;
  final String verificationStatus;
  final DateTime createdAt;

  factory Club.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Club(
      id: doc.id,
      ownerId: data['ownerId'] as String? ?? '',
      clubName: data['clubName'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? '',
      businessEmail: data['businessEmail'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      city: data['city'] as String? ?? '',
      address: data['address'] as String? ?? '',
      instagram: data['instagram'] as String? ?? '',
      googleMapsLink: data['googleMapsLink'] as String? ?? '',
      documentUrl: data['documentUrl'] as String? ?? '',
      gstNumber: data['gstNumber'] as String? ?? '',
      businessRegistrationDetails:
          data['businessRegistrationDetails'] as String? ?? '',
      profilePhotoUrl:
          data['profilePhotoUrl'] as String? ??
          data['profileImageUrl'] as String? ??
          data['photoUrl'] as String? ??
          '',
      coverBannerUrl: data['coverBannerUrl'] as String? ?? '',
      verificationStatus: data['verificationStatus'] as String? ?? 'pending',
      createdAt: _readDate(data['createdAt']),
    );
  }

  static DateTime _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
