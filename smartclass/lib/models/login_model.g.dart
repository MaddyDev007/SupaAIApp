// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LoginModelAdapter extends TypeAdapter<LoginModel> {
  @override
  final int typeId = 1;

  @override
  LoginModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LoginModel(
      name: fields[0] as String,
      email: fields[1] as String,
      avatarUrl: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LoginModel obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.email)
      ..writeByte(2)
      ..write(obj.avatarUrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoginModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
