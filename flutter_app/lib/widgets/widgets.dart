import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../screens/company_screen.dart';

final _ds = DataService.instance;

void showToast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error : Icons.check_circle,
            color: error ? Colors.white : const Color(0xFF6EE7A8), size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: error ? AppColors.danger : AppColors.ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      width: 360,
    ));
}

class RatingBadge extends StatelessWidget {
  final double avg;
  final int count;
  const RatingBadge(this.avg, this.count, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7EF),
        border: Border.all(color: const Color(0xFFFFE3C7)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.star, color: AppColors.orange, size: 16),
        const SizedBox(width: 3),
        Text(avg > 0 ? '$avg' : '—',
            style:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        const SizedBox(width: 3),
        Text('($count)',
            style: const TextStyle(color: AppColors.muted, fontSize: 13)),
      ]),
    );
  }
}

class MetaTag extends StatelessWidget {
  final IconData icon;
  final String label;
  const MetaTag(this.icon, this.label, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: AppColors.muted),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink2)),
      ]),
    );
  }
}

class NewPill extends StatelessWidget {
  const NewPill({super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: AppColors.orange, borderRadius: BorderRadius.circular(999)),
        child: const Text('NEW',
            style: TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .4)),
      );
}

class CompanyCard extends StatelessWidget {
  final Company c;
  const CompanyCard(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    final r = _ds.ratingFor(c.id);
    final cat = categoryById(c.category);
    final fav = _ds.isFav(c.id);
    final prices = c.services
        .where((s) => s.price > 0 && s.unit != 'quote')
        .map((s) => s.price)
        .toList()
      ..sort();
    final minPrice = prices.isNotEmpty ? prices.first : null;
    final grad = CategoryArt.gradient(c.category);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => CompanyScreen(companyId: c.id))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
          boxShadow: const [
            BoxShadow(
                color: Color(0x14102E3E), blurRadius: 12, offset: Offset(0, 4))
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // cover
          Stack(children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: grad,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight)),
              child: Center(
                  child: Icon(AppIcons.of(cat.icon),
                      color: Colors.white24, size: 56)),
            ),
            if (c.verified)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.ok.withOpacity(.95),
                      borderRadius: BorderRadius.circular(999)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.verified, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('Verified',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.white.withOpacity(.92),
                shape: const CircleBorder(),
                child: IconButton(
                  iconSize: 20,
                  icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                      color: fav ? AppColors.orange : AppColors.muted),
                  onPressed: () {
                    final on = _ds.toggleFav(c.id);
                    showToast(context,
                        on ? 'Saved to favorites' : 'Removed from favorites');
                  },
                ),
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cat.name.toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.orange,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .4)),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                    child: Text(c.name,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700))),
                RatingBadge(r.avg, r.count),
              ]),
              const SizedBox(height: 6),
              Text(c.tagline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 13.5, color: AppColors.muted)),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                MetaTag(Icons.location_on, c.city),
                MetaTag(Icons.local_shipping, '${c.fleetSize}+ fleet'),
                if (c.coverage.isNotEmpty)
                  MetaTag(Icons.public, c.coverage.first),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style:
                          const TextStyle(fontSize: 13, color: AppColors.ink2),
                      children: [
                        TextSpan(text: minPrice != null ? 'from ' : ''),
                        TextSpan(
                          text: minPrice != null
                              ? '\$${minPrice.toStringAsFixed(minPrice == minPrice.roundToDouble() ? 0 : 2)}'
                              : 'Custom quote',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppColors.ink),
                        ),
                      ],
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => CompanyScreen(companyId: c.id))),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8)),
                  icon: const Icon(Icons.event_available, size: 18),
                  label: const Text('Book', style: TextStyle(fontSize: 13)),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class StarsRow extends StatelessWidget {
  final int rating;
  final double size;
  const StarsRow(this.rating, {this.size = 16, super.key});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
            5,
            (i) => Icon(Icons.star,
                size: size,
                color: i < rating ? AppColors.orange : AppColors.line)),
      );
}

class SectionHead extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHead(this.title, {this.trailing, super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.4))),
          if (trailing != null) trailing!,
        ]),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final Widget? action;
  const EmptyState(this.icon, this.title, this.sub, {this.action, super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 54, color: AppColors.line),
            const SizedBox(height: 10),
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(sub,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted)),
            if (action != null) ...[const SizedBox(height: 14), action!],
          ]),
        ),
      );
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    const warnBg = Color(0xFFFFF4E0);
    const okBg = Color(0xFFE3F7EE);
    const dangerBg = Color(0xFFFDECEB);
    // Keyed by a normalized form so both wire values ("in_transit") and
    // human labels ("In transit") resolve to the same colors (TH-016).
    final map = {
      'draft': [AppColors.bg, AppColors.muted],
      'quoterequested': [warnBg, AppColors.warn],
      'quotesent': [warnBg, AppColors.warn],
      'pending': [warnBg, AppColors.warn],
      'confirmed': [okBg, AppColors.ok],
      'accepted': [okBg, AppColors.ok],
      'intransit': [AppColors.blue50, AppColors.blue],
      'completed': [okBg, AppColors.ok],
      'cancelled': [dangerBg, AppColors.danger],
    };
    final key = status.toLowerCase().replaceAll(RegExp(r'[\s_]'), '');
    final c = map[key] ?? [AppColors.blue50, AppColors.blue];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: c[0], borderRadius: BorderRadius.circular(999)),
      child: Text(status,
          style: TextStyle(
              color: c[1], fontWeight: FontWeight.w700, fontSize: 11.5)),
    );
  }
}
