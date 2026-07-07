import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'shell.dart';
import 'account_screen.dart';
import 'notifications_screen.dart';

final _ds = DataService.instance;

class HomeScreen extends StatelessWidget {
  final void Function(String? category) onBrowse;
  const HomeScreen({required this.onBrowse, super.key});

  @override
  Widget build(BuildContext context) {
    final companies = _ds.companies;
    final featured = [...companies]..sort(
        (a, b) => _ds.ratingFor(b.id).avg.compareTo(_ds.ratingFor(a.id).avg));
    final top = featured.take(6).toList();
    final newCats = kCategories.where((c) => c.isNew).toList();

    return Scaffold(
      appBar: BrandAppBar(actions: [
        TextButton.icon(
          onPressed: () => _showLocationSheet(context),
          icon:
              const Icon(Icons.location_on, color: AppColors.orange, size: 20),
          label: Text(_ds.location.isEmpty ? 'Set location' : _ds.location,
              style: const TextStyle(
                  color: AppColors.ink2, fontWeight: FontWeight.w600)),
        ),
        if (_ds.currentUser != null) const NotificationBell(),
        const SizedBox(width: 6),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _hero(context),
          SectionHead('Browse by service',
              trailing: TextButton(
                  onPressed: () => onBrowse(null),
                  child: const Text('View all'))),
          _categoryChips(context),
          if (newCats.isNotEmpty) ...[
            const SectionHead('✨ Newly added services'),
            ...newCats.map((c) => _newServiceTile(context, c)),
          ],
          SectionHead('Top-rated providers',
              trailing: TextButton(
                  onPressed: () => onBrowse(null),
                  child: const Text('See more'))),
          ...top.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: CompanyCard(c))),
          const SizedBox(height: 8),
          _providerCta(context),
          const SectionHead('Why TransportHub'),
          _whyGrid(),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.blue700, AppColors.blue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Move anything, anywhere — with transport you can trust.',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -.5)),
        const SizedBox(height: 10),
        const Text(
            'Compare vetted freight, moving, courier, cold-chain, heavy-haul and more. Get instant quotes and book in minutes.',
            style: TextStyle(color: Colors.white, fontSize: 14.5, height: 1.4)),
        const SizedBox(height: 18),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onBrowse(null),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(children: [
                Icon(Icons.search, color: AppColors.blue),
                SizedBox(width: 10),
                Expanded(
                    child: Text('Search companies, services, routes…',
                        style: TextStyle(color: AppColors.muted))),
                Icon(Icons.arrow_forward, color: AppColors.orange),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Wrap(spacing: 24, runSpacing: 12, children: [
          _stat('${_ds.companies.length}', 'Verified providers'),
          _stat('${kCategories.length}', 'Service categories'),
          _stat('24/7', 'Booking & support'),
          _stat('100%', 'Transparent pricing'),
        ]),
      ]),
    );
  }

  Widget _stat(String big, String small) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(big,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800)),
        Text(small,
            style: TextStyle(
                color: Colors.white.withOpacity(.85), fontSize: 12.5)),
      ]);

  Widget _categoryChips(BuildContext context) {
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = kCategories[i];
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onBrowse(c.id),
            child: Container(
              width: 104,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                        radius: 23,
                        backgroundColor: AppColors.blue50,
                        child: Icon(AppIcons.of(c.icon),
                            color: AppColors.blue, size: 24)),
                    const SizedBox(height: 8),
                    Text(c.name,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink2)),
                  ]),
            ),
          );
        },
      ),
    );
  }

  Widget _newServiceTile(BuildContext context, ServiceCategory c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onBrowse(c.id),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: AppColors.blue50,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(AppIcons.of(c.icon), color: AppColors.blue),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Flexible(
                        child: Text(c.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15))),
                    const SizedBox(width: 8),
                    const NewPill(),
                  ]),
                  const SizedBox(height: 2),
                  Text(c.blurb,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 13)),
                ])),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ]),
        ),
      ),
    );
  }

  Widget _providerCta(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(colors: [AppColors.ink, Color(0xFF1C3A5E)]),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Run a transport business?',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
            'List your services free, reach new customers and manage bookings from one dashboard.',
            style: TextStyle(color: Colors.white.withOpacity(.85))),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AuthScreen(startAsCompany: true))),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
          icon: const Icon(Icons.add_business),
          label: const Text('List your business'),
        ),
      ]),
    );
  }

  Widget _whyGrid() {
    final items = [
      [
        Icons.verified_user,
        'Vetted & verified',
        'Every provider is reviewed before going live.'
      ],
      [
        Icons.payments,
        'Transparent pricing',
        'See rates up front or request a fast quote.'
      ],
      [
        Icons.reviews,
        'Real reviews',
        'Ratings from real bookings help you choose.'
      ],
      [
        Icons.support_agent,
        'Always supported',
        'Booking help whenever you need it.'
      ],
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.25,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: items
          .map((f) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: AppColors.blue50,
                            borderRadius: BorderRadius.circular(12)),
                        child: Icon(f[0] as IconData, color: AppColors.blue),
                      ),
                      const SizedBox(height: 10),
                      Text(f[1] as String,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(f[2] as String,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 12.5)),
                    ]),
              ))
          .toList(),
    );
  }
}

void _showLocationSheet(BuildContext context) {
  final ctrl = TextEditingController(text: _ds.location);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Set your location',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
                labelText: 'City or area', hintText: 'e.g. Chicago, IL')),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              _ds.setLocation(ctrl.text.trim());
              Navigator.pop(ctx);
              showToast(
                  context,
                  ctrl.text.trim().isEmpty
                      ? 'Location cleared'
                      : 'Location set to ${ctrl.text.trim()}');
            },
            icon: const Icon(Icons.check),
            label: const Text('Save location'),
          ),
        ),
      ]),
    ),
  );
}
