import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'company_screen.dart';
import 'shell.dart';

final _ds = DataService.instance;

/// Admin verification review queue (TH-017).
///
/// Lists companies that have submitted for verification and lets an
/// administrator move them through the workflow:
/// submitted → under_review → approved / rejected. Access is gated by
/// [DataService.isAdmin] (config-driven admin emails).
class AdminReviewScreen extends StatelessWidget {
  const AdminReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ds,
      builder: (context, _) {
        if (!_ds.isAdmin) {
          return const Scaffold(
            appBar: BrandAppBar(title: 'Verification queue'),
            body: EmptyState(Icons.lock, 'Admins only',
                'You do not have access to the verification queue.'),
          );
        }
        final queue = _ds.companiesForReview;
        return Scaffold(
          appBar: BrandAppBar(title: 'Verification queue'),
          body: queue.isEmpty
              ? const EmptyState(Icons.verified_user, 'Queue is empty',
                  'No providers are awaiting verification right now.')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: queue.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _ReviewCard(queue[i]),
                ),
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard(this.c);
  final Company c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(c.name,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          StatusBadge(_ds.verificationLabel(c.verificationStatus)),
        ]),
        const SizedBox(height: 4),
        Text(
            '${c.city} · ${c.fleetSize} vehicles · ${c.yearsActive} yrs active',
            style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        if (c.tagline.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(c.tagline, style: const TextStyle(color: AppColors.ink2)),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => CompanyScreen(companyId: c.id)),
            ),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('View'),
          ),
          if (c.verificationStatus == 'submitted')
            FilledButton.tonalIcon(
              onPressed: () {
                // Honour the state-machine result so a stale card / double-tap
                // can't show a success toast for a transition that was a no-op
                // (QA round 15).
                final ok = _ds.setVerificationStatus(c.id, 'under_review');
                showToast(
                  context,
                  ok
                      ? '${c.name} moved to review'
                      : '${c.name} was already updated',
                  error: !ok,
                );
              },
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Start review'),
            ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.ok),
            onPressed: () {
              final ok = _ds.setVerificationStatus(c.id, 'approved');
              showToast(
                context,
                ok ? '${c.name} approved' : '${c.name} was already updated',
                error: !ok,
              );
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Approve'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              final ok = _ds.setVerificationStatus(c.id, 'rejected');
              showToast(
                context,
                ok ? '${c.name} rejected' : '${c.name} was already updated',
                error: true,
              );
            },
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Reject'),
          ),
        ]),
      ]),
    );
  }
}
