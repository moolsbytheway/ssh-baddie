// lib/screens/workspace_screen.dart - Unified Terminal & File Manager
import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ssh_baddie/theme/app_theme.dart';
import 'package:xterm/xterm.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/ssh_connection.dart';
import '../services/backend_service.dart';
import '../providers/connection_provider.dart';
import '../providers/theme_provider.dart';
import '../services/sftp_api_client.dart';
import '../services/file_picker_service.dart';
import 'file_preview_screen.dart';

class WorkspaceScreen extends StatefulWidget {
  final SSHConnection connection;

  const WorkspaceScreen({super.key, required this.connection});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  // Terminal state
  late Terminal _terminal;
  late TerminalController _terminalController;
  WebSocketChannel? _channel;
  late String _sessionId;
  bool _isConnecting = true;
  bool _isConnected = false;
  ConnectionProvider? _connectionProvider;
  DateTime? _connectedAt;
  Timer? _uptimeTimer;

  // SFTP state
  SFTPApiClient? _sftpClient;
  List<SFTPItem> _remoteFiles = [];
  List<SFTPItem> _filteredFiles = [];
  String _remotePath = '/';
  bool _isLoadingFiles = false;
  final _filePickerService = FilePickerService();
  final _pathController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  double _uploadProgress = 0.0;
  double _downloadProgress = 0.0;
  bool _isUploading = false;
  bool _isDownloading = false;
  String _currentOperation = '';

