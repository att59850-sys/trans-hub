/// Stable ordering helpers for time-ordered lists.
///
/// Several records can share the SAME `createdAt` millisecond (a single action
/// often creates more than one in one tick). A `createdAt`-only comparator is
/// therefore unstable on ties, letting Hive/Map iteration order decide the
/// result — the list can reorder/flicker between reads. These helpers tie-break
/// equal timestamps by id so ordering is deterministic and stable, and are the
/// single source of truth used by both the repositories and the DataService
/// facade so the two layers cannot diverge. (Introduced via adversarial QA:
/// notifications → sync queue → this systemic sweep.)
class Ordering {
  const Ordering._();

  /// Newest first: descending `createdAt`, tie-broken by descending id.
  static int newestFirst(
    int aCreatedAt,
    String aId,
    int bCreatedAt,
    String bId,
  ) {
    final byTime = bCreatedAt.compareTo(aCreatedAt);
    return byTime != 0 ? byTime : bId.compareTo(aId);
  }

  /// Oldest first (FIFO): ascending `createdAt`, tie-broken by ascending id.
  static int oldestFirst(
    int aCreatedAt,
    String aId,
    int bCreatedAt,
    String bId,
  ) {
    final byTime = aCreatedAt.compareTo(bCreatedAt);
    return byTime != 0 ? byTime : aId.compareTo(bId);
  }
}
