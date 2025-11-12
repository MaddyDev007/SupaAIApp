import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: 1)
class UserModel extends HiveObject {

  @HiveField(0)
  String name;

  @HiveField(1)
  String email;

  @HiveField(2)
  String department;

  @HiveField(3)
  String year;

  @HiveField(4)
  String role;

  @HiveField(5)
  String regNo;

  UserModel({
    required this.name,
    required this.email,
    required this.department,
    required this.year,
    required this.role,
    required this.regNo,
  });
}
