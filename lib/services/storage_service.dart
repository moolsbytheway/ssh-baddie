// lib/services/storage_service.dart
import 'package:hive_flutter/hive_flutter.dart';
import '../models/ssh_connection.dart';

class StorageService {
  static const String connectionsBox = 'connections';
  static const String settingsBox = 'settings';

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(SSHConnectionAdapter());
    await Hive.openBox<SSHConnection>(connectionsBox);
    await Hive.openBox(settingsBox);
  }

  Box<SSHConnection> get connections => Hive.box<SSHConnection>(connectionsBox);
  Box get settings => Hive.box(settingsBox);

  // Load all connections (used by ConnectionProvider)
  Future<List<SSHConnection>> loadConnections() async {
    return connections.values.toList()
      ..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
  }

  // Save all connections (used by ConnectionProvider)
  Future<void> saveConnections(List<SSHConnection> connectionsList) async {
    await connections.clear();
    for (final connection in connectionsList) {
      await connections.put(connection.id, connection);
    }
  }

  // Legacy methods (kept for backward compatibility)
  Future<void> saveConnection(SSHConnection connection) async {
    await connections.put(connection.id, connection);
  }

  Future<void> deleteConnection(String id) async {
    await connections.delete(id);
  }

  List<SSHConnection> getAllConnections() {
    return connections.values.toList()
      ..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
  }

  Future<void> updateLastUsed(String id) async {
    final connection = connections.get(id);
    if (connection != null) {
      final updated = SSHConnection(
        id: connection.id,
        name: connection.name,
        host: connection.host,
        port: connection.port,
        username: connection.username,
        password: connection.password,
        privateKey: connection.privateKey,
        passphrase: connection.passphrase,
        createdAt: connection.createdAt,
        lastUsed: DateTime.now(),
      );
      await connections.put(id, updated);
    }
  }

  // Theme methods
  Future<void> saveTheme(String themeName) async {
    await settings.put('theme', themeName);
  }

  String? getSavedTheme() {
    return settings.get('theme') as String?;
  }
}
