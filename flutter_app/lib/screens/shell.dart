import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'browse_screen.dart';
import 'bookings_screen.dart';
import 'dashboard_screen.dart';
import 'account_screen.dart';

final _ds = DataService.instance;

/// Bottom-navigation shell. Tabs adapt to the signed-in role:
/// - guest/customer: Home · Browse · Bookings · Account
/// - company:        Home · Browse · Dashboard · Account
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final user = _ds.currentUser;
    final isCompany = user?.role == UserRole.company;

    final pages = <Widget>[
      HomeScreen(
          onBrowse: (cat) => setState(() {
                _index = 1;
                _browseCat = cat;
              })),
      BrowseScreen(initialCategory: _browseCat),
      isCompany ? const DashboardScreen() : const BookingsScreen(),
      const AccountScreen(),
    ];

    return Scaffold(
      body: SafeArea(bottom: false, child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          if (i != 1) _browseCat = null;
          _index = i;
        }),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.blue50,
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppColors.blue),
              label: 'Home'),
          const NavigationDestination(
              icon: Icon(Icons.search),
              selectedIcon: Icon(Icons.search, color: AppColors.blue),
              label: 'Browse'),
          NavigationDestination(
              icon: Icon(isCompany
                  ? Icons.dashboard_outlined
                  : Icons.event_note_outlined),
              selectedIcon: Icon(isCompany ? Icons.dashboard : Icons.event_note,
                  color: AppColors.blue),
              label: isCompany ? 'Dashboard' : 'Bookings'),
          const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppColors.blue),
              label: 'Account'),
        ],
      ),
    );
  }

  String? _browseCat;
}

/// Shared brand app bar used across screens.
class BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<Widget>? actions;
  final bool showLocation;
  const BrandAppBar(
      {this.title, this.actions, this.showLocation = false, super.key});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 16,
      title: title != null
          ? Text(title!, style: const TextStyle(fontWeight: FontWeight.w800))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.local_shipping, color: AppColors.blue, size: 26),
              const SizedBox(width: 8),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      letterSpacing: -.4),
                  children: [
                    TextSpan(text: 'Transport'),
                    TextSpan(
                        text: 'Hub', style: TextStyle(color: AppColors.orange)),
                  ],
                ),
              ),
            ]),
      actions: actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.line),
      ),
    );
  }
}
