import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'l10n/app_localizations.dart';
import 'screens/login_screen.dart';
import 'services/phone_security_service.dart';
import 'store/app_store.dart';
import 'theme/app_theme.dart';

/// Sets the app theme, language, and login or home screen.
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
  /// Uses the supplied store and phone security service, or creates local instances.
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
  /// Reads store state to choose login or home and apply language and theme.
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store.dataChanges,
      builder: (context, _) => MaterialApp(
        title: 'SariScan',
        builder: (context, child) =>
            AppLanguageScope(language: store.language, child: child!),
        debugShowCheckedModeBanner: false,
        theme: AppTheme.forChoice(store.themeChoice),
        home: store.isAuthenticated
            ? HomeShell(store: store)
            : LoginScreen(store: store, phoneSecurity: _phoneSecurity),
      ),
    );
  }
}
