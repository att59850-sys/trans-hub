/// Remote backend abstraction (TH-013).
///
/// The repository layer talks to this interface, never to a concrete SDK, so
/// Hive can act purely as a local cache while the source of truth moves to a
/// remote backend (Supabase). A [NoopRemoteDataSource] is used while no backend
/// is configured, keeping the app fully offline-capable.
///
/// Each method returns/accepts JSON-able maps (the same shape the DTOs use), so
/// the sync engine can move records between local and remote without bespoke
/// mappers per table.
abstract interface class RemoteDataSource {
  /// Whether a real backend is wired up. When false the app is offline-only.
  bool get isConfigured;

  /// Fetches all rows of [table] changed since [sinceMillis] (0 = full pull).
  Future<List<Map<String, dynamic>>> fetchAll(
    String table, {
    int sinceMillis = 0,
  });

  /// Inserts or updates a row in [table]. Returns the stored row.
  Future<Map<String, dynamic>> upsert(
    String table,
    Map<String, dynamic> row,
  );

  /// Deletes the row with [id] from [table].
  Future<void> delete(String table, String id);
}

/// No-op implementation used when no backend is configured. Every read returns
/// empty and every write is a silent success, so callers behave identically
/// whether online or offline.
class NoopRemoteDataSource implements RemoteDataSource {
  const NoopRemoteDataSource();

  @override
  bool get isConfigured => false;

  @override
  Future<List<Map<String, dynamic>>> fetchAll(
    String table, {
    int sinceMillis = 0,
  }) async =>
      const [];

  @override
  Future<Map<String, dynamic>> upsert(
    String table,
    Map<String, dynamic> row,
  ) async =>
      row;

  @override
  Future<void> delete(String table, String id) async {}
}