  // UI state
  int _selectedTab = 0; // 0: Terminal, 1: File Manager

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);
    _terminalController = TerminalController();
    _pathController.text = _remotePath;
    _searchController.addListener(_onSearchChanged);
    _connect();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _connectionProvider = context.read<ConnectionProvider>();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterFiles();
    });
  }

  void _filterFiles() {
    if (_searchQuery.isEmpty) {
      _filteredFiles = _remoteFiles;
    } else {
      _filteredFiles = _remoteFiles
          .where((file) => file.name.toLowerCase().contains(_searchQuery))
          .toList();
    }
  }

  Future<void> _connect() async {
    try {
      final backendService = context.read<BackendService>();

      final response = await http.post(
        Uri.parse('${backendService.baseUrl}/api/ssh/connect'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'host': widget.connection.host,
          'port': widget.connection.port,
          'username': widget.connection.username,
          'password': widget.connection.password,
          'private_key': widget.connection.privateKey,
          'passphrase': widget.connection.passphrase,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to connect: ${response.body}');
      }

      final data = jsonDecode(response.body);
      _sessionId = data['session_id'];

      final wsUrl = backendService.baseUrl
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');

      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/api/terminal/$_sessionId'),
      );

      _channel!.stream.listen(
        (data) {
          if (data is String) {
            _terminal.write(data);
          } else if (data is List<int>) {
            _terminal.write(String.fromCharCodes(data));
          }
        },
        onError: (error) {
          if (mounted) {
            _showErrorDialog('$error');
            setState(() {
              _isConnected = false;
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _isConnected = false;
            });
          }
        },
      );

      _terminal.onOutput = (data) {
        _channel?.sink.add(data);
      };

      _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        _channel?.sink.add(
          jsonEncode({'type': 'resize', 'cols': width, 'rows': height}),
        );
      };

      setState(() {
        _isConnecting = false;
        _isConnected = true;
        _connectedAt = DateTime.now();
      });

      _uptimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _isConnected) {
          setState(() {}); // Trigger rebuild to update uptime display
        }
      });

      _connectionProvider?.setActiveConnection(widget.connection, _sessionId!);

      // Initialize SFTP
      _sftpClient = SFTPApiClient(backendService.baseUrl);
      await _loadRemoteFiles();
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _isConnected = false;
      });
      if (mounted) {
        _showErrorDialog('$e');
      }
    }
  }

  Future<void> _loadRemoteFiles() async {
    setState(() => _isLoadingFiles = true);

    try {
      final files = await _sftpClient!.listFiles(_sessionId, _remotePath);
      setState(() {
        _remoteFiles = files;
        _filterFiles();
        _pathController.text = _remotePath;
      });
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error loading files: $e');
      }
    } finally {
      setState(() => _isLoadingFiles = false);
    }
  }

  String _getUptime() {
    if (_connectedAt == null) return '0s';
    final duration = DateTime.now().difference(_connectedAt!);

    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;

    return Row(
      children: [
        // Sidebar
        Container(
          width: 240,
          decoration: BoxDecoration(
            color: theme.colors.surface,
            border: Border(
              right: BorderSide(color: theme.colors.border, width: 1),
            ),
          ),
          child: Column(
            children: [
              // Back button and connection info
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: theme.colors.border, width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.chevron_left,
                            size: 16,
                            color: theme.colors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Back to Connections',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colors.primary,
                                theme.colors.primary.withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            CupertinoIcons.device_desktop,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.connection.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _isConnected
                                          ? theme.colors.success
                                          : theme.colors.error,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isConnected ? 'Connected' : 'Disconnected',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Navigation tabs
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSidebarButton(
                      icon: CupertinoIcons.device_laptop,
                      label: 'Terminal',
                      isSelected: _selectedTab == 0,
                      onTap: () => setState(() => _selectedTab = 0),
                      theme: theme,
                    ),
                    const SizedBox(height: 8),
                    _buildSidebarButton(
                      icon: CupertinoIcons.folder,
                      label: 'File Manager',
                      isSelected: _selectedTab == 1,
                      onTap: _isConnected
                          ? () => setState(() => _selectedTab = 1)
                          : null,
                      theme: theme,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Connection Info
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: theme.colors.border, width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection Info',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Host', widget.connection.host, theme),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Port',
                      widget.connection.port.toString(),
                      theme,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow('User', widget.connection.username, theme),
                    if (_isConnected) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow('Uptime', _getUptime(), theme),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        // Main Content
        Expanded(
          child: _selectedTab == 0
              ? _buildTerminalView(theme)
              : _buildFileManagerView(theme),
        ),
      ],
    );
  }

  Widget _buildSidebarButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback? onTap,
    required AppTheme theme,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colors.primary.withOpacity(0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onPressed: onTap,
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? theme.colors.primary
                  : onTap == null
                  ? theme.colors.textTertiary
                  : theme.colors.textSecondary,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? theme.colors.primary
                    : onTap == null
                    ? theme.colors.textTertiary
                    : theme.colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, AppTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: theme.colors.textTertiary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: theme.colors.textPrimary,
            fontFamily: 'Menlo',
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildTerminalView(AppTheme theme) {
    final hasSelection = _terminalController.selection != null;

    return Column(
      children: [
        // Header
        Container(
          decoration: BoxDecoration(
            color: theme.colors.surface,
            border: Border(
              bottom: BorderSide(color: theme.colors.border, width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.terminal, size: 18, color: theme.colors.textSecondary),
              const SizedBox(width: 8),
              Text(
                '${widget.connection.username}@${widget.connection.host}:~',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colors.textSecondary,
                  fontFamily: 'Menlo',
                ),
              ),
              if (_isConnected) ...[
                const SizedBox(width: 12),
                Container(width: 1, height: 16, color: theme.colors.border),
                const SizedBox(width: 12),
                Icon(
                  CupertinoIcons.time,
                  size: 14,
                  color: theme.colors.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Session: ${_getUptime()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colors.textTertiary,
                  ),
                ),
              ],
              const Spacer(),
              if (_isConnected && hasSelection)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  color: theme.colors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  onPressed: _copySelection,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.doc_on_clipboard,
                        size: 14,
                        color: theme.colors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Copy',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_isConnected && hasSelection) const SizedBox(width: 8),
              CupertinoButton(
                padding: const EdgeInsets.all(6),
                onPressed: _isConnected
                    ? () => _showTerminalContextMenu()
                    : null,
                child: Icon(
                  CupertinoIcons.ellipsis,
                  size: 18,
                  color: _isConnected
                      ? theme.colors.textSecondary
                      : theme.colors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        // Terminal Content
        Expanded(
          child: _isConnecting
              ? _buildLoadingState(theme)
              : !_isConnected
              ? _buildErrorState(theme)
              : Container(
                  color: theme.colors.terminalBackground,
                  child: TerminalView(
                    _terminal,
                    controller: _terminalController,
                    theme: theme.terminalTheme,
                    textStyle: theme.terminalStyle,
                    autofocus: true,
                    backgroundOpacity: 1.0,
                    padding: const EdgeInsets.all(16),
                    hardwareKeyboardOnly: false,
                    onSecondaryTapDown: (details, offset) =>
                        _showTerminalRightClickMenu(details, theme),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFileManagerView(AppTheme theme) {
    return Container(
      color: theme.colors.background,
      child: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              color: theme.colors.surface,
              border: Border(
                bottom: BorderSide(color: theme.colors.border, width: 1),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.folder,
                  size: 18,
                  color: theme.colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'SFTP File Manager',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colors.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Container(width: 1, height: 16, color: theme.colors.border),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${widget.connection.username}@${widget.connection.host}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colors.textSecondary,
                      fontFamily: 'Menlo',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  color: theme.colors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  onPressed: _isLoadingFiles ? null : _createFolder,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.folder_badge_plus,
                        size: 14,
                        color: theme.colors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'New Folder',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  color: theme.colors.primary,
                  borderRadius: BorderRadius.circular(6),
                  onPressed: _isLoadingFiles ? null : _uploadFile,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.arrow_up_circle,
                        size: 14,
                        color: Colors.white,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Upload',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: const EdgeInsets.all(6),
                  onPressed: _isLoadingFiles ? null : _loadRemoteFiles,
                  child: Icon(
                    CupertinoIcons.refresh,
                    size: 18,
                    color: _isLoadingFiles
                        ? theme.colors.textTertiary
                        : theme.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Path navigation bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colors.surface,
              border: Border(
                bottom: BorderSide(color: theme.colors.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.all(6),
                  minSize: 0,
                  onPressed: _remotePath != '/' ? _navigateUp : null,
                  child: Icon(
                    CupertinoIcons.arrow_up,
                    color: _remotePath != '/'
                        ? theme.colors.textPrimary
                        : theme.colors.textTertiary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colors.inputBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colors.border, width: 1),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Icon(
                            CupertinoIcons.folder,
                            size: 16,
                            color: theme.colors.textSecondary,
                          ),
                        ),
                        Expanded(
                          child: CupertinoTextField(
                            controller: _pathController,
                            placeholder: '/path',
                            style: TextStyle(
                              color: theme.colors.textPrimary,
                              fontSize: 13,
                              fontFamily: 'Menlo',
                            ),
                            placeholderStyle: TextStyle(
                              color: theme.colors.textTertiary,
                              fontSize: 13,
                            ),
                            decoration: const BoxDecoration(
                              color: Colors.transparent,
                              border: Border(),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            onSubmitted: (_) => _navigateToPath(),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minSize: 0,
                          onPressed: _navigateToPath,
                          child: Icon(
                            CupertinoIcons.arrow_right,
                            size: 14,
                            color: theme.colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Search bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colors.surface,
              border: Border(
                bottom: BorderSide(color: theme.colors.border, width: 1),
              ),
            ),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: theme.colors.inputBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colors.border, width: 1),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Icon(
                      CupertinoIcons.search,
                      size: 16,
                      color: theme.colors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: CupertinoTextField(
                      controller: _searchController,
                      placeholder: 'Search files...',
                      style: TextStyle(
                        color: theme.colors.textPrimary,
                        fontSize: 13,
                      ),
                      placeholderStyle: TextStyle(
                        color: theme.colors.textTertiary,
                        fontSize: 13,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        border: Border(),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minSize: 0,
                      onPressed: () => _searchController.clear(),
                      child: Icon(
                        CupertinoIcons.xmark_circle_fill,
                        size: 16,
                        color: theme.colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // File list
          Expanded(
            child: Container(
              color: theme.colors.background,
              child: Stack(
                children: [
                  _isLoadingFiles
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CupertinoActivityIndicator(
                                radius: 16,
                                color: theme.colors.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Loading files...',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _filteredFiles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchQuery.isNotEmpty
                                    ? CupertinoIcons.search
                                    : CupertinoIcons.folder,
                                size: 48,
                                color: theme.colors.textTertiary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No files found'
                                    : 'Empty directory',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredFiles.length,
                          itemBuilder: (context, index) {
                            final item = _filteredFiles[index];
                            return _buildFileItem(item, theme);
                          },
                        ),
                  if (_isUploading || _isDownloading)
                    _buildProgressOverlay(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(SFTPItem item, AppTheme theme) {
    final dateFormat = DateFormat('MMM dd HH:mm');
    final sizeFormat = _formatBytes(item.size);

    return GestureDetector(
      onTap: () => _navigateInto(item),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.colors.border, width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: item.isDirectory
                    ? theme.colors.primary.withOpacity(0.1)
                    : theme.colors.inputBackground,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                item.isDirectory
                    ? CupertinoIcons.folder_fill
                    : CupertinoIcons.doc_fill,
                color: item.isDirectory
                    ? theme.colors.primary
                    : theme.colors.textSecondary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      color: theme.colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.permissions} • $sizeFormat • ${dateFormat.format(item.modifiedTime)}',
                    style: TextStyle(
                      color: theme.colors.textSecondary,
                      fontSize: 11,
                      fontFamily: 'Menlo',
                    ),
                  ),
                ],
              ),
            ),
            _buildFilePopupMenu(item, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(AppTheme theme) {
    return Container(
      color: theme.colors.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: CupertinoActivityIndicator(
                radius: 20,
                color: theme.colors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Connecting to ${widget.connection.name}...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.connection.username}@${widget.connection.host}:${widget.connection.port}',
              style: TextStyle(
                fontSize: 13,
                color: theme.colors.textSecondary,
                fontFamily: 'Menlo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(AppTheme theme) {
    return Container(
      color: theme.colors.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 48,
                color: theme.colors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Connection Failed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to establish SSH connection',
              style: TextStyle(fontSize: 14, color: theme.colors.textSecondary),
            ),
            const SizedBox(height: 32),
            CupertinoButton.filled(
              onPressed: () {
                setState(() {
                  _isConnecting = true;
                });
                _connect();
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.refresh, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Retry Connection',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressOverlay(AppTheme theme) {
    return Container(
      color: theme.colors.background.withOpacity(0.95),
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: theme.colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.colors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isUploading
                      ? CupertinoIcons.arrow_up_circle
                      : CupertinoIcons.arrow_down_circle,
                  size: 32,
                  color: theme.colors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _currentOperation,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.colors.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _isUploading ? _uploadProgress : _downloadProgress,
                  backgroundColor: theme.colors.inputBackground,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colors.primary,
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${((_isUploading ? _uploadProgress : _downloadProgress) * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colors.textSecondary,
                  fontFamily: 'Menlo',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Terminal operations
  void _copySelection() async {
    final selection = _terminalController.selection;
    if (selection != null) {
      final text = _terminal.buffer.getText(selection);
      if (text.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: text));
        _terminalController.clearSelection();
        setState(() {});
      }
    }
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      _terminal.paste(data!.text!);
    }
  }

  void _showTerminalContextMenu() {
    final theme = context.read<ThemeProvider>().currentTheme;
    final hasSelection = _terminalController.selection != null;

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: [
          if (hasSelection)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _copySelection();
              },
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.doc_on_clipboard,
                    size: 20,
                    color: theme.colors.primary,
                  ),
                  const SizedBox(width: 12),
                  const Text('Copy Selection'),
                ],
              ),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pasteFromClipboard();
            },
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.doc_on_clipboard_fill,
                  size: 20,
                  color: theme.colors.textPrimary,
                ),
                const SizedBox(width: 12),
                const Text('Paste'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _terminal.write('\x0C'); // Clear screen
            },
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.clear,
                  size: 20,
                  color: theme.colors.textPrimary,
                ),
                const SizedBox(width: 12),
                const Text('Clear Terminal'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showTerminalRightClickMenu(TapDownDetails details, AppTheme theme) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final hasSelection = _terminalController.selection != null;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        details.globalPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      color: theme.colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colors.border, width: 1),
      ),
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          enabled: hasSelection,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.doc_on_clipboard,
                size: 16,
                color: hasSelection
                    ? theme.colors.textPrimary
                    : theme.colors.textTertiary,
              ),
              const SizedBox(width: 12),
              Text(
                'Copy',
                style: TextStyle(
                  fontSize: 14,
                  color: hasSelection
                      ? theme.colors.textPrimary
                      : theme.colors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'paste',
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.doc_on_clipboard_fill,
                size: 16,
                color: theme.colors.textPrimary,
              ),
              const SizedBox(width: 12),
              Text(
                'Paste',
                style: TextStyle(fontSize: 14, color: theme.colors.textPrimary),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'clear',
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.clear,
                size: 16,
                color: theme.colors.textPrimary,
              ),
              const SizedBox(width: 12),
              Text(
                'Clear',
                style: TextStyle(fontSize: 14, color: theme.colors.textPrimary),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;

      switch (value) {
        case 'copy':
          _copySelection();
          break;
        case 'paste':
          _pasteFromClipboard();
          break;
        case 'clear':
          _terminal.write('\x0C');
          break;
      }
    });
  }

  // SFTP operations
  Future<void> _navigateToPath() async {
    final newPath = _pathController.text.trim();
    if (newPath.isNotEmpty) {
      setState(() => _remotePath = newPath);
      await _loadRemoteFiles();
    }
  }

  Future<void> _navigateUp() async {
    if (_remotePath != '/') {
      final cleanPath = _remotePath.endsWith('/') && _remotePath.length > 1
          ? _remotePath.substring(0, _remotePath.length - 1)
          : _remotePath;

      final parts = cleanPath.split('/')..removeLast();
      setState(
        () => _remotePath = parts.isEmpty || parts.join('/').isEmpty
            ? '/'
            : parts.join('/'),
      );
      await _loadRemoteFiles();
    }
  }

  Future<void> _navigateInto(SFTPItem item) async {
    if (item.isDirectory) {
      setState(() {
        String path = item.path.replaceAll('//', '/');
        _remotePath = path.endsWith('/') ? path : '$path/';
      });
      await _loadRemoteFiles();
    }
  }

  bool _isPreviewableFile(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    const textExtensions = [
      'txt',
      'log',
      'conf',
      'config',
      'json',
      'xml',
      'yaml',
      'yml',
      'md',
      'markdown',
      'sh',
      'bash',
      'py',
      'js',
      'dart',
      'java',
      'go',
      'rs',
      'c',
      'cpp',
      'h',
      'css',
      'html',
      'sql',
      'env',
    ];
    const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];

    return textExtensions.contains(ext) || imageExtensions.contains(ext);
  }

  Future<void> _uploadFile() async {
    final path = await _filePickerService.pickFile();
    if (path != null) {
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
        _currentOperation = 'Uploading ${path.split('/').last}';
      });

      try {
        final remotePath = _remotePath.endsWith('/')
            ? _remotePath
            : '$_remotePath/';
        await _sftpClient!.uploadFile(
          _sessionId,
          path,
          '$remotePath${path.split('/').last}',
          onProgress: (sent, total) {
            setState(() {
              _uploadProgress = sent / total;
            });
          },
        );
        await _loadRemoteFiles();
        if (mounted) {
          _showSuccessDialog('File uploaded successfully');
        }
      } catch (e) {
        if (mounted) {
          _showErrorDialog('Upload error: $e');
        }
      } finally {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
          _currentOperation = '';
        });
      }
    }
  }

  Future<void> _downloadFile(SFTPItem item) async {
    if (item.isDirectory) return;

    final savePath = await _filePickerService.pickSaveLocation(item.name);
    if (savePath != null) {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
        _currentOperation = 'Downloading ${item.name}';
      });

      try {
        await _sftpClient!.downloadFile(
          _sessionId,
          item.path,
          savePath,
          onProgress: (received, total) {
            setState(() {
              _downloadProgress = received / total;
            });
          },
        );
        if (mounted) {
          _showSuccessDialog('File downloaded successfully');
        }
      } catch (e) {
        if (mounted) {
          _showErrorDialog('Download error: $e');
        }
      } finally {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
          _currentOperation = '';
        });
      }
    }
  }

  Future<void> _previewFile(SFTPItem item) async {
    if (item.isDirectory) return;

    if (item.size > 10 * 1024 * 1024) {
      _showErrorDialog('File too large to preview (max 10MB)');
      return;
    }

    final ext = item.name.toLowerCase().split('.').last;
    const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];

    if (mounted) {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => FilePreviewScreen(
            sftpClient: _sftpClient!,
            sessionId: _sessionId,
            item: item,
            isImage: imageExtensions.contains(ext),
          ),
        ),
      );
    }
  }

  Future<void> _createFolder() async {
    final nameController = TextEditingController();

    final folderName = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Create New Folder'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: CupertinoTextField(
            controller: nameController,
            placeholder: 'Folder name',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(nameController.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (folderName != null && folderName.trim().isNotEmpty) {
      setState(() => _isLoadingFiles = true);
      try {
        final remotePath = _remotePath.endsWith('/')
            ? _remotePath
            : '$_remotePath/';
        await _sftpClient!.createDirectory(
          _sessionId,
          '$remotePath${folderName.trim()}',
        );
        await _loadRemoteFiles();
        if (mounted) {
          _showSuccessDialog('Folder created successfully');
        }
      } catch (e) {
        if (mounted) {
          _showErrorDialog('Create folder error: $e');
        }
      } finally {
        setState(() => _isLoadingFiles = false);
      }
    }
  }

  Future<void> _renameItem(SFTPItem item) async {
    final nameController = TextEditingController(text: item.name);

    final newName = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Rename ${item.isDirectory ? "Folder" : "File"}'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: CupertinoTextField(
            controller: nameController,
            placeholder: 'New name',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(nameController.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName != null &&
        newName.trim().isNotEmpty &&
        newName.trim() != item.name) {
      setState(() => _isLoadingFiles = true);
      try {
        final itemPath = item.path.replaceAll('//', '/');
        final parentPath = itemPath.substring(0, itemPath.lastIndexOf('/') + 1);
        final newPath = '$parentPath${newName.trim()}';

        await _sftpClient!.renameFile(_sessionId, itemPath, newPath);
        await _loadRemoteFiles();
        if (mounted) {
          _showSuccessDialog('Renamed successfully');
        }
      } catch (e) {
        if (mounted) {
          _showErrorDialog('Rename error: $e');
        }
      } finally {
        setState(() => _isLoadingFiles = false);
      }
    }
  }

  Future<void> _deleteFile(SFTPItem item) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Delete ${item.isDirectory ? "Directory" : "File"}'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoadingFiles = true);
      try {
        if (item.isDirectory) {
          await _sftpClient!.removeDirectory(_sessionId, item.path);
        } else {
          await _sftpClient!.removeFile(_sessionId, item.path);
        }
        await _loadRemoteFiles();
        if (mounted) {
          _showSuccessDialog('Deleted successfully');
        }
      } catch (e) {
        if (mounted) {
          _showErrorDialog('Delete error: $e');
        }
      } finally {
        setState(() => _isLoadingFiles = false);
      }
    }
  }

  Widget _buildFilePopupMenu(SFTPItem item, AppTheme theme) {
    return GestureDetector(
      onTapDown: (TapDownDetails details) {
        final RenderBox overlay =
            Overlay.of(context).context.findRenderObject() as RenderBox;

        showMenu<String>(
          context: context,
          position: RelativeRect.fromRect(
            details.globalPosition & const Size(40, 40),
            Offset.zero & overlay.size,
          ),
          color: theme.colors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: theme.colors.border, width: 1),
          ),
          items: [
            if (!item.isDirectory && _isPreviewableFile(item.name))
              PopupMenuItem<String>(
                value: 'preview',
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.eye,
                      size: 16,
                      color: theme.colors.textPrimary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Preview',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            if (!item.isDirectory)
              PopupMenuItem<String>(
                value: 'download',
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.arrow_down_circle,
                      size: 16,
                      color: theme.colors.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Download',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            PopupMenuItem<String>(
              value: 'rename',
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.pencil_outline,
                    size: 16,
                    color: theme.colors.textPrimary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Rename',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              height: 1,
              enabled: false,
              padding: EdgeInsets.zero,
              child: Divider(height: 1, color: theme.colors.divider),
            ),
            PopupMenuItem<String>(
              value: 'delete',
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.trash,
                    size: 16,
                    color: theme.colors.error,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Delete',
                    style: TextStyle(fontSize: 14, color: theme.colors.error),
                  ),
                ],
              ),
            ),
          ],
        ).then((value) {
          if (value == null) return;

          switch (value) {
            case 'preview':
              _previewFile(item);
              break;
            case 'download':
              _downloadFile(item);
              break;
            case 'rename':
              _renameItem(item);
              break;
            case 'delete':
              _deleteFile(item);
              break;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(
          CupertinoIcons.ellipsis,
          size: 18,
          color: theme.colors.textSecondary,
        ),
      ),
    );
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

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _disconnect() async {
    _uptimeTimer?.cancel();
    _channel?.sink.close();
    _connectionProvider?.clearActiveConnection();
  }

  @override
  void dispose() {
    _disconnect();
    _terminal.onOutput = null;
    _pathController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
