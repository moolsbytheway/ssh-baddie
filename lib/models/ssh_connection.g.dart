// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ssh_connection.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SSHConnectionAdapter extends TypeAdapter<SSHConnection> {
  @override
  final int typeId = 0;

  @override
  SSHConnection read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SSHConnection(
      id: fields[0] as String,
      name: fields[1] as String,
      host: fields[2] as String,
      port: fields[3] as int,
      username: fields[4] as String,
      password: fields[5] as String?,
      privateKey: fields[6] as String?,
      passphrase: fields[7] as String?,
      createdAt: fields[8] as DateTime,
      lastUsed: fields[9] as DateTime,
      group: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SSHConnection obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.host)
      ..writeByte(3)
      ..write(obj.port)
      ..writeByte(4)
      ..write(obj.username)
      ..writeByte(5)
      ..write(obj.password)
      ..writeByte(6)
      ..write(obj.privateKey)
      ..writeByte(7)
      ..write(obj.passphrase)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.lastUsed)
      ..writeByte(10)
      ..write(obj.group);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SSHConnectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
