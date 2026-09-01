import '../../core/utils/id_generator.dart';

/// A bookable service offered by a [Company] (e.g. "Same-day courier").
class TransportService {
  TransportService({
    String? id,
    required this.name,
    this.desc = '',
    this.unit = 'flat',
    this.price = 0,
    this.icon = 'local_shipping',
    this.active = true,
  }) : id = id ?? newId('s');

  final String id;
  String name;
  String desc;
  String unit; // flat, per mile, per kg, quote, etc.
  double price;
  String icon; // material icon key
  bool active;

  /// Human-friendly price label, e.g. `$120` or `$2 / kg` or `On quote`.
  ///
  /// Renders defensively: a non-finite (NaN/±Infinity) or non-positive price is
  /// treated as "On quote" so a corrupt or unsanitized value can never crash the
  /// card (`(±Inf).toInt()` throws) or show garbage like `$NaN` / `$-50`.
  String get priceLabel {
    if (unit == 'quote' || !price.isFinite || price <= 0) return 'On quote';
    final p = price == price.roundToDouble()
        ? '\$${price.toInt()}'
        : '\$${price.toStringAsFixed(2)}';
    if (unit == 'flat') return p;
    return '$p / ${unit.replaceFirst('per ', '')}';
  }
}
