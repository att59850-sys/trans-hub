import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/shell.dart';
import 'services/data_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initializes Hive, registers the DI graph (repositories + use cases),
  // and seeds first-run data.
  await DataService.instance.init();
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
