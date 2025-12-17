// lib/screens/connection_form_screen.dart - Add group selection
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sshbaddie/theme/app_theme.dart';
import 'package:uuid/uuid.dart';
import '../models/ssh_connection.dart';
import '../providers/connection_provider.dart';
import '../providers/theme_provider.dart';
import '../services/file_picker_service.dart';

class ConnectionFormSheet extends StatefulWidget {
  final SSHConnection? connection;

  const ConnectionFormSheet({super.key, this.connection});

  @override
  State<ConnectionFormSheet> createState() => _ConnectionFormSheetState();
}

class _ConnectionFormSheetState extends State<ConnectionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passphraseController = TextEditingController();

  bool _usePrivateKey = false;
  String? _privateKeyPath;
  final _filePickerService = FilePickerService();

  // Group selection
  String _selectedGroup = 'Servers';
  final List<String> _availableGroups = [
    'Servers',
    'Production',
    'Staging',
    'Development',
    'Testing',
    'Database',
    'Personal',
  ];

  // Validation error messages
  String? _nameError;
  String? _hostError;
  String? _portError;
  String? _usernameError;
  String? _passwordError;
  String? _privateKeyError;

  @override
  void initState() {
    super.initState();
    if (widget.connection != null) {
      _nameController.text = widget.connection!.name;
      _hostController.text = widget.connection!.host;
      _portController.text = widget.connection!.port.toString();
      _usernameController.text = widget.connection!.username;
      _passwordController.text = widget.connection!.password ?? '';
      _usePrivateKey = widget.connection!.privateKey != null;
      _selectedGroup = widget.connection!.group ?? 'Servers';
    }

    // Add listeners to clear errors when user types
    _nameController.addListener(() {
      if (_nameError != null) setState(() => _nameError = null);
    });

    _hostController.addListener(() {
      if (_hostError != null) setState(() => _hostError = null);
    });

    _portController.addListener(() {
      if (_portError != null) setState(() => _portError = null);
    });

    _usernameController.addListener(() {
      if (_usernameError != null) setState(() => _usernameError = null);
    });

    _passwordController.addListener(() {
      if (_passwordError != null) setState(() => _passwordError = null);
    });
  }

  bool _validateForm() {
    bool isValid = true;

    setState(() {
      if (_nameController.text.trim().isEmpty) {
        _nameError = 'Connection name is required';
        isValid = false;
      } else {
        _nameError = null;
      }

      if (_hostController.text.trim().isEmpty) {
        _hostError = 'Host is required';
        isValid = false;
      } else if (!_isValidHost(_hostController.text.trim())) {
        _hostError = 'Invalid host format';
        isValid = false;
      } else {
        _hostError = null;
      }

      final port = int.tryParse(_portController.text.trim());
      if (_portController.text.trim().isEmpty) {
        _portError = 'Port is required';
        isValid = false;
      } else if (port == null || port < 1 || port > 65535) {
        _portError = 'Port must be between 1 and 65535';
        isValid = false;
      } else {
        _portError = null;
      }

      if (_usernameController.text.trim().isEmpty) {
        _usernameError = 'Username is required';
        isValid = false;
      } else {
        _usernameError = null;
      }

      if (!_usePrivateKey) {
        if (_passwordController.text.isEmpty) {
          _passwordError = 'Password is required';
          isValid = false;
        } else {
          _passwordError = null;
        }
        _privateKeyError = null;
      } else {
        _passwordError = null;
        if (_privateKeyPath == null && widget.connection?.privateKey == null) {
          _privateKeyError = 'Please select a private key';
          isValid = false;
        } else {
          _privateKeyError = null;
        }
      }
    });

    return isValid;
  }

  bool _isValidHost(String host) {
    final ipRegex = RegExp(
      r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
    );
    final hostnameRegex = RegExp(
      r'^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$',
    );

    return ipRegex.hasMatch(host) || hostnameRegex.hasMatch(host);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        color: Colors.transparent,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              constraints: const BoxConstraints(maxHeight: 650, maxWidth: 600),
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colors.border, width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.connection == null
                              ? 'New Connection'
                              : 'Edit Connection',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: theme.colors.textPrimary,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        child: Icon(
                          CupertinoIcons.xmark,
                          color: theme.colors.textSecondary,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Form content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTextField(
                              controller: _nameController,
                              label: 'Connection Name',
                              placeholder: 'My Server',
                              icon: CupertinoIcons.tag,
                              theme: theme,
                              error: _nameError,
                            ),
                            const SizedBox(height: 16),

                            // Group selector
                            _buildGroupSelector(theme),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildTextField(
                                    controller: _hostController,
                                    label: 'Host',
                                    placeholder: '192.168.1.100',
                                    icon: CupertinoIcons.globe,
                                    theme: theme,
                                    error: _hostError,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 1,
                                  child: _buildTextField(
                                    controller: _portController,
                                    label: 'Port',
                                    placeholder: '22',
                                    icon: CupertinoIcons.number,
                                    theme: theme,
                                    error: _portError,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _usernameController,
                              label: 'Username',
                              placeholder: 'root',
                              icon: CupertinoIcons.person,
                              theme: theme,
                              error: _usernameError,
                            ),
                            const SizedBox(height: 16),
                            // Private key toggle
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colors.inputBackground,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: theme.colors.border,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CupertinoSwitch(
                                    value: _usePrivateKey,
                                    activeColor: theme.colors.primary,
                                    onChanged: (value) {
                                      setState(() {
                                        _usePrivateKey = value;
                                        _passwordError = null;
                                        _privateKeyError = null;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Use Private Key',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: theme.colors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (!_usePrivateKey) ...[
                              _buildTextField(
                                controller: _passwordController,
                                label: 'Password',
                                placeholder: 'Password',
                                icon: CupertinoIcons.lock,
                                obscureText: true,
                                theme: theme,
                                error: _passwordError,
                              ),
                            ] else ...[
                              _buildPrivateKeySelector(theme),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _passphraseController,
                                label: 'Passphrase (optional)',
                                placeholder: 'Key passphrase',
                                icon: CupertinoIcons.lock_shield,
                                obscureText: true,
                                theme: theme,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Footer buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      CupertinoButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: theme.colors.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      CupertinoButton.filled(
                        onPressed: _saveConnection,
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupSelector(AppTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Group',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTapDown: (TapDownDetails details) {
            _showGroupDropdown(theme, details.globalPosition);
          },
          child: Container(
            decoration: BoxDecoration(
              color: theme.colors.inputBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colors.border, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.square_stack_3d_up,
                  size: 16,
                  color: theme.colors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedGroup,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_down,
                  size: 16,
                  color: theme.colors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showGroupDropdown(AppTheme theme, Offset position) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy + 10, 200, 0),
        Offset.zero & overlay.size,
      ),
      color: theme.colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colors.border, width: 1),
      ),
      items: _availableGroups.map((group) {
        final isSelected = group == _selectedGroup;
        return PopupMenuItem<String>(
          value: group,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.circle,
                size: 18,
                color: isSelected
                    ? theme.colors.primary
                    : theme.colors.textTertiary,
              ),
              const SizedBox(width: 12),
              Text(
                group,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? theme.colors.primary
                      : theme.colors.textPrimary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ).then((value) {
      if (value != null) {
        setState(() {
          _selectedGroup = value;
        });
      }
    });
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    required IconData icon,
    required AppTheme theme,
    bool obscureText = false,
    String? error,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: theme.colors.inputBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: error != null ? theme.colors.error : theme.colors.border,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Icon(icon, size: 16, color: theme.colors.textSecondary),
              ),
              Expanded(
                child: CupertinoTextField(
                  controller: controller,
                  placeholder: placeholder,
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  style: TextStyle(
                    color: theme.colors.textPrimary,
                    fontSize: 14,
                  ),
                  placeholderStyle: TextStyle(
                    color: theme.colors.textTertiary,
                    fontSize: 14,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    border: Border(),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error,
            style: TextStyle(fontSize: 11, color: theme.colors.error),
          ),
        ],
      ],
    );
  }

  Widget _buildPrivateKeySelector(AppTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Private Key',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colors.inputBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _privateKeyError != null
                  ? theme.colors.error
                  : theme.colors.border,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.doc,
                size: 18,
                color: theme.colors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _privateKeyPath ??
                      (widget.connection?.privateKey != null
                          ? 'Key loaded'
                          : 'No key selected'),
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        _privateKeyPath != null ||
                            widget.connection?.privateKey != null
                        ? theme.colors.textPrimary
                        : theme.colors.textSecondary,
                    fontFamily: 'Menlo',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                color: theme.colors.primary,
                onPressed: _pickPrivateKey,
                child: const Text(
                  'Select',
                  style: TextStyle(fontSize: 12, color: CupertinoColors.white),
                ),
              ),
            ],
          ),
        ),
        if (_privateKeyError != null) ...[
          const SizedBox(height: 6),
          Text(
            _privateKeyError!,
            style: TextStyle(fontSize: 11, color: theme.colors.error),
          ),
        ],
      ],
    );
  }

  Future<void> _pickPrivateKey() async {
    final path = await _filePickerService.pickFile();
    if (path != null) {
      setState(() {
        _privateKeyPath = path;
        _privateKeyError = null;
      });
    }
  }

  Future<void> _saveConnection() async {
    if (!_validateForm()) {
      return;
    }

    String? privateKeyContent;
    if (_usePrivateKey && _privateKeyPath != null) {
      privateKeyContent = await _filePickerService.readFileAsString(
        _privateKeyPath!,
      );
    } else if (_usePrivateKey && widget.connection?.privateKey != null) {
      privateKeyContent = widget.connection!.privateKey;
    }

    final connection = SSHConnection(
      id: widget.connection?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      host: _hostController.text.trim(),
      port: int.parse(_portController.text.trim()),
      username: _usernameController.text.trim(),
      password: _usePrivateKey ? null : _passwordController.text,
      privateKey: privateKeyContent,
      passphrase: _passphraseController.text.isEmpty
          ? null
          : _passphraseController.text,
      createdAt: widget.connection?.createdAt ?? DateTime.now(),
      lastUsed: widget.connection?.lastUsed ?? DateTime.now(),
      group: _selectedGroup, // Add group field
    );

    await context.read<ConnectionProvider>().addConnection(connection);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }
}
