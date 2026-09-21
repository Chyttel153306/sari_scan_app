import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/services/local_storage_service.dart';
import 'src/services/supabase_image_service.dart';
import 'src/services/supabase_sync_service.dart';
import 'src/store/app_store.dart';

// The project URL and publishable (anon) key are meant to ship inside the
// app: what protects the data is Row Level Security and the Storage
// policies, not the secrecy of these two values. Never put the
// service-role / secret key here. To point a build at another project:
//   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://uobzpgufatdvctqxtywu.supabase.co',
);
const _supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_MfYnja_5n658MMsCcvOVcw_yS2MR9NY',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase powers optional, manual multi-device sync (see the Sync
  // button in Settings) and product photo sync. The app still works fully
  // offline even if this fails to initialize, so a Supabase outage or
  // misconfiguration on a brand-new install should never block the person
  // from using the POS.
  SupabaseSyncService? cloudSync;
  SupabaseImageService? imageSync;
  try {
    await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseAnonKey);
    cloudSync = SupabaseSyncService();
    imageSync = SupabaseImageService();
  } catch (_) {
    cloudSync = null;
    imageSync = null;
  }

  final storage = await LocalStorageService.create();
  final store = AppStore.forApp(
    storage: storage,
    cloudSync: cloudSync,
    imageSync: imageSync,
  );
  await store.initialize();
  runApp(SariScanApp(store: store));
}