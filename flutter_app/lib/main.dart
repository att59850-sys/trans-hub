import 'package:flutter/material.dart';
import 'services/data_service.dart';
import 'theme/app_theme.dart';
import 'screens/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DataService.instance.init();
  runApp(const TransportHubApp());
}

class TransportHubApp extends StatelessWidget {
  const TransportHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: DataService.instance,
      builder: (context, _) => MaterialApp(
        title: 'TransportHub',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const AppShell(),
      ),
    );
  }
}
