// Service-catalog / price edge-case simulation (manual-QA style).
//
// QA round 9 targets a company owner editing their service catalog. Prices are
// free-form doubles with (until this fix) NO validation anywhere, so a slip or
// corrupt record could store:
//   * a NEGATIVE price   -> renders as a nonsensical "$-50" to customers
//   * Infinity / NaN     -> `priceLabel` calls (±Inf).toInt() which THROWS
//                           UnsupportedError, crashing the service-card render
//   * an absurd figure   -> "$999999999999" splashed across the UI
//
// This runs on the plain Dart VM (the domain entity + Validators are pure Dart)
// and asserts that, after sanitizing through Validators, priceLabel is always
// safe and sensible.

import 'package:transport_hub/core/utils/validators.dart';
import 'package:transport_hub/domain/entities/transport_service.dart';

int _checks = 0;
int _failures = 0;

void check(String desc, bool ok, [String? detail]) {
  _checks++;
  final tag = ok ? 'PASS' : 'FAIL';
  if (!ok) _failures++;
  print('   $tag  $desc${detail != null ? '  ($detail)' : ''}');
}

void section(String title) => print('\n== $title ==');

/// Does calling `priceLabel` on a service with this raw price throw?
bool labelThrows(double rawPrice, {String unit = 'flat'}) {
  try {
    // ignore: unused_local_variable
    final _ =
        TransportService(name: 'X', unit: unit, price: rawPrice).priceLabel;
    return false;
  } catch (_) {
    return true;
  }
}

void main() {
  print('Trans-Hub — service price edge-case simulation\n');

  // ---------------------------------------------------------------------------
  // Before the fix, priceLabel crashed on ±Infinity ((±Inf).toInt() throws) and
  // rendered garbage ("$NaN", "$-50") for NaN/negative. The render layer is now
  // hardened as the last line of defence, so even a raw unsanitized value is
  // safe. These checks assert that fixed, crash-proof behavior.
  section('PRICE 1: priceLabel is crash-safe even on raw bad values');
  check('Infinity price no longer crashes priceLabel',
      !labelThrows(double.infinity));
  check('-Infinity price no longer crashes priceLabel',
      !labelThrows(double.negativeInfinity));
  check('NaN price renders "On quote" (not "\$NaN")',
      TransportService(name: 'X', price: double.nan).priceLabel == 'On quote');
  check('negative price renders "On quote" (not "\$-50")',
      TransportService(name: 'X', price: -50).priceLabel == 'On quote');

  // ---------------------------------------------------------------------------
  section('PRICE 2: validation rules');
  check('rejects Infinity', !Validators.isValidPrice(double.infinity));
  check('rejects NaN', !Validators.isValidPrice(double.nan));
  check('rejects -Infinity', !Validators.isValidPrice(double.negativeInfinity));
  check('rejects negative', !Validators.isValidPrice(-50));
  check('rejects absurdly large', !Validators.isValidPrice(1e12));
  check('accepts 0 (On quote)', Validators.isValidPrice(0));
  check('accepts a normal price', Validators.isValidPrice(120.50));
  check('accepts the max boundary',
      Validators.isValidPrice(Validators.maxServicePrice));

  // ---------------------------------------------------------------------------
  section('PRICE 3: sanitize maps every hazard to a safe value');
  check('Infinity -> 0', Validators.sanitizePrice(double.infinity) == 0);
  check('NaN -> 0', Validators.sanitizePrice(double.nan) == 0);
  check(
      '-Infinity -> 0', Validators.sanitizePrice(double.negativeInfinity) == 0);
  check('negative -> 0', Validators.sanitizePrice(-50) == 0);
  check('absurd -> clamped to max',
      Validators.sanitizePrice(1e12) == Validators.maxServicePrice);
  check('normal price passes through',
      Validators.sanitizePrice(120.50) == 120.50);

  // ---------------------------------------------------------------------------
  section('PRICE 4: a sanitized service never crashes & never shows nonsense');
  for (final raw in <double>[
    double.infinity,
    double.nan,
    double.negativeInfinity,
    -50,
    -0.01,
    1e15,
  ]) {
    final safe = Validators.sanitizePrice(raw);
    final label =
        TransportService(name: 'X', unit: 'flat', price: safe).priceLabel;
    check(
        'raw $raw -> safe label "$label" (no crash, no leading -)',
        !label.contains('-') &&
            !label.toLowerCase().contains('nan') &&
            !label.toLowerCase().contains('inf'),
        'label="$label"');
  }

  // ---------------------------------------------------------------------------
  section('PRICE 5: sensible labels still render correctly post-fix');
  String lbl(double p, String u) =>
      TransportService(name: 'X', unit: u, price: Validators.sanitizePrice(p))
          .priceLabel;
  check('flat \$120 -> "\$120"', lbl(120, 'flat') == '\$120',
      'got "${lbl(120, 'flat')}"');
  check('per kg \$2 -> "\$2 / kg"', lbl(2, 'per kg') == '\$2 / kg',
      'got "${lbl(2, 'per kg')}"');
  check('quote unit -> "On quote"', lbl(50, 'quote') == 'On quote');
  check('0 price -> "On quote"', lbl(0, 'flat') == 'On quote');
  check('fractional \$99.99 -> "\$99.99"', lbl(99.99, 'flat') == '\$99.99',
      'got "${lbl(99.99, 'flat')}"');

  // ---------------------------------------------------------------------------
  print('\n${'=' * 60}');
  print('RESULT: ${_checks - _failures}/$_checks checks passed');
  if (_failures > 0) {
    print('$_failures FAILURE(S) — see FAIL lines above.');
  } else {
    print('All service-price invariants hold.');
  }
}
