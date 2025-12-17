// lib/models/ssh_connection.dart - Optional: Add group field
import 'package:hive/hive.dart';

part 'ssh_connection.g.dart';

@HiveType(typeId: 0)
class SSHConnection extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String host;

  @HiveField(3)
  final int port;

  @HiveField(4)
  final String username;

  @HiveField(5)
  final String? password;

  @HiveField(6)
  final String? privateKey;

  @HiveField(7)
  final String? passphrase;

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  DateTime lastUsed;

  @HiveField(10) // Add new field with next available index
  final String? group;

  SSHConnection({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    this.password,
    this.privateKey,
    this.passphrase,
    required this.createdAt,
    required this.lastUsed,
    this.group, // Add to constructor
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'host': host,
    'port': port,
    'username': username,
    'password': password,
    'privateKey': privateKey,
    'passphrase': passphrase,
    'createdAt': createdAt.toIso8601String(),
    'lastUsed': lastUsed.toIso8601String(),
    'group': group, // Add to JSON
  };

  factory SSHConnection.fromJson(Map<String, dynamic> json) => SSHConnection(
    id: json['id'] as String,
    name: json['name'] as String,
    host: json['host'] as String,
    port: json['port'] as int,
    username: json['username'] as String,
    password: json['password'] as String?,
    privateKey: json['privateKey'] as String?,
    passphrase: json['passphrase'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    lastUsed: DateTime.parse(json['lastUsed'] as String),
    group: json['group'] as String?, // Add from JSON
  );

  SSHConnection copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    String? password,
    String? privateKey,
    String? passphrase,
    DateTime? createdAt,
    DateTime? lastUsed,
    String? group, // Add to copyWith
  }) {
    return SSHConnection(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      privateKey: privateKey ?? this.privateKey,
      passphrase: passphrase ?? this.passphrase,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
      group: group ?? this.group, // Add to copyWith
    );
  }
}

// IMPORTANT: After adding the group field, you need to regenerate the Hive adapter
// Run: flutter packages pub run build_runner build --delete-conflicting-outputs
