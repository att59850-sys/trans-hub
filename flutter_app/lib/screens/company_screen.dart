import 'package:flutter/material.dart';
import '../core/maps/maps_service.dart';
import '../services/data_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

final _ds = DataService.instance;

class CompanyScreen extends StatelessWidget {
  final String companyId;
  const CompanyScreen({required this.companyId, super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ds,
      builder: (context, _) {
        final c = _ds.company(companyId);
        if (c == null) {
          return const Scaffold(
              body: EmptyState(Icons.error, 'Company not found',
                  'It may have been removed.'));
        }
        final r = _ds.ratingFor(c.id);
        final cat = categoryById(c.category);
        final reviews = _ds.reviewsFor(c.id);
        final fav = _ds.isFav(c.id);
        final grad = CategoryArt.gradient(c.category);
        final services = c.services.where((s) => s.active).toList();

        return Scaffold(
          body: CustomScrollView(slivers: [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: grad.first,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: Icon(fav ? Icons.favorite : Icons.favorite_border),
                  onPressed: () {
                    final on = _ds.toggleFav(c.id);
                    showToast(context,
                        on ? 'Saved to favorites' : 'Removed from favorites');
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: grad,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight)),
                  child: Center(
                      child: Icon(AppIcons.of(cat.icon),
                          color: Colors.white24, size: 90)),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(cat.name.toUpperCase(),
                            style: const TextStyle(
                                color: AppColors.orange,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: .4)),
                        if (c.verified) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.verified,
                              color: AppColors.ok, size: 16),
                          const Text(' Verified',
                              style: TextStyle(
                                  color: AppColors.ok,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ]
                      ]),
                      const SizedBox(height: 4),
                      Text(c.name,
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(c.tagline,
                          style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        RatingBadge(r.avg, r.count),
                        MetaTag(Icons.location_on, c.city),
                        MetaTag(
                            Icons.local_shipping, '${c.fleetSize}+ vehicles'),
                        MetaTag(Icons.history, '${c.yearsActive} yrs'),
                        ...c.coverage.map((cv) => MetaTag(Icons.public, cv)),
                      ]),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => openBookingSheet(context, c, null),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.orange),
                            icon: const Icon(Icons.request_quote),
                            label: const Text('Request a quote'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () => showToast(context,
                              'Demo: this would open chat/phone for ${c.name}'),
                          icon: const Icon(Icons.call),
                          label: const Text('Contact'),
                        ),
                      ]),
                      const SectionHead('Services & pricing'),
                      if (services.isEmpty)
                        const EmptyState(Icons.inventory,
                            'No services listed yet', 'Check back soon.')
                      else
                        ...services.map((s) => _serviceRow(context, c, s)),
                      const SectionHead('About'),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.line),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(c.description,
                            style: const TextStyle(
                                color: AppColors.ink2, height: 1.5)),
                      ),
                      SectionHead('Reviews (${reviews.length})',
                          trailing: TextButton.icon(
                            onPressed: () => _writeReview(context, c),
                            icon: const Icon(Icons.rate_review, size: 18),
                            label: const Text('Write'),
                          )),
                      if (reviews.isEmpty)
                        const Text(
                            'No reviews yet — be the first after booking.',
                            style: TextStyle(color: AppColors.muted))
                      else
                        ...reviews.map((rv) => _reviewTile(rv)),
                      const SizedBox(height: 20),
                    ]),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _serviceRow(BuildContext context, Company c, TransportService s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
              color: AppColors.blue50, borderRadius: BorderRadius.circular(12)),
          child: Icon(AppIcons.of(s.icon), color: AppColors.blue),
        ),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(s.desc,
              style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(s.priceLabel,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          ElevatedButton(
            onPressed: () => openBookingSheet(context, c, s),
            style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
            child: const Text('Book', style: TextStyle(fontSize: 13)),
          ),
        ]),
      ]),
    );
  }

  Widget _reviewTile(Review rv) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.blue50,
              child: Text(_initials(rv.name),
                  style: const TextStyle(
                      color: AppColors.blue,
                      fontWeight: FontWeight.w700,
                      fontSize: 13))),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rv.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            StarsRow(rv.rating, size: 15),
          ]),
        ]),
        const SizedBox(height: 6),
        Text(rv.text, style: const TextStyle(color: AppColors.ink2)),
        const Divider(height: 24),
      ]),
    );
  }

  String _initials(String n) {
    final parts = n.trim().split(RegExp(r'\s+'));
    return parts
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join()
        .toUpperCase();
  }

  void _writeReview(BuildContext context, Company c) {
    int rating = 5;
    final nameCtrl = TextEditingController(text: _ds.currentUser?.name ?? '');
    final textCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Review ${c.name}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    5,
                    (i) => IconButton(
                          iconSize: 34,
                          icon: Icon(Icons.star,
                              color: i < rating
                                  ? AppColors.orange
                                  : AppColors.line),
                          onPressed: () => setSt(() => rating = i + 1),
                        ))),
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Your name')),
            const SizedBox(height: 12),
            TextField(
                controller: textCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Review', hintText: 'How was your experience?')),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (textCtrl.text.trim().isEmpty) return;
                  _ds.addReview(Review(
                    companyId: c.id,
                    userId: _ds.currentUser?.id,
                    name: nameCtrl.text.trim().isEmpty
                        ? 'Anonymous'
                        : nameCtrl.text.trim(),
                    rating: rating,
                    text: textCtrl.text.trim(),
                  ));
                  Navigator.pop(ctx);
                  showToast(context, 'Thanks for your review!');
                },
                icon: const Icon(Icons.rate_review),
                label: const Text('Post review'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Booking / quote bottom sheet — shared from cards and service rows.
void openBookingSheet(
    BuildContext context, Company c, TransportService? service) {
  final u = _ds.currentUser;
  String? serviceId = service?.id;
  final pickup = TextEditingController(text: _ds.location);
  final dropoff = TextEditingController();
  final date = TextEditingController();
  final name = TextEditingController(text: u?.name ?? '');
  final email = TextEditingController(text: u?.email ?? '');
  final phone = TextEditingController();
  final notes = TextEditingController();
  final services = c.services.where((s) => s.active).toList();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
                service != null
                    ? 'Book: ${service.name}'
                    : 'Request a quote — ${c.name}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            DropdownButtonFormField<String?>(
              value: serviceId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Service'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('General quote request')),
                ...services.map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text('${s.name} — ${s.priceLabel}',
                        overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => setSt(() => serviceId = v),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: pickup,
                      onChanged: (_) => setSt(() {}),
                      decoration: const InputDecoration(labelText: 'Pickup'))),
              const SizedBox(width: 10),
              Expanded(
                  child: TextField(
                      controller: dropoff,
                      onChanged: (_) => setSt(() {}),
                      decoration:
                          const InputDecoration(labelText: 'Drop-off'))),
            ]),
            _RoutePreviewStrip(pickup: pickup.text, dropoff: dropoff.text),
            const SizedBox(height: 12),
            TextField(
              controller: date,
              readOnly: true,
              decoration: const InputDecoration(
                  labelText: 'Preferred date',
                  suffixIcon: Icon(Icons.calendar_today, size: 18)),
              onTap: () async {
                final d = await showDatePicker(
                    context: ctx,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDate: DateTime.now());
                if (d != null) {
                  date.text = d.toIso8601String().substring(0, 10);
                }
              },
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: name,
                      decoration:
                          const InputDecoration(labelText: 'Your name'))),
              const SizedBox(width: 10),
              Expanded(
                  child: TextField(
                      controller: email,
                      decoration: const InputDecoration(labelText: 'Email'))),
            ]),
            const SizedBox(height: 12),
            TextField(
                controller: phone,
                decoration:
                    const InputDecoration(labelText: 'Phone (optional)')),
            const SizedBox(height: 12),
            TextField(
                controller: notes,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Details',
                    hintText: 'Cargo, weight, special requirements…')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
                onPressed: () {
                  if (name.text.trim().isEmpty || email.text.trim().isEmpty) {
                    showToast(ctx, 'Please enter your name and email',
                        error: true);
                    return;
                  }
                  _ds.createBooking(Booking(
                    companyId: c.id,
                    serviceId: serviceId,
                    userId: u?.id,
                    contactName: name.text.trim(),
                    contactEmail: email.text.trim(),
                    phone: phone.text.trim(),
                    pickup: pickup.text.trim(),
                    dropoff: dropoff.text.trim(),
                    date: date.text,
                    notes: notes.text.trim(),
                  ));
                  Navigator.pop(ctx);
                  showToast(
                      context,
                      service != null
                          ? 'Booking request sent to ${c.name}'
                          : 'Quote request sent!');
                },
                icon: const Icon(Icons.send),
                label: Text(service != null
                    ? 'Confirm booking request'
                    : 'Send quote request'),
              ),
            ),
          ]),
        ),
      ),
    ),
  );
}

