// lib/providers/connection_provider.dart - Add active connection tracking
import 'package:flutter/foundation.dart';
import '../models/ssh_connection.dart';
import '../services/storage_service.dart';

class ConnectionProvider with ChangeNotifier {
  final StorageService _storageService;
  List<SSHConnection> _connections = [];

  // Track active connections
  final Map<String, String> _activeConnections =
      {}; // connectionId -> sessionId

  ConnectionProvider(this._storageService) {
    _loadConnections();
  }

  List<SSHConnection> get connections => _connections;

  bool isConnectionActive(String connectionId) {
    return _activeConnections.containsKey(connectionId);
  }

  String? getSessionId(String connectionId) {
    return _activeConnections[connectionId];
  }

  void setActiveConnection(SSHConnection connection, String sessionId) {
    _activeConnections[connection.id] = sessionId;
    notifyListeners();
  }

  void clearActiveConnection() {
    // Clear the most recent one or provide connectionId param
    if (_activeConnections.isNotEmpty) {
      _activeConnections.clear();
      notifyListeners();
    }
  }

  void clearConnectionById(String connectionId) {
    if (_activeConnections.containsKey(connectionId)) {
      _activeConnections.remove(connectionId);
      notifyListeners();
    }
  }

  Future<void> _loadConnections() async {
    _connections = await _storageService.loadConnections();
    notifyListeners();
  }

  Future<void> addConnection(SSHConnection connection) async {
    final index = _connections.indexWhere((c) => c.id == connection.id);
    if (index != -1) {
      _connections[index] = connection;
    } else {
      _connections.add(connection);
    }
    await _storageService.saveConnections(_connections);
    notifyListeners();
  }

  Future<void> deleteConnection(String id) async {
    _connections.removeWhere((c) => c.id == id);
    _activeConnections.remove(id);
    await _storageService.saveConnections(_connections);
    notifyListeners();
  }

  Future<void> updateLastUsed(String id) async {
    final index = _connections.indexWhere((c) => c.id == id);
    if (index != -1) {
      _connections[index] = SSHConnection(
        id: _connections[index].id,
        name: _connections[index].name,
        host: _connections[index].host,
        port: _connections[index].port,
        username: _connections[index].username,
        password: _connections[index].password,
        privateKey: _connections[index].privateKey,
        passphrase: _connections[index].passphrase,
        createdAt: _connections[index].createdAt,
        lastUsed: DateTime.now(),
      );
      await _storageService.saveConnections(_connections);
      notifyListeners();
    }
  }
}
