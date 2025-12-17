// lib/services/sftp_api_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;

class SFTPApiClient {
  final String baseUrl;

  SFTPApiClient(this.baseUrl);

  void _log(String message) {
    developer.log(message, name: 'SFTPApiClient');
  }

  Future<List<SFTPItem>> listFiles(String sessionId, String path) async {
    _log('Listing files: session=$sessionId, path=$path');

    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/sftp/list',
      ).replace(queryParameters: {'session_id': sessionId, 'path': path}),
    );

    _log('List files response: status=${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final files = (data['files'] as List)
          .map((item) => SFTPItem.fromJson(item))
          .toList();
      _log('Listed ${files.length} files');
      return files;
    } else {
      _log('List files failed: ${response.body}');
      throw Exception('Failed to list files: ${response.body}');
    }
  }

  Future<void> uploadFile(
    String sessionId,
    String localPath,
    String remotePath, {
    void Function(int sent, int total)? onProgress,
  }) async {
    _log('Uploading file: local=$localPath, remote=$remotePath');

    final file = File(localPath);
    final fileLength = await file.length();
    _log('File size: $fileLength bytes');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/sftp/upload'),
    );

    request.fields['session_id'] = sessionId;
    request.fields['remote_path'] = remotePath;

    // Create a stream that reports progress
    final stream = http.ByteStream(file.openRead());

    if (onProgress != null) {
      int bytesSent = 0;
      final progressStream = stream.transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (data, sink) {
            bytesSent += data.length;
            onProgress(bytesSent, fileLength);
            sink.add(data);
          },
        ),
      );

      request.files.add(
        http.MultipartFile(
          'file',
          progressStream,
          fileLength,
          filename: localPath.split('/').last,
        ),
      );
    } else {
      request.files.add(
        http.MultipartFile(
          'file',
          stream,
          fileLength,
          filename: localPath.split('/').last,
        ),
      );
    }

    final response = await request.send();
    _log('Upload response: status=${response.statusCode}');

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      _log('Upload failed: $body');
      throw Exception('Upload failed: $body');
    }

    _log('Upload successful');
  }

  Future<void> downloadFile(
    String sessionId,
    String remotePath,
    String localPath, {
    void Function(int received, int total)? onProgress,
  }) async {
    _log('Downloading file: remote=$remotePath, local=$localPath');

    final request = http.Request(
      'GET',
      Uri.parse('$baseUrl/api/sftp/download').replace(
        queryParameters: {'session_id': sessionId, 'remote_path': remotePath},
      ),
    );

    final response = await request.send();
    _log('Download response: status=${response.statusCode}');

    if (response.statusCode == 200) {
      final file = File(localPath);
      final sink = file.openWrite();
      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      try {
        await for (var chunk in response.stream) {
          receivedBytes += chunk.length;
          if (onProgress != null && totalBytes > 0) {
            onProgress(receivedBytes, totalBytes);
          }
          sink.add(chunk);
        }

        await sink.close();
        _log('Downloaded $receivedBytes bytes');
      } catch (e) {
        await sink.close();
        _log('Download failed: $e');
        rethrow;
      }
    } else {
      final body = await response.stream.bytesToString();
      _log('Download failed: $body');
      throw Exception('Download failed: $body');
    }
  }

  Future<void> removeFile(String sessionId, String path) async {
    _log('Removing file: path=$path');

    final response = await http.delete(
      Uri.parse('$baseUrl/api/sftp/delete'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'session_id': sessionId,
        'path': path,
        'is_directory': false,
      }),
    );

    _log('Remove file response: status=${response.statusCode}');

    if (response.statusCode != 200) {
      _log('Remove file failed: ${response.body}');
      throw Exception('Delete file failed: ${response.body}');
    }

    _log('File removed successfully');
  }

  Future<void> removeDirectory(String sessionId, String path) async {
    _log('Removing directory: path=$path');

    final response = await http.delete(
      Uri.parse('$baseUrl/api/sftp/delete'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'session_id': sessionId,
        'path': path,
        'is_directory': true,
      }),
    );

    _log('Remove directory response: status=${response.statusCode}');

    if (response.statusCode != 200) {
      _log('Remove directory failed: ${response.body}');
      throw Exception('Delete directory failed: ${response.body}');
    }

    _log('Directory removed successfully');
  }

  Future<void> createDirectory(String sessionId, String path) async {
    _log('Creating directory: path=$path');

    final response = await http.post(
      Uri.parse('$baseUrl/api/sftp/mkdir'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'session_id': sessionId, 'path': path}),
    );

    _log('Create directory response: status=${response.statusCode}');

    if (response.statusCode != 200) {
      _log('Create directory failed: ${response.body}');
      throw Exception('Create directory failed: ${response.body}');
    }

    _log('Directory created successfully');
  }

  Future<void> renameFile(
    String sessionId,
    String oldPath,
    String newPath,
  ) async {
    _log('Renaming file: old=$oldPath, new=$newPath');

    final response = await http.post(
      Uri.parse('$baseUrl/api/sftp/rename'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'session_id': sessionId,
        'old_path': oldPath,
        'new_path': newPath,
      }),
    );

    _log('Rename file response: status=${response.statusCode}');

    if (response.statusCode != 200) {
      _log('Rename file failed: ${response.body}');
      throw Exception('Rename failed: ${response.body}');
    }

    _log('File renamed successfully');
  }
}

// Model class for SFTP items
class SFTPItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime modifiedTime;
  final String permissions;

  SFTPItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.modifiedTime,
    required this.permissions,
  });

  factory SFTPItem.fromJson(Map<String, dynamic> json) {
    return SFTPItem(
      name: json['name'],
      path: json['path'],
      isDirectory: json['is_directory'],
      size: json['size'],
      modifiedTime: DateTime.parse(json['modified_time']),
      permissions: json['permissions'],
    );
  }
}
