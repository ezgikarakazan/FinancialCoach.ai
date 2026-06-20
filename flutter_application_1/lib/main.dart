import 'package:flutter/material.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(const FinanceCoachApp());
}

class FinanceCoachApp extends StatelessWidget {
  const FinanceCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF5F3EC);
    const surface = Color(0xFFFFFCF6);
    const ink = Color(0xFF1E2722);
    const accent = Color(0xFF1E6B52);
    const accentSoft = Color(0xFFDDEEE7);
    const warning = Color(0xFFC96B3B);

    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      primary: accent,
      secondary: warning,
      surface: surface,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Finance Coach',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: background,
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: ink,
            height: 1.05,
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          titleLarge: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: ink,
            height: 1.45,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: Color(0xFF53625B),
            height: 1.4,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: ink,
          titleTextStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: surface,
          indicatorColor: accentSoft,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: accent,
                fontWeight: FontWeight.w700,
              );
            }
            return const TextStyle(
              color: Color(0xFF67756F),
              fontWeight: FontWeight.w500,
            );
          }),
        ),
      ),
      home: const MainScreen(),
    );
  }
}