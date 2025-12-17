// lib/main.dart - update
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DefaultMaterialLocalizations;
import 'package:provider/provider.dart';

import 'providers/connection_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'services/backend_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();

  final backendService = BackendService();
  await backendService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ConnectionProvider(storageService),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider(storageService)),
        Provider.value(value: backendService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final theme = themeProvider.currentTheme;
        return CupertinoApp(
          title: 'SSH Baddie',
          theme: CupertinoThemeData(
            brightness: theme.brightness,
            primaryColor: theme.colors.primary,
            scaffoldBackgroundColor: theme.colors.background,
            textTheme: CupertinoTextThemeData(
              primaryColor: theme.colors.textPrimary,
            ),
          ),
          localizationsDelegates: const [DefaultMaterialLocalizations.delegate],
          home: Container(
            color: theme.colors.background,
            child: const HomeScreen(),
          ),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
