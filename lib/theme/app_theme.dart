// lib/theme/app_theme.dart
import 'package:flutter/cupertino.dart';
import 'package:xterm/xterm.dart';
import 'app_colors.dart';

enum AppThemeMode {
  light,
  dark,
  nord,
  gruvboxDark,
  oneDark,
  tokyoNight,
  catppuccinMocha,
  material,
  horizon,
  monokai,
}

class AppTheme {
  final AppThemeMode mode;
  final AppColors colors;

  const AppTheme({required this.mode, required this.colors});

  static AppTheme fromMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.dark:
        return const AppTheme(mode: AppThemeMode.dark, colors: AppColors.dark);
      case AppThemeMode.light:
        return const AppTheme(
          mode: AppThemeMode.light,
          colors: AppColors.light,
        );
      case AppThemeMode.nord:
        return const AppTheme(mode: AppThemeMode.nord, colors: AppColors.nord);
      case AppThemeMode.monokai:
        return const AppTheme(
          mode: AppThemeMode.monokai,
          colors: AppColors.monokai,
        );
      case AppThemeMode.gruvboxDark:
        return const AppTheme(
          mode: AppThemeMode.gruvboxDark,
          colors: AppColors.gruvboxDark,
        );
      case AppThemeMode.oneDark:
        return const AppTheme(
          mode: AppThemeMode.oneDark,
          colors: AppColors.oneDark,
        );
      case AppThemeMode.tokyoNight:
        return const AppTheme(
          mode: AppThemeMode.tokyoNight,
          colors: AppColors.tokyoNight,
        );
      case AppThemeMode.catppuccinMocha:
        return const AppTheme(
          mode: AppThemeMode.catppuccinMocha,
          colors: AppColors.catppuccinMocha,
        );
      case AppThemeMode.material:
        return const AppTheme(
          mode: AppThemeMode.material,
          colors: AppColors.material,
        );
      case AppThemeMode.horizon:
        return const AppTheme(
          mode: AppThemeMode.horizon,
          colors: AppColors.horizon,
        );
    }
  }

  // Helper to get theme display name
  String get displayName {
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

  // Get all available themes
  static List<AppThemeMode> get allThemes => AppThemeMode.values;

  TerminalTheme get terminalTheme {
    return TerminalTheme(
      cursor: colors.terminalCursor,
      selection: colors.terminalSelection.withOpacity(
        0.5,
      ), // Semi-transparent selection
      foreground: colors.terminalForeground,
      background: colors.terminalBackground,
      black: colors.terminalBlack,
      red: colors.terminalRed,
      green: colors.terminalGreen,
      yellow: colors.terminalYellow,
      blue: colors.terminalBlue,
      magenta: colors.terminalMagenta,
      cyan: colors.terminalCyan,
      white: colors.terminalWhite,
      brightBlack: colors.terminalBrightBlack,
      brightRed: colors.terminalBrightRed,
      brightGreen: colors.terminalBrightGreen,
      brightYellow: colors.terminalBrightYellow,
      brightBlue: colors.terminalBrightBlue,
      brightMagenta: colors.terminalBrightMagenta,
      brightCyan: colors.terminalBrightCyan,
      brightWhite: colors.terminalBrightWhite,
      searchHitBackground: colors.warning,
      searchHitBackgroundCurrent: colors.primary,
      searchHitForeground: colors.terminalBackground,
    );
  }

  TerminalStyle get terminalStyle {
    return const TerminalStyle(fontFamily: 'monospace', fontSize: 13);
  }

  Brightness get brightness {
    return mode == AppThemeMode.light ? Brightness.light : Brightness.dark;
  }

  // Check if theme is dark
  bool get isDark => mode != AppThemeMode.light;
}
