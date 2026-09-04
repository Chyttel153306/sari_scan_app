import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/phone_security_service.dart';
import 'store/app_store.dart';

class SariScanApp extends StatefulWidget {
  const SariScanApp({super.key, this.store, this.phoneSecurity});

  final AppStore? store;
  final PhoneSecurityAuthenticator? phoneSecurity;

  @override
  State<SariScanApp> createState() => _SariScanAppState();
}

class _SariScanAppState extends State<SariScanApp> {
  late final AppStore store;
  late final bool _ownsStore;
  late final PhoneSecurityAuthenticator _phoneSecurity;

  @override
  void initState() {
    super.initState();
    _ownsStore = widget.store == null;
    store = widget.store ?? AppStore();
    _phoneSecurity = widget.phoneSecurity ?? PhoneSecurityService();
  }

  @override
  void dispose() {
    if (_ownsStore) store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0D631B);
    const greenContainer = Color(0xFF2E7D32);
    const mint = Color(0xFFABF4AC);
    const amber = Color(0xFF8C6800);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: green,
          brightness: Brightness.light,
        ).copyWith(
          primary: green,
          onPrimary: Colors.white,
          primaryContainer: greenContainer,
          onPrimaryContainer: const Color(0xFFCBFFC2),
          secondary: const Color(0xFF286B33),
          onSecondary: Colors.white,
          secondaryContainer: mint,
          onSecondaryContainer: const Color(0xFF07521D),
          tertiary: amber,
          tertiaryContainer: const Color(0xFFFFDF9E),
          error: const Color(0xFFBA1A1A),
          errorContainer: const Color(0xFFFFDAD6),
          surface: const Color(0xFFFCF9F8),
          onSurface: const Color(0xFF1B1C1C),
          onSurfaceVariant: const Color(0xFF40493D),
          outline: const Color(0xFF707A6C),
          outlineVariant: const Color(0xFFBFCABA),
        );

    return MaterialApp(
      title: 'SariScan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF1F8E9),
        useMaterial3: true,
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Color(0xFFFCF9F8),
          foregroundColor: green,
          titleTextStyle: TextStyle(
            color: green,
            fontSize: 20,
            height: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFBFCABA)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFBFCABA)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: green, width: 2),
          ),
          filled: true,
          fillColor: const Color(0xFFFCF9F8),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFFFFFFFF),
          surfaceTintColor: Colors.transparent,
          elevation: 2,
          shadowColor: green.withValues(alpha: 0.10),
          margin: EdgeInsets.zero,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 72,
          backgroundColor: const Color(0xFFFCF9F8),
          indicatorColor: mint,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? green
                  : const Color(0xFF40493D),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      home: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          return store.isAuthenticated
              ? HomeShell(store: store)
              : LoginScreen(store: store, phoneSecurity: _phoneSecurity);
        },
      ),
    );
  }
}
