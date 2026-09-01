import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:transport_hub/data/datasources/local/hive_local_datasource.dart';
import 'package:transport_hub/data/repositories/company_repository_impl.dart';
import 'package:transport_hub/domain/entities/company.dart';
import 'package:transport_hub/domain/entities/transport_service.dart';

/// Service-price integrity (QA round 9). A company owner editing their catalog
/// could store a non-finite (NaN/±Infinity) or negative price, which crashed
/// the service card (`(±Inf).toInt()` throws) or rendered garbage like `$-50`.
/// The entity's priceLabel now renders defensively and the repository sanitizes
/// the price on write. Hive-backed; runs in CI.
void main() {
  group('TransportService.priceLabel is crash-safe', () {
    String label(double p, {String unit = 'flat'}) =>
        TransportService(name: 'X', unit: unit, price: p).priceLabel;

    test('non-finite prices render "On quote" instead of throwing', () {
      expect(label(double.infinity), 'On quote');
      expect(label(double.nan), 'On quote');
      expect(label(double.negativeInfinity), 'On quote');
    });

    test('negative prices render "On quote", never "\$-50"', () {
      expect(label(-50), 'On quote');
      expect(label(-0.01), 'On quote');
    });

    test('sensible prices still render correctly', () {
      expect(label(120), '\$120');
      expect(label(99.99), '\$99.99');
      expect(label(2, unit: 'per kg'), '\$2 / kg');
      expect(label(0), 'On quote');
      expect(label(50, unit: 'quote'), 'On quote');
    });
  });

  group('CompanyRepositoryImpl sanitizes service prices on write', () {
    late Directory tempDir;
    late HiveLocalDataSource ds;
    late CompanyRepositoryImpl repo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('transhub_company_');
      Hive.init(tempDir.path);
      ds = HiveLocalDataSource.instance;
      ds.companies = await Hive.openBox(HiveLocalDataSource.companiesBox);
      repo = CompanyRepositoryImpl(ds);
    });

    tearDown(() async {
      await ds.companies.clear();
      await Hive.deleteFromDisk();
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    Company seedCompany() {
      final c = Company(ownerId: 'o1', name: 'Acme Freight');
      repo.save(c);
      return c;
    }

    test('addService clamps a non-finite price to 0', () {
      final c = seedCompany();
      repo.addService(
          c.id, TransportService(name: 'Rush', price: double.infinity));
      final stored = repo.byId(c.id)!.services.single;
      expect(stored.price, 0);
      expect(stored.priceLabel, 'On quote');
    });

    test('addService clamps a negative price to 0', () {
      final c = seedCompany();
      repo.addService(c.id, TransportService(name: 'Rush', price: -50));
      expect(repo.byId(c.id)!.services.single.price, 0);
    });

    test('addService clamps an absurd price down to the max', () {
      final c = seedCompany();
      repo.addService(c.id, TransportService(name: 'Rush', price: 1e12));
      expect(repo.byId(c.id)!.services.single.price, 1000000);
    });

    test('updateService sanitizes on edit too', () {
      final c = seedCompany();
      final s = TransportService(name: 'Rush', price: 120);
      repo.addService(c.id, s);
      s.price = double.nan;
      repo.updateService(c.id, s);
      expect(repo.byId(c.id)!.services.single.price, 0);
    });

    test('a valid price is preserved untouched', () {
      final c = seedCompany();
      repo.addService(c.id, TransportService(name: 'Rush', price: 149.99));
      expect(repo.byId(c.id)!.services.single.price, 149.99);
    });
  });
}
