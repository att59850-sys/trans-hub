import 'package:flutter/material.dart';
import '../core/utils/search_matcher.dart';
import '../services/data_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'shell.dart';

final _ds = DataService.instance;

class BrowseScreen extends StatefulWidget {
  final String? initialCategory;
  const BrowseScreen({this.initialCategory, super.key});
  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  String? _cat;
  bool _verifiedOnly = false;
  String _sort = 'rating';
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cat = widget.initialCategory;
  }

  @override
  void didUpdateWidget(BrowseScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialCategory != old.initialCategory) {
      _cat = widget.initialCategory;
    }
  }

  @override
  Widget build(BuildContext context) {
    var list = _ds.companies.where((c) {
      if (_cat != null && c.category != _cat) return false;
      if (_verifiedOnly && !c.verified) return false;
      // Trim + case-fold the query so a stray leading/trailing space (common
      // from mobile keyboards) can't hide a real match, and a whitespace-only
      // query behaves like an empty one (QA round 10).
      if (!SearchMatcher.matches(c.searchHaystack, _query)) return false;
      return true;
    }).toList();

    int Function(Company, Company) sorter;
    switch (_sort) {
      case 'reviews':
        sorter = (a, b) =>
            _ds.ratingFor(b.id).count.compareTo(_ds.ratingFor(a.id).count);
        break;
      case 'fleet':
        sorter = (a, b) => b.fleetSize.compareTo(a.fleetSize);
        break;
      case 'name':
        // Case-insensitive so a lowercase initial doesn't sort after an
        // uppercase one (QA round 10).
        sorter = (a, b) => SearchMatcher.compareNames(a.name, b.name);
        break;
      default:
        sorter = (a, b) =>
            _ds.ratingFor(b.id).avg.compareTo(_ds.ratingFor(a.id).avg);
    }
    list.sort(sorter);

    return Scaffold(
      appBar: const BrandAppBar(title: 'Browse providers'),
      body: Column(children: [
        // search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            // Log on submit rather than per keystroke to avoid noise (TH-024).
            onSubmitted: (v) {
              if (v.trim().isNotEmpty)
                _ds.trackSearch(v.trim(), category: _cat);
            },
            decoration: InputDecoration(
              hintText: 'Search companies, services, routes…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      }),
            ),
          ),
        ),
        // category chips
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _filterChip(
                  'All', _cat == null, () => setState(() => _cat = null)),
              ...kCategories.map((c) => _filterChip(
                  c.name, _cat == c.id, () => setState(() => _cat = c.id),
                  isNew: c.isNew)),
            ],
          ),
        ),
        // sort + verified row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Row(children: [
            Expanded(
                child: Text(
                    '${list.length} provider${list.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            FilterChip(
              label: const Text('Verified'),
              selected: _verifiedOnly,
              showCheckmark: true,
              selectedColor: AppColors.blue50,
              onSelected: (v) => setState(() => _verifiedOnly = v),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _sort,
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(12),
              items: const [
                DropdownMenuItem(value: 'rating', child: Text('Top rated')),
                DropdownMenuItem(
                    value: 'reviews', child: Text('Most reviewed')),
                DropdownMenuItem(value: 'fleet', child: Text('Largest fleet')),
                DropdownMenuItem(value: 'name', child: Text('Name A-Z')),
              ],
              onChanged: (v) => setState(() => _sort = v!),
            ),
          ]),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(Icons.search_off, 'No providers found',
                  'Try a different service type or clear your filters.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (_, i) => CompanyCard(list[i]),
                ),
        ),
      ]),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap,
      {bool isNew = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label),
          if (isNew) ...[const SizedBox(width: 6), const NewPill()],
        ]),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.blue,
        labelStyle: TextStyle(
            color: selected ? Colors.white : AppColors.ink2,
            fontWeight: FontWeight.w600),
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? AppColors.blue : AppColors.line),
        onSelected: (_) => onTap(),
      ),
    );
  }
}
