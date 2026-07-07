import 'package:flutter/material.dart';

import '../domain/entities/app_notification.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'shell.dart';

final _ds = DataService.instance;

/// In-app notifications inbox (TH-018).
///
/// Lists the signed-in user's notifications newest-first, lets them mark a
/// single one (by tapping) or all read, and reflects unread state visually.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ds,
      builder: (context, _) {
        final items = _ds.notifications;
        final hasUnread = _ds.unreadNotifications > 0;
        return Scaffold(
          appBar: BrandAppBar(
            title: 'Notifications',
            actions: [
              if (hasUnread)
                TextButton(
                  onPressed: _ds.markAllNotificationsRead,
                  child: const Text('Mark all read'),
                ),
            ],
          ),
          body: items.isEmpty
              ? const EmptyState(
                  Icons.notifications_none,
                  'No notifications yet',
                  'Booking updates and quote responses will show up here.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.line),
                  itemBuilder: (context, i) => _NotificationTile(items[i]),
                ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile(this.n);
  final AppNotification n;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: n.read ? null : () => _ds.markNotificationRead(n.id),
      leading: CircleAvatar(
        backgroundColor: n.read ? AppColors.bg : AppColors.blue50,
        child: Icon(_iconFor(n.kind),
            color: n.read ? AppColors.muted : AppColors.blue, size: 20),
      ),
      title: Text(
        n.title,
        style: TextStyle(
            fontWeight: n.read ? FontWeight.w600 : FontWeight.w800,
            fontSize: 15),
      ),
      subtitle: n.body.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(n.body,
                  style: const TextStyle(color: AppColors.ink2, fontSize: 13)),
            ),
      trailing: n.read
          ? null
          : Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                  color: AppColors.orange, shape: BoxShape.circle)),
    );
  }

  IconData _iconFor(NotificationKind k) => switch (k) {
        NotificationKind.bookingUpdate => Icons.local_shipping,
        NotificationKind.quoteResponse => Icons.request_quote,
        NotificationKind.reviewReminder => Icons.star_outline,
        NotificationKind.system => Icons.info_outline,
      };
}

/// App-bar bell with an unread badge. Drop into a [BrandAppBar]'s actions.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ds,
      builder: (context, _) {
        final unread = _ds.unreadNotifications;
        return IconButton(
          tooltip: 'Notifications',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) => const NotificationsScreen()),
          ),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            backgroundColor: AppColors.orange,
            child: const Icon(Icons.notifications_none, color: AppColors.ink2),
          ),
        );
      },
    );
  }
}
