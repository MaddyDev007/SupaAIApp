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

  @HiveField(3)
  final String? role;

  @HiveField(4)
  final String? reg_no;

  LoginModel({
    required this.name,
    required this.email,
    this.avatarUrl,
    this.role,
    this.reg_no,
  });
}
