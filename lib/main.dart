import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/services/firebase_sync_service.dart';
import 'src/services/local_storage_service.dart';
import 'src/store/app_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase powers optional, manual multi-device sync (see the Sync
  // button in Settings). The app still works fully offline even if this
  // fails to initialize, so a Firebase outage or misconfiguration on a
  // brand-new install should never block the person from using the POS.
  FirebaseSyncService? cloudSync;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    cloudSync = FirebaseSyncService();
  } catch (_) {
    cloudSync = null;
  }

  final storage = await LocalStorageService.create();
  final store = AppStore.forApp(storage: storage, cloudSync: cloudSync);
  await store.initialize();
  runApp(SariScanApp(store: store));
}