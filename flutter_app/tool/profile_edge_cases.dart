// Company profile-edit edge-case simulation (manual-QA style).
//
// QA round 13 acts as a provider editing their company profile on the
// dashboard. The save handler wrote whatever was typed with no validation:
//
//   ..name = _name.text.trim()                       // may be ""
//   ..fleetSize = int.tryParse(_fleet.text) ?? 1     // may be -5, 0, 99999999
//   ..yearsActive = int.tryParse(_years.text) ?? 0   // may be -3, 9999
//
// and updateCompany persisted it blindly. So a provider could save:
//   * a BLANK company name -> a nameless card in Browse, empty titles;
//   * "-5 vehicles" / "0+ vehicles" (fleetSize <= 0);
//   * "-3 yrs" active (negative), or an absurd age.
//
// Runs on the plain Dart VM (models.dart + Validators are pure Dart) and
// asserts the sanitizers keep every rendered figure sane.

import 'package:transport_hub/core/utils/validators.dart';
import 'package:transport_hub/models/models.dart';

int _checks = 0;
int _failures = 0;

void check(String desc, bool ok, [String? detail]) {
  _checks++;
  final tag = ok ? 'PASS' : 'FAIL';
  if (!ok) _failures++;
  print('   $tag  $desc${detail != null ? '  ($detail)' : ''}');
}

void section(String title) => print('\n== $title ==');

void main() {
  print('Trans-Hub — company profile edit edge-case simulation\n');

  // ---------------------------------------------------------------------------
  section('PROFILE 1: the raw (undefended) hazard');
  {
    // Mirror the old save handler + the card labels it feeds.
    final bad = Company(
      ownerId: 'o1',
      name: '   '.trim(), // user cleared the field
      fleetSize: int.tryParse('-5') ?? 1,
      yearsActive: int.tryParse('-3') ?? 0,
    );
    check('DEMO: blank name persisted as empty', bad.name.isEmpty);
    check('DEMO: negative fleet renders "-5+ vehicles"',
        '${bad.fleetSize}+ vehicles' == '-5+ vehicles');
    check('DEMO: negative years renders "-3 yrs"',
        '${bad.yearsActive} yrs' == '-3 yrs');
  }

  // ---------------------------------------------------------------------------
  section('PROFILE 2: name validation');
  check('empty name rejected', !Validators.isNonEmptyName(''));
  check('whitespace name rejected', !Validators.isNonEmptyName('   '));
  check('real name accepted', Validators.isNonEmptyName('Acme Freight'));

  // ---------------------------------------------------------------------------
  section('PROFILE 3: fleet size clamps to >= 1');
  check('-5 -> 1', Validators.sanitizeFleetSize(-5) == 1);
  check('0 -> 1', Validators.sanitizeFleetSize(0) == 1);
  check('1 -> 1', Validators.sanitizeFleetSize(1) == 1);
  check('42 -> 42', Validators.sanitizeFleetSize(42) == 42);
  check('99999999 -> max',
      Validators.sanitizeFleetSize(99999999) == Validators.maxFleetSize);

  // ---------------------------------------------------------------------------
  section('PROFILE 4: years-active clamps to [0, max]');
  check('-3 -> 0', Validators.sanitizeYearsActive(-3) == 0);
  check('0 -> 0', Validators.sanitizeYearsActive(0) == 0);
  check('12 -> 12', Validators.sanitizeYearsActive(12) == 12);
  check('9999 -> max',
      Validators.sanitizeYearsActive(9999) == Validators.maxYearsActive);

  // ---------------------------------------------------------------------------
  section('PROFILE 5: a sanitized profile renders sane labels');
  {
    final safe = Company(
      ownerId: 'o1',
      name: 'Acme Freight',
      fleetSize: Validators.sanitizeFleetSize(int.tryParse('-5') ?? 1),
      yearsActive: Validators.sanitizeYearsActive(int.tryParse('-3') ?? 0),
    );
    final fleetLabel = '${safe.fleetSize}+ vehicles';
    final yearsLabel = '${safe.yearsActive} yrs';
    check('no negative fleet in label', !fleetLabel.contains('-'), fleetLabel);
    check('no negative years in label', !yearsLabel.contains('-'), yearsLabel);
    check('fleet label is "1+ vehicles"', fleetLabel == '1+ vehicles');
    check('years label is "0 yrs"', yearsLabel == '0 yrs');
  }

  // ---------------------------------------------------------------------------
  print('\n${'=' * 60}');
  print('RESULT: ${_checks - _failures}/$_checks checks passed');
  if (_failures > 0) {
    print('$_failures FAILURE(S) — see FAIL lines above.');
  } else {
    print('All company-profile invariants hold.');
  }
}
