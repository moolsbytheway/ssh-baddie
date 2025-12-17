// lib/services/file_picker_service.dart
import 'dart:io';
import 'package:file_selector/file_selector.dart';

class FilePickerService {
  Future<String?> pickFile() async {
    final XFile? file = await openFile(
      acceptedTypeGroups: [const XTypeGroup(label: 'All Files')],
    );

    return file?.path;
  }

  Future<String?> pickDirectory() async {
    final String? path = await getDirectoryPath();
    return path;
  }

  Future<String?> pickSaveLocation(String suggestedName) async {
    final FileSaveLocation? result = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: [const XTypeGroup(label: 'All Files')],
    );

    return result?.path;
  }

  Future<String?> readFileAsString(String path) async {
    try {
      return await File(path).readAsString();
    } catch (e) {
      print("Failed to read file: $e");
      return null;
    }
  }
}
