import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/providers.dart';
import 'data/repositories/firestore_config.dart';
import 'firebase_options.dart';
import 'presentation/navigation/vaultx_router.dart';
import 'presentation/theme/vaultx_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterCryptography.enable();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Explicitly bind named Firestore database (never `(default)`)
  final db = FirestoreConfig.db;
  FirestoreConfig.assertNamedDatabaseConfigured(db);

  runApp(const ProviderScope(child: VaultXApp()));
}

class VaultXApp extends ConsumerWidget {
  const VaultXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(vaultXRouterProvider);
    final themeMode = ref.watch(
      vaultSessionProvider.select((s) => s.localPreferences.themeMode),
    );

    return MaterialApp.router(
      title: 'VaultX',
      debugShowCheckedModeBanner: false,
      theme: VaultXTheme.light(),
      darkTheme: VaultXTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
