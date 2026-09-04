import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/services/local_storage_service.dart';
import 'src/store/app_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await LocalStorageService.create();
  final store = AppStore.forApp(storage: storage);
  await store.initialize();
  runApp(SariScanApp(store: store));
}
