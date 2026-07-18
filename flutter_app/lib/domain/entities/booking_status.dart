/// Booking lifecycle states (TH-016).
///
/// draft → quote_requested → quote_sent → pending → accepted →
/// in_transit → completed   (or → cancelled from most states)
enum BookingStatus {
  draft,
  quoteRequested,
  quoteSent,
  pending,
  accepted,
  inTransit,
  completed,
  cancelled,
}

extension BookingStatusX on BookingStatus {
  /// Wire/storage value (snake_case), stable across versions.
  String get wire => switch (this) {
        BookingStatus.draft => 'draft',
        BookingStatus.quoteRequested => 'quote_requested',
        BookingStatus.quoteSent => 'quote_sent',
        BookingStatus.pending => 'pending',
        BookingStatus.accepted => 'accepted',
        BookingStatus.inTransit => 'in_transit',
        BookingStatus.completed => 'completed',
        BookingStatus.cancelled => 'cancelled',
      };

  /// Human-readable label.
  String get label => switch (this) {
        BookingStatus.draft => 'Draft',
        BookingStatus.quoteRequested => 'Quote requested',
        BookingStatus.quoteSent => 'Quote sent',
        BookingStatus.pending => 'Pending',
        BookingStatus.accepted => 'Accepted',
        BookingStatus.inTransit => 'In transit',
        BookingStatus.completed => 'Completed',
        BookingStatus.cancelled => 'Cancelled',
      };

  /// Valid next transitions from this state.
  List<BookingStatus> get nextStates => switch (this) {
        BookingStatus.draft => [
            BookingStatus.quoteRequested,
            BookingStatus.pending,
            BookingStatus.cancelled,
          ],
        BookingStatus.quoteRequested => [
            BookingStatus.quoteSent,
            BookingStatus.cancelled,
          ],
        BookingStatus.quoteSent => [
            BookingStatus.pending,
            BookingStatus.cancelled,
          ],
        BookingStatus.pending => [
            BookingStatus.accepted,
            BookingStatus.cancelled,
          ],
        BookingStatus.accepted => [
            BookingStatus.inTransit,
            BookingStatus.cancelled,
          ],
        BookingStatus.inTransit => [BookingStatus.completed],
        BookingStatus.completed => const [],
        BookingStatus.cancelled => const [],
      };

  bool get isTerminal =>
      this == BookingStatus.completed || this == BookingStatus.cancelled;

  /// Whether moving directly to [target] is a legal lifecycle transition.
  ///
  /// This is the single source of truth for the state machine: the dashboard
  /// uses [nextStates] to *offer* moves, and the data layer uses this to
  /// *reject* illegal ones (e.g. a client trying to jump pending → completed).
  bool canTransitionTo(BookingStatus target) => nextStates.contains(target);
}

/// Parses a [BookingStatus] from its wire value, tolerating legacy values
/// ("confirmed" → accepted) and unknown input (→ pending).
BookingStatus bookingStatusFromWire(String? s) {
  switch (s) {
    case 'draft':
      return BookingStatus.draft;
    case 'quote_requested':
      return BookingStatus.quoteRequested;
    case 'quote_sent':
      return BookingStatus.quoteSent;
    case 'pending':
      return BookingStatus.pending;
    case 'accepted':
    case 'confirmed': // legacy alias
      return BookingStatus.accepted;
    case 'in_transit':
      return BookingStatus.inTransit;
    case 'completed':
      return BookingStatus.completed;
    case 'cancelled':
      return BookingStatus.cancelled;
    default:
      return BookingStatus.pending;
  }
}
