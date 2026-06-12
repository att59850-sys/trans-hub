import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'shell.dart';
import 'company_screen.dart';
import 'account_screen.dart';

final _ds = DataService.instance;

class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final u = _ds.currentUser;
    if (u == null) {
      return Scaffold(
        appBar: const BrandAppBar(title: 'My bookings'),
        body: EmptyState(
          Icons.lock_outline,
          'Log in to see your bookings',
          'Sign in or create a free account to book and track services.',
          action: ElevatedButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AuthScreen())),
            icon: const Icon(Icons.login),
            label: const Text('Log in / Sign up'),
          ),
        ),
      );
    }

    final bookings = _ds.bookingsForUser(u.id);
    return Scaffold(
      appBar: const BrandAppBar(title: 'My bookings'),
      body: bookings.isEmpty
          ? const EmptyState(Icons.event_busy, 'No bookings yet',
              'Browse providers and book your first service.')
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final b = bookings[i];
                final c = _ds.company(b.companyId);
                final s = c?.serviceById(b.serviceId);
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: InkWell(
                              onTap: c == null
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => CompanyScreen(
                                              companyId: c.id))),
                              child: Text(c?.name ?? '—',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: AppColors.blue)),
                            ),
                          ),
                          StatusBadge(b.status),
                        ]),
                        const SizedBox(height: 6),
                        Text(s?.name ?? 'Quote request',
                            style: const TextStyle(color: AppColors.ink2)),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.route,
                              size: 16, color: AppColors.muted),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(
                                  '${b.pickup.isEmpty ? '—' : b.pickup} → ${b.dropoff.isEmpty ? '—' : b.dropoff}',
                                  style: const TextStyle(
                                      color: AppColors.muted, fontSize: 13))),
                          if (b.date.isNotEmpty) ...[
                            const Icon(Icons.calendar_today,
                                size: 14, color: AppColors.muted),
                            const SizedBox(width: 4),
                            Text(b.date,
                                style: const TextStyle(
                                    color: AppColors.muted, fontSize: 13)),
                          ]
                        ]),
                      ]),
                );
              },
            ),
    );
  }
}
