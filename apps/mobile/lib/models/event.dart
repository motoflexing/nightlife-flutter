import 'package:cloud_firestore/cloud_firestore.dart';

class NightlifeEvent {
  const NightlifeEvent({
    required this.id,
    required this.title,
    required this.city,
    required this.venueName,
    required this.address,
    required this.dateTime,
    required this.musicType,
    required this.crowdType,
    required this.entryRules,
    required this.description,
    required this.posterUrl,
    required this.priceText,
    required this.artistText,
    required this.latitude,
    required this.longitude,
    required this.googleMapsLink,
    required this.fullAddress,
    required this.isActive,
    required this.venueId,
    required this.clubId,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String city;
  final String venueName;
  final String address;
  final DateTime dateTime;
  final String musicType;
  final String crowdType;
  final String entryRules;
  final String description;
  final String posterUrl;
  final String priceText;
  final String artistText;
  final double? latitude;
  final double? longitude;
  final String googleMapsLink;
  final String fullAddress;
  final bool isActive;
  final String? venueId;
  final String? clubId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory NightlifeEvent.empty({String createdBy = ''}) {
    final now = DateTime.now().add(const Duration(days: 7));

    return NightlifeEvent(
      id: '',
      title: '',
      city: 'Guwahati',
      venueName: '',
      address: '',
      dateTime: now,
      musicType: '',
      crowdType: '',
      entryRules: '',
      description: '',
      posterUrl: '',
      priceText: '',
      artistText: '',
      latitude: null,
      longitude: null,
      googleMapsLink: '',
      fullAddress: '',
      isActive: true,
      venueId: null,
      clubId: null,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  factory NightlifeEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return NightlifeEvent(
      id: doc.id,
      title: data['title'] as String? ?? '',
      city: data['city'] as String? ?? '',
      venueName: data['venueName'] as String? ?? '',
      address: data['address'] as String? ?? '',
      dateTime: _readDate(data['dateTime']),
      musicType: data['musicType'] as String? ?? '',
      crowdType: data['crowdType'] as String? ?? '',
      entryRules: data['entryRules'] as String? ?? '',
      description: data['description'] as String? ?? '',
      posterUrl: data['posterUrl'] as String? ?? '',
      priceText: data['priceText'] as String? ?? '',
      artistText: _readArtistText(data),
      latitude: _readDouble(data['latitude']),
      longitude: _readDouble(data['longitude']),
      googleMapsLink: data['googleMapsLink'] as String? ?? '',
      fullAddress: data['fullAddress'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? false,
      venueId: _readOptionalString(data['venueId']),
      clubId: data['clubId'] as String?,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'title': title,
      'city': city,
      'venueName': venueName,
      'address': address,
      'dateTime': Timestamp.fromDate(dateTime),
      'musicType': musicType,
      'crowdType': crowdType,
      'entryRules': entryRules,
      'description': description,
      'posterUrl': posterUrl,
      'priceText': priceText,
      'latitude': latitude,
      'longitude': longitude,
      'googleMapsLink': googleMapsLink,
      'fullAddress': fullAddress,
      'isActive': isActive,
      'venueId': venueId,
      'clubId': clubId,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'title': title,
      'city': city,
      'venueName': venueName,
      'address': address,
      'dateTime': Timestamp.fromDate(dateTime),
      'musicType': musicType,
      'crowdType': crowdType,
      'entryRules': entryRules,
      'description': description,
      'posterUrl': posterUrl,
      'priceText': priceText,
      'latitude': latitude,
      'longitude': longitude,
      'googleMapsLink': googleMapsLink,
      'fullAddress': fullAddress,
      'isActive': isActive,
      'venueId': venueId,
      'clubId': clubId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  NightlifeEvent copyWith({
    String? id,
    String? title,
    String? city,
    String? venueName,
    String? address,
    DateTime? dateTime,
    String? musicType,
    String? crowdType,
    String? entryRules,
    String? description,
    String? posterUrl,
    String? priceText,
    String? artistText,
    double? latitude,
    double? longitude,
    String? googleMapsLink,
    String? fullAddress,
    bool? isActive,
    String? venueId,
    String? clubId,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NightlifeEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      city: city ?? this.city,
      venueName: venueName ?? this.venueName,
      address: address ?? this.address,
      dateTime: dateTime ?? this.dateTime,
      musicType: musicType ?? this.musicType,
      crowdType: crowdType ?? this.crowdType,
      entryRules: entryRules ?? this.entryRules,
      description: description ?? this.description,
      posterUrl: posterUrl ?? this.posterUrl,
      priceText: priceText ?? this.priceText,
      artistText: artistText ?? this.artistText,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      googleMapsLink: googleMapsLink ?? this.googleMapsLink,
      fullAddress: fullAddress ?? this.fullAddress,
      isActive: isActive ?? this.isActive,
      venueId: venueId ?? this.venueId,
      clubId: clubId ?? this.clubId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  static double? _readDouble(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static String? _readOptionalString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _readArtistText(Map<String, dynamic> data) {
    final values = [
      data['artistName'],
      data['artist'],
      data['artists'],
      data['lineup'],
      data['djName'],
    ];

    return values
        .expand((value) {
          if (value is Iterable) return value.map((item) => item.toString());
          if (value is String && value.trim().isNotEmpty) return [value];
          return const <String>[];
        })
        .join(' ')
        .trim();
  }
}
