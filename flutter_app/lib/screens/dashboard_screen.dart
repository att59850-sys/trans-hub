import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'shell.dart';
import 'company_screen.dart';

final _ds = DataService.instance;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final c = _ds.myCompany;
    if (c == null) {
      return const Scaffold(
          appBar: BrandAppBar(title: 'Dashboard'),
          body: EmptyState(Icons.lock, 'Provider area',
              'This dashboard is for transport providers.'));
    }
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title:
            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'View public page',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CompanyScreen(companyId: c.id))),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          labelColor: AppColors.blue,
          indicatorColor: AppColors.blue,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Services'),
            Tab(text: 'Bookings'),
            Tab(text: 'Profile'),
          ],
        ),
      ),
      body: TabBarView(controller: _tab, children: [
        _overview(c),
        _services(context, c),
        _bookings(context, c),
        ProfileEditor(company: c),
      ]),
    );
  }

  Widget _overview(Company c) {
    final bookings = _ds.bookingsForCompany(c.id);
    final pending = bookings.where((b) => b.status == 'pending').length;
    final r = _ds.ratingFor(c.id);
    final kpis = [
      [Icons.event_note, '${bookings.length}', 'Total bookings'],
      [Icons.pending_actions, '$pending', 'Pending'],
      [Icons.inventory_2, '${c.services.length}', 'Services'],
      [Icons.star, r.avg > 0 ? '${r.avg}' : '—', '${r.count} reviews'],
    ];
    return ListView(padding: const EdgeInsets.all(16), children: [
      _verificationPanel(c),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: kpis
            .map((k) => Container(
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
                        Icon(k[0] as IconData, color: AppColors.blue),
                        const SizedBox(height: 6),
                        Text(k[1] as String,
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w800)),
                        Text(k[2] as String,
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12.5)),
                      ]),
                ))
            .toList(),
      ),
      const SectionHead('Recent bookings'),
      if (bookings.isEmpty)
        const EmptyState(Icons.event_busy, 'No bookings yet',
            'New requests will appear here.')
      else
        ...bookings.take(5).map((b) => _bookingTile(context, c, b, false)),
    ]);
  }

  /// Provider verification status + action (TH-017).
  Widget _verificationPanel(Company c) {
    final status = c.verificationStatus;
    final approved = status == 'approved';
    final pending = status == 'submitted' || status == 'under_review';
    final (Color bg, Color fg, IconData icon) = approved
        ? (const Color(0xFFE3F7EE), AppColors.ok, Icons.verified)
        : pending
            ? (const Color(0xFFFFF4E0), AppColors.warn, Icons.hourglass_top)
            : (AppColors.blue50, AppColors.blue, Icons.shield_outlined);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Icon(icon, color: fg),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_ds.verificationLabel(status),
                  style: TextStyle(
                      color: fg, fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text(
                approved
                    ? 'Your company is verified and shows a badge to customers.'
                    : pending
                        ? 'Your verification request is being reviewed.'
                        : 'Get a verified badge to build customer trust.',
                style: const TextStyle(color: AppColors.ink2, fontSize: 12.5),
              ),
            ],
          ),
        ),
        if (!approved && !pending)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.blue),
            onPressed: () {
              _ds.submitForVerification(c.id);
              showToast(context, 'Submitted for verification');
            },
            child: const Text('Submit'),
          ),
      ]),
    );
  }

  Widget _services(BuildContext context, Company c) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editService(context, c, null),
        backgroundColor: AppColors.orange,
        icon: const Icon(Icons.add),
        label: const Text('Add service'),
      ),
      body: c.services.isEmpty
          ? const EmptyState(Icons.inventory, 'No services yet',
              'Add your first service so customers can book.')
          : ListView(padding: const EdgeInsets.all(16), children: [
              ...c.services.map((s) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: AppColors.blue50,
                            borderRadius: BorderRadius.circular(12)),
                        child: Icon(AppIcons.of(s.icon), color: AppColors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Row(children: [
                              Flexible(
                                  child: Text(s.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700))),
                              if (!s.active) ...[
                                const SizedBox(width: 6),
                                const StatusBadge('cancelled'),
                              ]
                            ]),
                            Text(s.priceLabel,
                                style: const TextStyle(
                                    color: AppColors.muted, fontSize: 13)),
                          ])),
                      IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _editService(context, c, s)),
                      IconButton(
                          icon: const Icon(Icons.delete,
                              size: 20, color: AppColors.danger),
                          onPressed: () {
                            _ds.removeService(c.id, s.id);
                            showToast(context, 'Service removed');
                          }),
                    ]),
                  )),
              const SizedBox(height: 70),
            ]),
    );
  }

  Widget _bookings(BuildContext context, Company c) {
    final bookings = _ds.bookingsForCompany(c.id);
    if (bookings.isEmpty) {
      return const EmptyState(Icons.event_busy, 'No bookings yet',
          'New requests will appear here.');
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      ...bookings.map((b) => _bookingTile(context, c, b, true)),
    ]);
  }

  Widget _bookingTile(
      BuildContext context, Company c, Booking b, bool withActions) {
    final s = c.serviceById(b.serviceId);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(b.contactName.isEmpty ? '—' : b.contactName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15))),
          StatusBadge(_ds.statusLabel(b.status)),
        ]),
        Text(b.contactEmail,
            style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
        const SizedBox(height: 6),
        Text(s?.name ?? 'Quote request',
            style: const TextStyle(color: AppColors.ink2)),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.route, size: 15, color: AppColors.muted),
          const SizedBox(width: 5),
          Expanded(
              child: Text(
                  '${b.pickup.isEmpty ? '—' : b.pickup} → ${b.dropoff.isEmpty ? '—' : b.dropoff}',
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 13))),
          if (b.date.isNotEmpty)
            Text(b.date,
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ]),
        if (b.notes.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(b.notes,
              style: const TextStyle(
                  color: AppColors.ink2,
                  fontSize: 13,
                  fontStyle: FontStyle.italic)),
        ],
        if (withActions) ...[
          const SizedBox(height: 10),
          if (_ds.isTerminalStatus(b.status))
            Text('This booking is ${_ds.statusLabel(b.status).toLowerCase()}.',
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5))
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              const Padding(
                padding: EdgeInsets.only(top: 6, right: 2),
                child: Text('Move to:',
                    style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              for (final next in _ds.nextStatuses(b.status))
                ActionChip(
                  label: Text(_ds.statusLabel(next),
                      style: const TextStyle(fontSize: 12)),
                  backgroundColor: AppColors.blue50,
                  onPressed: () {
                    _ds.setBookingStatus(b.id, next);
                    showToast(context, 'Booking → ${_ds.statusLabel(next)}');
                  },
                ),
            ]),
        ],
      ]),
    );
  }

  void _editService(BuildContext context, Company c, TransportService? svc) {
    final editing = svc != null;
    final name = TextEditingController(text: svc?.name ?? '');
    final desc = TextEditingController(text: svc?.desc ?? '');
    final price = TextEditingController(
        text: svc != null && svc.price > 0 ? svc.price.toString() : '');
    String unit = svc?.unit ?? 'flat';
    String icon = svc?.icon ?? 'local_shipping';
    bool active = svc?.active ?? true;
    const units = [
      'flat',
      'per mile',
      'per kg',
      'per pallet',
      'per hour',
      'per day',
      'per trip',
      'per vehicle',
      'monthly',
      'add-on',
      'quote'
    ];
    const icons = [
      'local_shipping',
      'inventory_2',
      'directions_bus',
      'local_taxi',
      'ac_unit',
      'precision_manufacturing',
      'electric_bolt',
      'send',
      'directions_boat',
      'bolt',
      'schedule',
      'home',
      'flight',
      'my_location',
      'medical_services',
      'eco'
    ];

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
              Text(editing ? 'Edit service' : 'Add a service',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Service name')),
              const SizedBox(height: 12),
              TextField(
                  controller: desc,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: unit,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Pricing'),
                    items: units
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => setSt(() => unit = v!),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                      controller: price,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Price', hintText: '0 = quote')),
                ),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: icon,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Icon'),
                items: icons
                    .map((i) => DropdownMenuItem(
                        value: i,
                        child: Row(children: [
                          Icon(AppIcons.of(i), size: 18, color: AppColors.blue),
                          const SizedBox(width: 8),
                          Text(i),
                        ])))
                    .toList(),
                onChanged: (v) => setSt(() => icon = v!),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Visible to customers'),
                value: active,
                activeColor: AppColors.blue,
                onChanged: (v) => setSt(() => active = v),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (name.text.trim().isEmpty) return;
                    final s = TransportService(
                      id: svc?.id,
                      name: name.text.trim(),
                      desc: desc.text.trim(),
                      unit: unit,
                      price: double.tryParse(price.text) ?? 0,
                      icon: icon,
                      active: active,
                    );
                    if (editing) {
                      _ds.updateService(c.id, s);
                    } else {
                      _ds.addService(c.id, s);
                    }
                    Navigator.pop(ctx);
                    showToast(
                        context, editing ? 'Service updated' : 'Service added');
                  },
                  icon: const Icon(Icons.save),
                  label: Text(editing ? 'Save service' : 'Add service'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Profile editor tab.
class ProfileEditor extends StatefulWidget {
  final Company company;
  const ProfileEditor({required this.company, super.key});
  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  late TextEditingController _name,
      _tagline,
      _city,
      _fleet,
      _years,
      _coverage,
      _desc;
  late String _category;

  @override
  void initState() {
    super.initState();
    final c = widget.company;
    _name = TextEditingController(text: c.name);
    _tagline = TextEditingController(text: c.tagline);
    _city = TextEditingController(text: c.city);
    _fleet = TextEditingController(text: c.fleetSize.toString());
    _years = TextEditingController(text: c.yearsActive.toString());
    _coverage = TextEditingController(text: c.coverage.join(', '));
    _desc = TextEditingController(text: c.description);
    _category = c.category;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Business name')),
      const SizedBox(height: 12),
      TextField(
          controller: _tagline,
          decoration: const InputDecoration(labelText: 'Tagline')),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _category,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Service category'),
        items: kCategories
            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
            .toList(),
        onChanged: (v) => setState(() => _category = v!),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: TextField(
                controller: _city,
                decoration: const InputDecoration(labelText: 'City / base'))),
        const SizedBox(width: 10),
        Expanded(
            child: TextField(
                controller: _fleet,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Fleet size'))),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: TextField(
                controller: _years,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Years active'))),
        const SizedBox(width: 10),
        Expanded(
            child: TextField(
                controller: _coverage,
                decoration:
                    const InputDecoration(labelText: 'Coverage (comma sep.)'))),
      ]),
      const SizedBox(height: 12),
      TextField(
          controller: _desc,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'About your business')),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            final c = widget.company
              ..name = _name.text.trim()
              ..tagline = _tagline.text.trim()
              ..category = _category
              ..city = _city.text.trim()
              ..fleetSize = int.tryParse(_fleet.text) ?? 1
              ..yearsActive = int.tryParse(_years.text) ?? 0
              ..coverage = _coverage.text
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList()
              ..description = _desc.text.trim();
            _ds.updateCompany(c);
            showToast(context, 'Profile saved');
          },
          icon: const Icon(Icons.save),
          label: const Text('Save changes'),
        ),
      ),
    ]);
  }
}
