import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/di/injection.dart';
import 'core/network/connectivity_service.dart';
import 'data/datasources/remote/sync_engine.dart';
import 'screens/shell.dart';
import 'services/data_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initializes Hive, registers the DI graph (repositories + use cases),
  // and seeds first-run data.
  await DataService.instance.init();

  // Start connectivity monitoring and run an initial sync cycle (TH-014/015).
  // Both are no-ops until a Supabase backend is configured.
  await sl<ConnectivityService>().start();
  unawaited(sl<SyncEngine>().sync());

  // Record the app-open event (TH-024); binds the current user if a session
  // was restored during init.
  DataService.instance.trackAppOpened();

  // ProviderScope activates Riverpod for the new presentation layer (TH-005).
  runApp(const ProviderScope(child: TransportHubApp()));
}

class TransportHubApp extends StatelessWidget {
  const TransportHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: DataService.instance,
      builder: (context, _) => MaterialApp(
        title: 'Trans-Hub',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const AppShell(),
      ),
    );
  }
}
