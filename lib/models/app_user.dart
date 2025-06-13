// importは省略しています
import 'package:almost_zenly/types/image_type.dart';

class AppUser {
  AppUser({
    this.id,
    this.name = '',
    this.profile = '',
    this.imageType = ImageType.lion,
  });

  final String? id;
  final String name;
  final String profile;
  final ImageType imageType;

  factory AppUser.fromDoc(String id, Map<String, dynamic> doc) => AppUser(
        id: id,
        name: doc['name'],
        profile: doc['profile'],
        imageType: ImageType.fromString(doc['image_type']),
      );
}