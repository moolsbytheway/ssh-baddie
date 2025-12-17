// lib/screens/file_preview_screen.dart
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter_highlight/themes/github.dart';
import '../services/sftp_api_client.dart';
import '../providers/theme_provider.dart';

class FilePreviewScreen extends StatefulWidget {
  final SFTPApiClient sftpClient;
  final String sessionId;
  final SFTPItem item;
  final bool isImage;

  const FilePreviewScreen({
    super.key,
    required this.sftpClient,
    required this.sessionId,
    required this.item,
    required this.isImage,
  });

  @override
  State<FilePreviewScreen> createState() => _FilePreviewScreenState();
}

class _FilePreviewScreenState extends State<FilePreviewScreen> {
  bool _isLoading = true;
  double _progress = 0.0;
  String? _error;
  String? _tempPath;
  String? _content;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  final _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _downloadFile();
  }

  Future<void> _downloadFile() async {
    try {
      final tempPath =
          '${DateTime.now().millisecondsSinceEpoch}_${widget.item.name}';

      await widget.sftpClient.downloadFile(
        widget.sessionId,
        widget.item.path,
        tempPath,
        onProgress: (received, total) {
          if (mounted) {
            setState(() {
              _progress = received / total;
            });
          }
        },
      );

      if (widget.isImage) {
        setState(() {
          _tempPath = tempPath;
          _isLoading = false;
        });
      } else {
        // Read text content
        final file = File(tempPath);
        final content = await file.readAsString();
        await file.delete(); // Clean up immediately for text files

        setState(() {
          _content = content;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Clean up image file if it exists
    if (_tempPath != null) {
      try {
        File(_tempPath!).delete();
      } catch (_) {}
    }
    _editController.dispose();
    super.dispose();
  }

  void _toggleEditMode() {
    setState(() {
      if (_isEditing) {
        // Exiting edit mode - check for changes
        if (_editController.text != _content) {
          _showUnsavedChangesDialog();
        } else {
          _isEditing = false;
        }
      } else {
        // Entering edit mode
        _editController.text = _content ?? '';
        _isEditing = true;
        _hasUnsavedChanges = false;
      }
    });
  }

  void _showUnsavedChangesDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes. Do you want to save them?',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Discard'),
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _isEditing = false;
                _hasUnsavedChanges = false;
              });
            },
          ),
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              _saveFile();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveFile() async {
    if (_isSaving || !_isEditing) return;

    setState(() => _isSaving = true);

    try {
      // Create a temporary file with the new content
      final tempPath =
          '${DateTime.now().millisecondsSinceEpoch}_${widget.item.name}';
      final file = File(tempPath);
      await file.writeAsString(_editController.text);

      // Upload the file
      await widget.sftpClient.uploadFile(
        widget.sessionId,
        tempPath,
        widget.item.path,
        onProgress: (sent, total) {
          // Could show upload progress here if needed
        },
      );

      // Clean up temp file
      await file.delete();

      // Update the content
      setState(() {
        _content = _editController.text;
        _isEditing = false;
        _hasUnsavedChanges = false;
      });

      if (mounted) {
        _showSuccessDialog('File saved successfully');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to save: $e');
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSuccessDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;

    if (_error != null) {
      return Scaffold(
        backgroundColor: theme.colors.background,
        body: Column(
          children: [
            _buildHeader(theme),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.exclamationmark_triangle,
                      size: 48,
                      color: theme.colors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Preview failed',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.colors.background,
        body: Column(
          children: [
            _buildHeader(theme),
            Expanded(
              child: Center(
                child: Container(
                  width: 300,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colors.border, width: 1),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.arrow_down_circle,
                        size: 48,
                        color: theme.colors.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Downloading ${widget.item.name}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: theme.colors.inputBackground,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colors.primary,
                          ),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(_progress * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colors.textSecondary,
                          fontFamily: 'Menlo',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Show content based on type
    if (widget.isImage) {
      return _ImagePreviewContent(
        imagePath: _tempPath!,
        filename: widget.item.name,
      );
    } else {
      return _TextPreviewContent(
        content: _content!,
        filename: widget.item.name,
        isEditing: _isEditing,
        isSaving: _isSaving,
        editController: _editController,
        onToggleEdit: _toggleEditMode,
        onSave: _saveFile,
        onTextChanged: () {
          if (!_hasUnsavedChanges) {
            setState(() => _hasUnsavedChanges = true);
          }
        },
      );
    }
  }

  Widget _buildHeader(theme) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border(
          bottom: BorderSide(color: theme.colors.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: () => Navigator.of(context).pop(),
            child: Icon(
              CupertinoIcons.back,
              size: 20,
              color: theme.colors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            widget.isImage ? CupertinoIcons.photo : CupertinoIcons.doc_text,
            size: 16,
            color: theme.colors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.item.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// Text Preview Content
class _TextPreviewContent extends StatelessWidget {
  final String content;
  final String filename;
  final bool isEditing;
  final bool isSaving;
  final TextEditingController editController;
  final VoidCallback onToggleEdit;
  final VoidCallback onSave;
  final VoidCallback onTextChanged;

  const _TextPreviewContent({
    required this.content,
    required this.filename,
    required this.isEditing,
    required this.isSaving,
    required this.editController,
    required this.onToggleEdit,
    required this.onSave,
    required this.onTextChanged,
  });

  String _getLanguage(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    const languageMap = {
      'dart': 'dart',
      'js': 'javascript',
      'jsx': 'javascript',
      'ts': 'typescript',
      'tsx': 'typescript',
      'py': 'python',
      'java': 'java',
      'kt': 'kotlin',
      'swift': 'swift',
      'go': 'go',
      'rs': 'rust',
      'c': 'c',
      'cpp': 'cpp',
      'cc': 'cpp',
      'h': 'cpp',
      'hpp': 'cpp',
      'cs': 'csharp',
      'php': 'php',
      'rb': 'ruby',
      'sh': 'bash',
      'bash': 'bash',
      'zsh': 'bash',
      'fish': 'bash',
      'json': 'json',
      'xml': 'xml',
      'html': 'xml',
      'yaml': 'yaml',
      'yml': 'yaml',
      'sql': 'sql',
      'css': 'css',
      'scss': 'scss',
      'less': 'less',
      'md': 'markdown',
      'gradle': 'gradle',
      'dockerfile': 'dockerfile',
    };
    return languageMap[ext] ?? '';
  }

  bool _isCodeFile(String filename) {
    return _getLanguage(filename).isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;
    final isCode = _isCodeFile(filename);
    final language = _getLanguage(filename);

    return Scaffold(
      backgroundColor: theme.colors.background,
      body: Column(
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: theme.colors.surface,
              border: Border(
                bottom: BorderSide(color: theme.colors.border, width: 1),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: () => Navigator.of(context).pop(),
                  child: Icon(
                    CupertinoIcons.back,
                    size: 20,
                    color: theme.colors.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  isCode
                      ? CupertinoIcons.chevron_left_slash_chevron_right
                      : CupertinoIcons.doc_text,
                  size: 16,
                  color: theme.colors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    filename,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCode && !isEditing)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      language.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: theme.colors.primary,
                        fontFamily: 'Menlo',
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                if (isEditing) ...[
                  if (isSaving)
                    CupertinoActivityIndicator(color: theme.colors.primary)
                  else
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 0,
                      onPressed: onSave,
                      child: Icon(
                        CupertinoIcons.floppy_disk,
                        size: 20,
                        color: theme.colors.primary,
                      ),
                    ),
                  const SizedBox(width: 8),
                ],
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: isSaving ? null : onToggleEdit,
                  child: Icon(
                    isEditing ? CupertinoIcons.xmark : CupertinoIcons.pencil,
                    size: 20,
                    color: isEditing
                        ? theme.colors.error
                        : theme.colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isEditing
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: CupertinoTextField(
                      controller: editController,
                      maxLines: null,
                      expands: true,
                      style: TextStyle(
                        fontFamily: 'Menlo',
                        fontSize: 12,
                        color: theme.colors.textPrimary,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colors.inputBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colors.border,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      onChanged: (_) => onTextChanged(),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: isCode
                        ? HighlightView(
                            content,
                            language: language,
                            theme: theme.isDark
                                ? monokaiSublimeTheme
                                : githubTheme,
                            padding: const EdgeInsets.all(12),
                            textStyle: const TextStyle(
                              fontFamily: 'Menlo',
                              fontSize: 12,
                            ),
                          )
                        : SelectableText(
                            content,
                            style: TextStyle(
                              fontFamily: 'Menlo',
                              fontSize: 12,
                              color: theme.colors.textPrimary,
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

// Image Preview Content
class _ImagePreviewContent extends StatelessWidget {
  final String imagePath;
  final String filename;

  const _ImagePreviewContent({required this.imagePath, required this.filename});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;

    return Scaffold(
      backgroundColor: theme.colors.background,
      body: Column(
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: theme.colors.surface,
              border: Border(
                bottom: BorderSide(color: theme.colors.border, width: 1),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: () => Navigator.of(context).pop(),
                  child: Icon(
                    CupertinoIcons.back,
                    size: 20,
                    color: theme.colors.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  CupertinoIcons.photo,
                  size: 16,
                  color: theme.colors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    filename,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(File(imagePath)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
