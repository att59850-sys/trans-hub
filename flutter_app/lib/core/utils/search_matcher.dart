/// Shared, testable search/sort helpers for the Browse screen (single source
/// of truth).
///
/// The Browse filter used to match with the RAW query text inline in the
/// widget, which produced two user-facing defects a QA pass surfaced (round 10):
///
///   * a trailing/leading space in the query (very common from mobile
///     keyboards / autocomplete) made `contains(" acme ")` fail even though
///     "Acme" existed, so the user saw "No providers found"; and
///   * a whitespace-only query ("   ") counted as non-empty and matched
///     nothing, blanking the whole list.
///
/// Centralizing the rule here keeps the widget thin and lets it be unit-tested
/// without a Flutter binding.
class SearchMatcher {
  const SearchMatcher._();

  /// Whether [haystack] matches [query], case-insensitively. A blank query
  /// (empty or whitespace-only) matches everything — an empty search is not a
  /// filter. Both sides are trimmed so stray spaces never hide a real match.
  static bool matches(String haystack, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return haystack.toLowerCase().contains(q);
  }

  /// Case-insensitive name comparison for alphabetical sorting, tie-broken by
  /// the raw value so ordering stays deterministic. Prevents the ASCII quirk
  /// where a lowercase initial (e.g. "blue") sorts after an uppercase one
  /// (e.g. "Zephyr").
  static int compareNames(String a, String b) {
    final byLower = a.toLowerCase().compareTo(b.toLowerCase());
    return byLower != 0 ? byLower : a.compareTo(b);
  }
}
