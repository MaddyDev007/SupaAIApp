import 'package:hive/hive.dart';

part 'login_model.g.dart';

@HiveType(typeId: 1) // ⚠️ ensure unique typeId
class LoginModel extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final String email;

  @HiveField(2)
  final String? avatarUrl;

  LoginModel({
    required this.name,
    required this.email,
    this.avatarUrl,
  });
}
