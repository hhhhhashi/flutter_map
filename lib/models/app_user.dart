// importは省略しています
import 'package:almost_zenly/types/image_type.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  AppUser({
    this.id,
    this.name = '',
    this.profile = '',
    this.imageType = ImageType.lion,
    this.location,
  });

  final String? id;
  final String name;
  final String profile;
  final ImageType imageType;
  final GeoPoint? location;

  factory AppUser.fromDoc(String id, Map<String, dynamic> json) => AppUser(
        id: id,
        imageType: ImageType.fromString(json['image_type']),
        name: json['name'],
        profile: json['profile'],
        location: json['location'],
      );
}