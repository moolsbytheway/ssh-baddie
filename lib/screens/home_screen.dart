// lib/screens/home_screen.dart - With collapsible groups and two-column layout
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssh_baddie/screens/workspace_screen.dart';
import 'package:ssh_baddie/theme/app_theme.dart';
import 'package:uuid/uuid.dart';
import '../providers/connection_provider.dart';
import '../providers/theme_provider.dart';
import '../models/ssh_connection.dart';
import 'connection_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sidebar Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SSH Baddie',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colors.textPrimary,
                      ),
                    ),
                    Text(
                      'Manage your connections',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Navigation
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      _buildSidebarItem(
                        icon: CupertinoIcons.square_grid_2x2,
                        label: 'Connections',
                        isSelected: _selectedIndex == 0,
                        onTap: () => setState(() => _selectedIndex = 0),
                        theme: theme,
                      ),
                      const SizedBox(height: 4),
                      _buildSidebarItem(
                        icon: CupertinoIcons.settings,
                        label: 'Settings',
                        isSelected: _selectedIndex == 1,
                        onTap: () => setState(() => _selectedIndex = 1),
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ),
              // Quick Stats
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: theme.colors.border, width: 1),
                  ),
                ),
                child: Consumer<ConnectionProvider>(
                  builder: (context, provider, child) {
                    final activeCount = provider.connections
                        .where((c) => provider.isConnectionActive(c.id))
                        .length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Stats',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: theme.colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Active',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colors.textSecondary,
                              ),
                            ),
                            Text(
                              '$activeCount',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.colors.success,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colors.textSecondary,
                              ),
                            ),
                            Text(
                              '${provider.connections.length}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: Container(
            color: theme.colors.background,
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                ConnectionsView(
                  searchQuery: _searchQuery,
                  searchController: _searchController,
                  onSearchChanged: (query) =>
                      setState(() => _searchQuery = query),
                ),
                const SettingsView(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required AppTheme theme,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
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
              size: 20,
              color: isSelected
                  ? theme.colors.primary
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
                    : theme.colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConnectionsView extends StatefulWidget {
  final String searchQuery;
  final TextEditingController searchController;
  final Function(String) onSearchChanged;

  const ConnectionsView({
    super.key,
    required this.searchQuery,
    required this.searchController,
    required this.onSearchChanged,
  });

  @override
  State<ConnectionsView> createState() => _ConnectionsViewState();
}

class _ConnectionsViewState extends State<ConnectionsView> {
  final Map<String, bool> _expandedGroups = {};

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;

    return Consumer<ConnectionProvider>(
      builder: (context, provider, child) {
        final groupedConnections = _groupConnections(provider.connections);
        final filteredGroups = _filterGroups(
          groupedConnections,
          widget.searchQuery,
        );

        // Initialize expanded state for new groups
        for (final groupName in filteredGroups.keys) {
          _expandedGroups.putIfAbsent(groupName, () => true);
        }

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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'SSH Connections',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.colors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      CupertinoButton.filled(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        onPressed: () => _showConnectionForm(context, null),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.add, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'New Connection',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  Container(
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
                            size: 18,
                            color: theme.colors.textSecondary,
                          ),
                        ),
                        Expanded(
                          child: CupertinoTextField(
                            controller: widget.searchController,
                            placeholder: 'Search connections...',
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
                            onChanged: widget.onSearchChanged,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Connections Grid
            Expanded(
              child: provider.connections.isEmpty
                  ? _buildEmptyState(context, theme)
                  : ListView(
                      padding: const EdgeInsets.all(24),
                      children: filteredGroups.entries.map((entry) {
                        return _buildConnectionGroup(
                          context,
                          entry.key,
                          entry.value,
                          theme,
                          provider,
                        );
                      }).toList(),
                    ),
            ),
          ],
        );
      },
    );
  }

  Map<String, List<SSHConnection>> _groupConnections(
    List<SSHConnection> connections,
  ) {
    final groups = <String, List<SSHConnection>>{};

    for (final conn in connections) {
      String groupName = conn.group ?? 'Servers';

      if (conn.group == null) {
        if (conn.host.contains('prod')) {
          groupName = 'Production';
        } else if (conn.host.contains('staging') || conn.host.contains('stg')) {
          groupName = 'Staging';
        } else if (conn.host.contains('dev') || conn.host.contains('test')) {
          groupName = 'Development';
        }
      }

      groups.putIfAbsent(groupName, () => []).add(conn);
    }

    return groups;
  }

  Map<String, List<SSHConnection>> _filterGroups(
    Map<String, List<SSHConnection>> groups,
    String query,
  ) {
    if (query.isEmpty) return groups;

    final filtered = <String, List<SSHConnection>>{};
    final lowerQuery = query.toLowerCase();

    for (final entry in groups.entries) {
      final filteredConns = entry.value
          .where(
            (conn) =>
                conn.name.toLowerCase().contains(lowerQuery) ||
                conn.host.toLowerCase().contains(lowerQuery) ||
                conn.username.toLowerCase().contains(lowerQuery),
          )
          .toList();

      if (filteredConns.isNotEmpty) {
        filtered[entry.key] = filteredConns;
      }
    }

    return filtered;
  }

  Widget _buildConnectionGroup(
    BuildContext context,
    String groupName,
    List<SSHConnection> connections,
    AppTheme theme,
    ConnectionProvider provider,
  ) {
    final isExpanded = _expandedGroups[groupName] ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group Header (Collapsible)
        GestureDetector(
          onTap: () {
            setState(() {
              _expandedGroups[groupName] = !isExpanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            margin: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(
                  isExpanded
                      ? CupertinoIcons.chevron_down
                      : CupertinoIcons.chevron_right,
                  size: 14,
                  color: theme.colors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  groupName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colors.inputBackground,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${connections.length}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: theme.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Connections in Two Columns
        if (isExpanded)
          LayoutBuilder(
            builder: (context, constraints) {
              // Calculate number of columns based on available width
              final cardWidth = 400.0;
              final spacing = 16.0;
              final columns = (constraints.maxWidth / (cardWidth + spacing))
                  .floor()
                  .clamp(1, 2);

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: connections.map((conn) {
                  return SizedBox(
                    width: columns == 2
                        ? (constraints.maxWidth - spacing) / 2
                        : constraints.maxWidth,
                    child: ConnectionCard(
                      connection: conn,
                      isActive: provider.isConnectionActive(conn.id),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, AppTheme theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.colors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.square_grid_2x2,
              size: 64,
              color: theme.colors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No connections yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: theme.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first SSH connection to get started',
            style: TextStyle(fontSize: 14, color: theme.colors.textSecondary),
          ),
          const SizedBox(height: 32),
          CupertinoButton.filled(
            onPressed: () => _showConnectionForm(context, null),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.add, size: 18),
                SizedBox(width: 8),
                Text(
                  'Add Connection',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showConnectionForm(BuildContext context, SSHConnection? connection) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: const Color(0x80000000),
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: Center(
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, -0.1),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: ConnectionFormSheet(connection: connection),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ConnectionCard extends StatefulWidget {
  final SSHConnection connection;
  final bool isActive;

  const ConnectionCard({
    super.key,
    required this.connection,
    required this.isActive,
  });

  @override
  State<ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<ConnectionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: theme.colors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered
                ? theme.colors.primary.withOpacity(0.5)
                : theme.colors.border,
            width: 1,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: theme.colors.primary.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: widget.isActive
                                  ? theme.colors.success
                                  : theme.colors.textTertiary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.isActive ? 'Connected' : 'Disconnected',
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
                _buildPopupMenu(context, theme),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  CupertinoIcons.device_desktop,
                  size: 12,
                  color: theme.colors.textSecondary,
                ),
                const SizedBox(width: 6),
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
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  CupertinoIcons.time,
                  size: 12,
                  color: theme.colors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatLastUsed(widget.connection.lastUsed),
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colors.textSecondary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colors.inputBackground,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ':${widget.connection.port}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colors.textSecondary,
                      fontFamily: 'Menlo',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colors.border.withOpacity(0.5),
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      color: theme.colors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      onPressed: () => _connect(context, widget.connection),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.bolt_circle,
                            size: 16,
                            color: theme.colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Connect',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
          ],
        ),
      ),
    );
  }

  String _formatLastUsed(DateTime lastUsed) {
    final now = DateTime.now();
    final difference = now.difference(lastUsed);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }

  Widget _buildPopupMenu(BuildContext context, AppTheme theme) {
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
            PopupMenuItem<String>(
              value: 'edit',
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.pencil,
                    size: 16,
                    color: theme.colors.textPrimary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'duplicate',
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.doc_on_doc,
                    size: 16,
                    color: theme.colors.textPrimary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Duplicate',
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
            case 'edit':
              Navigator.of(context).push(
                PageRouteBuilder(
                  opaque: false,
                  barrierDismissible: true,
                  barrierColor: const Color(0x80000000),
                  pageBuilder: (context, animation, secondaryAnimation) {
                    return FadeTransition(
                      opacity: animation,
                      child: Center(
                        child: ConnectionFormSheet(
                          connection: widget.connection,
                        ),
                      ),
                    );
                  },
                ),
              );
              break;
            case 'duplicate':
              final duplicated = SSHConnection(
                id: const Uuid().v4(),
                name: '${widget.connection.name} (Copy)',
                host: widget.connection.host,
                port: widget.connection.port,
                username: widget.connection.username,
                password: widget.connection.password,
                privateKey: widget.connection.privateKey,
                passphrase: widget.connection.passphrase,
                createdAt: DateTime.now(),
                lastUsed: DateTime.now(),
              );
              context.read<ConnectionProvider>().addConnection(duplicated);
              break;
            case 'delete':
              _confirmDelete(context, widget.connection);
              break;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Icon(
          CupertinoIcons.ellipsis,
          size: 16,
          color: theme.colors.textSecondary,
        ),
      ),
    );
  }

  void _connect(BuildContext context, SSHConnection connection) {
    final updatedConnection = connection.copyWith(lastUsed: DateTime.now());
    context.read<ConnectionProvider>().addConnection(updatedConnection);

    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => WorkspaceScreen(connection: updatedConnection),
      ),
    );
  }

  void _confirmDelete(BuildContext context, SSHConnection connection) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Connection'),
        content: Text('Are you sure you want to delete "${connection.name}"?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              context.read<ConnectionProvider>().deleteConnection(
                connection.id,
              );
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// Settings View (keeping the same as before)
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentTheme;

    return Container(
      color: theme.colors.background,
      child: Column(
        children: [
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: theme.colors.surface,
              border: Border(
                bottom: BorderSide(color: theme.colors.border, width: 1),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.centerLeft,
            child: Text(
              'Settings',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: theme.colors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: theme.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose your preferred color scheme',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...AppThemeMode.values.map((mode) {
                    final isSelected = themeProvider.currentMode == mode;
                    return GestureDetector(
                      onTap: () => themeProvider.setTheme(mode),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colors.primary.withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? theme.colors.primary
                                : theme.colors.border,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? CupertinoIcons.checkmark_circle_fill
                                  : CupertinoIcons.circle,
                              size: 20,
                              color: isSelected
                                  ? theme.colors.primary
                                  : theme.colors.textSecondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getThemeName(mode),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _getThemeDescription(mode),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildThemePreview(mode, theme),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemePreview(AppThemeMode mode, AppTheme currentTheme) {
    final previewTheme = AppTheme.fromMode(mode);

    return Container(
      width: 60,
      height: 40,
      decoration: BoxDecoration(
        color: previewTheme.colors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: currentTheme.colors.border, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: previewTheme.colors.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  bottomLeft: Radius.circular(5),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: previewTheme.colors.primary.withOpacity(0.3),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: previewTheme.colors.accent.withOpacity(0.3),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(5),
                  bottomRight: Radius.circular(5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getThemeName(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.nord:
        return 'Nord';
      case AppThemeMode.monokai:
        return 'Monokai';
      case AppThemeMode.gruvboxDark:
        return 'Gruvbox Dark';
      case AppThemeMode.oneDark:
        return 'One Dark';
      case AppThemeMode.tokyoNight:
        return 'Tokyo Night';
      case AppThemeMode.catppuccinMocha:
        return 'Catppuccin Mocha';
      case AppThemeMode.material:
        return 'Material';
      case AppThemeMode.horizon:
        return 'Horizon';
    }
  }

  String _getThemeDescription(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.dark:
        return 'Classic dark theme';
      case AppThemeMode.light:
        return 'Clean light theme';
      case AppThemeMode.nord:
        return 'Arctic, north-bluish color palette';
      case AppThemeMode.monokai:
        return 'Classic Sublime Text theme';
      case AppThemeMode.gruvboxDark:
        return 'Retro groove with warm colors';
      case AppThemeMode.oneDark:
        return 'Popular Atom editor theme';
      case AppThemeMode.tokyoNight:
        return 'Modern dark theme inspired by Tokyo nights';
      case AppThemeMode.catppuccinMocha:
        return 'Soothing pastel theme with cozy aesthetics';
      case AppThemeMode.material:
        return 'Material Design inspired colors';
      case AppThemeMode.horizon:
        return 'Warm dark theme with vibrant accents';
    }
  }
}
