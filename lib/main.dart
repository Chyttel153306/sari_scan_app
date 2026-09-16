import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/services/firebase_sync_service.dart';
import 'src/services/imgbb_image_service.dart';
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

  // ImgBB (a free image host, no credit card required) mirrors product
  // photos so they show up on every synced phone, not just the one that
  // took the picture. Pass a real key at build/run time, e.g.:
  //   flutter run --dart-define=IMGBB_API_KEY=your_key_here
  // With no key configured, photo sync is simply skipped — everything
  // else (products, sales, utang) keeps syncing normally through Firebase.
  const imgbbApiKey = String.fromEnvironment('IMGBB_API_KEY');
  final imageSync = imgbbApiKey.isEmpty
      ? null
      : ImgbbImageService(apiKey: imgbbApiKey);

  final storage = await LocalStorageService.create();
  final store = AppStore.forApp(
    storage: storage,
    cloudSync: cloudSync,
    imageSync: imageSync,
  );
  await store.initialize();
  runApp(SariScanApp(store: store));
}