import '../../core/utils/validators.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';
import '../datasources/local/hive_local_datasource.dart';
import '../models/company_dto.dart';

/// Hive-backed [CompanyRepository].
class CompanyRepositoryImpl implements CompanyRepository {
  CompanyRepositoryImpl(this._ds);

  final HiveLocalDataSource _ds;

  @override
  List<Company> all() =>
      _ds.companies.values.map((e) => companyFromJson(e as Map)).toList();

  @override
  Company? byId(String id) {
    final j = _ds.companies.get(id);
    return j == null ? null : companyFromJson(j as Map);
  }

  @override
  void save(Company company) => _ds.companies.put(company.id, company.toJson());

  @override
  void addService(String companyId, TransportService service) {
    final c = byId(companyId);
    if (c == null) return;
    // Sanitize price at the data layer too, so a non-finite/negative value can
    // never reach storage regardless of which path wrote it (QA round 9).
    service.price = Validators.sanitizePrice(service.price);
    c.services.add(service);
    save(c);
  }

  @override
  void updateService(String companyId, TransportService service) {
    final c = byId(companyId);
    if (c == null) return;
    service.price = Validators.sanitizePrice(service.price);
    final i = c.services.indexWhere((x) => x.id == service.id);
    if (i >= 0) c.services[i] = service;
    save(c);
  }

  @override
  void removeService(String companyId, String serviceId) {
    final c = byId(companyId);
    if (c == null) return;
    c.services.removeWhere((x) => x.id == serviceId);
    save(c);
  }
}
