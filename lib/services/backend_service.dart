// lib/services/backend_service.dart
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class BackendService {
  static const int defaultPort = 8822;
  static const int maxPortAttempts = 10;
  static const String backendHost = 'localhost';

  int _port = defaultPort;
  Process? _backendProcess;
  bool _isRunning = false;
  bool _isDevelopmentMode = false;

  int get port => _port;

  /// Initialize with optional custom port
  /// If port is busy, will automatically find an available one
  Future<void> initialize({int? port}) async {
    if (_isRunning) return;

    final preferredPort = port ?? _getPortFromArgs() ?? defaultPort;

    // Try to connect to existing backend first (development mode)
    _port = preferredPort;
    if (await _checkExistingBackend()) {
      _isDevelopmentMode = true;
      _isRunning = true;
      print('✅ Connected to development backend on port $_port');
      return;
    }

    // Find an available port
    _port = await _findAvailablePort(preferredPort);
    print('🔌 Using port $_port');

    // Try to start embedded backend
    try {
      final backendPath = _getBackendPath();
      print('🔍 Looking for backend at: $backendPath');

      if (!File(backendPath).existsSync()) {
        throw Exception(
          'Backend binary not found at: $backendPath\n'
          'Run ./build_backend.sh to build the backend binary.',
        );
      }

      // Ensure executable permissions
      await Process.run('chmod', ['+x', backendPath]);

      _backendProcess = await Process.start(backendPath, [
        '--port',
        _port.toString(),
      ]);

      _backendProcess!.stdout.listen((data) {
        print('[Backend] ${String.fromCharCodes(data)}');
      });

      _backendProcess!.stderr.listen((data) {
        print('[Backend Error] ${String.fromCharCodes(data)}');
      });

      // Listen for process exit
      _backendProcess!.exitCode.then((code) {
        print('[Backend] Process exited with code: $code');
        _isRunning = false;
      });

      await _waitForBackend();
      _isRunning = true;
      print('✅ Embedded backend started on port $_port');
    } catch (e) {
      print('❌ Failed to start backend: $e');
      print(
        '💡 Run the backend separately: cd go-backend && go run . --port $_port',
      );
      rethrow;
    }
  }

  /// Find an available port starting from preferredPort
  Future<int> _findAvailablePort(int preferredPort) async {
    for (int i = 0; i < maxPortAttempts; i++) {
      final portToTry = preferredPort + i;
      if (await _isPortAvailable(portToTry)) {
        return portToTry;
      }
      print('⚠️ Port $portToTry is busy, trying next...');
    }
    throw Exception(
      'Could not find available port in range $preferredPort-${preferredPort + maxPortAttempts - 1}',
    );
  }

  /// Check if a port is available by trying to bind to it
  Future<bool> _isPortAvailable(int port) async {
    try {
      final server = await ServerSocket.bind(backendHost, port);
      await server.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Parse port from command line arguments
  /// Usage: open SSH\ Baddie.app --args --port 9000
  int? _getPortFromArgs() {
    final args = Platform.executableArguments;
    for (int i = 0; i < args.length - 1; i++) {
      if (args[i] == '--port' || args[i] == '-p') {
        return int.tryParse(args[i + 1]);
      }
    }
    // Also check environment variable
    final envPort = Platform.environment['SSH_BADDIE_PORT'];
    if (envPort != null) {
      return int.tryParse(envPort);
    }
    return null;
  }

  String _getBackendPath() {
    if (Platform.isMacOS) {
      final executablePath = Platform.resolvedExecutable;
      print('📍 Executable path: $executablePath');

      final appDir = Directory(executablePath).parent;
      final contentsDir = appDir.parent;

      print('📁 Contents directory: ${contentsDir.path}');

      // Try multiple possible locations
      final possiblePaths = [
        // Standard Resources location
        path.join(contentsDir.path, 'Resources', 'ssh-backend'),
        // Frameworks location (fallback)
        path.join(contentsDir.path, 'Frameworks', 'ssh-backend'),
        // Development location
        path.join(
          Directory.current.path,
          'macos',
          'Runner',
          'Resources',
          'ssh-backend',
        ),
        // Project root
        path.join(Directory.current.path, 'ssh-backend'),
      ];

      for (final possiblePath in possiblePaths) {
        print('🔍 Checking: $possiblePath');
        if (File(possiblePath).existsSync()) {
          print('✅ Found backend at: $possiblePath');
          return possiblePath;
        }
      }

      // List what's actually in Resources
      final resourcesDir = Directory(path.join(contentsDir.path, 'Resources'));
      if (resourcesDir.existsSync()) {
        print('📂 Contents of Resources:');
        resourcesDir.listSync().forEach((entity) {
          print('   - ${path.basename(entity.path)}');
        });
      } else {
        print('❌ Resources directory does not exist');
      }

      throw Exception(
        'Backend not found. Tried:\n${possiblePaths.map((p) => '  - $p').join('\n')}',
      );
    }

    throw UnsupportedError(
      'Platform not supported: ${Platform.operatingSystem}',
    );
  }

  Future<bool> _checkExistingBackend() async {
    try {
      final response = await http
          .get(Uri.parse('http://$backendHost:$_port/health'))
          .timeout(const Duration(milliseconds: 500));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> _waitForBackend({int maxAttempts = 30}) async {
    for (int i = 0; i < maxAttempts; i++) {
      try {
        final response = await http
            .get(Uri.parse('http://$backendHost:$_port/health'))
            .timeout(const Duration(seconds: 1));

        if (response.statusCode == 200) {
          print('✅ Backend health check passed');
          return;
        }
      } catch (e) {
        if (i % 10 == 0) {
          print('⏳ Waiting for backend... (attempt ${i + 1}/$maxAttempts)');
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    throw Exception('Backend failed to start within ${maxAttempts * 100}ms');
  }

  String get baseUrl => 'http://$backendHost:$_port';

  bool get isRunning => _isRunning;

  bool get isDevelopmentMode => _isDevelopmentMode;

  Future<void> dispose() async {
    if (!_isDevelopmentMode && _backendProcess != null) {
      print('🛑 Stopping backend...');
      _backendProcess!.kill(ProcessSignal.sigterm);

      // Wait for graceful shutdown
      try {
        await _backendProcess!.exitCode.timeout(const Duration(seconds: 3));
        print('✅ Backend stopped gracefully');
      } catch (e) {
        // Force kill if graceful shutdown fails
        print('⚠️  Force killing backend...');
        _backendProcess!.kill(ProcessSignal.sigkill);
      }

      _isRunning = false;
    }
  }
}
