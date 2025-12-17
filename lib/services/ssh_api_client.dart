// lib/services/ssh_api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ssh_connection.dart';

class SSHApiClient {
  final String baseUrl;

  SSHApiClient(this.baseUrl);

  Future<String> createSession(SSHConnection connection) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/ssh/connect'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'host': connection.host,
        'port': connection.port,
        'username': connection.username,
        'password': connection.password,
        'private_key': connection.privateKey,
        'passphrase': connection.passphrase,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['session_id'];
    } else {
      throw Exception('Failed to connect: ${response.body}');
    }
  }

  Future<void> closeSession(String sessionId) async {
    await http.delete(Uri.parse('$baseUrl/api/ssh/session/$sessionId'));
  }

  Future<String> executeCommand(String sessionId, String command) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/ssh/exec'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'session_id': sessionId, 'command': command}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['output'];
    } else {
      throw Exception('Command failed: ${response.body}');
    }
  }

  Stream<String> terminalStream(String sessionId) async* {
    // WebSocket or SSE implementation
    // For now, placeholder
    yield 'Terminal output...';
  }
}