/// Live route estimate shown in the booking sheet between the pickup and
/// drop-off fields (TH-019). Renders nothing until both are filled; shows a
/// distance + estimated duration once resolvable.
class _RoutePreviewStrip extends StatefulWidget {
  const _RoutePreviewStrip({required this.pickup, required this.dropoff});
  final String pickup;
  final String dropoff;

  @override
  State<_RoutePreviewStrip> createState() => _RoutePreviewStripState();
}

class _RoutePreviewStripState extends State<_RoutePreviewStrip> {
  Future<RoutePreview?>? _future;

  @override
  void didUpdateWidget(covariant _RoutePreviewStrip old) {
    super.didUpdateWidget(old);
    if (old.pickup != widget.pickup || old.dropoff != widget.dropoff) {
      _refresh();
    }
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _future = _ds.estimateRoute(widget.pickup, widget.dropoff);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pickup.trim().isEmpty || widget.dropoff.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<RoutePreview?>(
      future: _future,
      builder: (context, snap) {
        final r = snap.data;
        if (r == null) return const SizedBox.shrink();
        final h = r.durationMinutes ~/ 60;
        final m = r.durationMinutes % 60;
        final eta = h > 0 ? '${h}h ${m}m' : '${m}m';
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.blue50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.route, size: 18, color: AppColors.blue),
              const SizedBox(width: 8),
              Text('~${r.distanceKm} km',
                  style: const TextStyle(
                      color: AppColors.blue, fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              const Icon(Icons.schedule, size: 16, color: AppColors.blue),
              const SizedBox(width: 4),
              Text('~$eta',
                  style: const TextStyle(
                      color: AppColors.blue, fontWeight: FontWeight.w700)),
              const Spacer(),
              const Text('estimate',
                  style: TextStyle(color: AppColors.muted, fontSize: 11.5)),
            ]),
          ),
        );
      },
    );
  }
}
