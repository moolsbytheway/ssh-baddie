// lib/providers/theme_provider.dart - add persistence
import 'package:flutter/foundation.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';

class ThemeProvider extends ChangeNotifier {
  AppTheme _currentTheme = AppTheme.fromMode(AppThemeMode.light);
  final StorageService? _storageService;

  ThemeProvider([this._storageService]) {
    _loadSavedTheme();
  }

  AppTheme get currentTheme => _currentTheme;
  AppThemeMode get currentMode => _currentTheme.mode;

  void _loadSavedTheme() {
    if (_storageService == null) return;

    final savedTheme = _storageService!.getSavedTheme();
    if (savedTheme != null) {
      try {
        final mode = AppThemeMode.values.firstWhere(
          (m) => m.toString() == savedTheme,
        );
        _currentTheme = AppTheme.fromMode(mode);
        notifyListeners();
      } catch (e) {
        print('Failed to load saved theme: $e');
      }
    }
  }

  void setTheme(AppThemeMode mode) {
    _currentTheme = AppTheme.fromMode(mode);
    _storageService?.saveTheme(mode.toString());
    notifyListeners();
  }

  void toggleTheme() {
    final modes = AppThemeMode.values;
    final currentIndex = modes.indexOf(_currentTheme.mode);
    final nextIndex = (currentIndex + 1) % modes.length;
    setTheme(modes[nextIndex]);
  }
}
