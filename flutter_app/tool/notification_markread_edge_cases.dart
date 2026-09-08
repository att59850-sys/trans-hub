// QA round 20 — notification mark-read ownership (pure-Dart harness).
//
// Re-implements NotificationRepositoryImpl's forUser / unreadCount / markRead /
// markAllRead in-memory (it's Hive-backed, so it can't run under bare
// `dart run`) to reproduce the bug found acting as a human user, and to prove
// the fix.
//
// Bug: markRead(notificationId) marks a notification read by id ALONE, with no
// check that it belongs to the acting user. The notifications screen normally
// passes an id from the current user's own list, but the facade offers no
// ownership guard — so a stale/misrouted id (e.g. one captured before a user
// switch, or from another account) silently marks ANOTHER user's notification
// read and decrements THEIR unread badge.
//
// Fix: markRead takes the acting userId and only flips the flag when the
// notification belongs to that user.
//
// Run: dart run tool/notification_markread_edge_cases.dart

int _passed = 0;
int _failed = 0;

void check(String name, bool cond) {
  if (cond) {
    _passed++;
    print('  ok   $name');
  } else {
    _failed++;
    print('  FAIL $name');
  }
}

class Note {
  Note(this.id, this.userId, {this.read = false});
  final String id;
  final String userId;
  bool read;
}

/// Faithful in-memory store mirroring the Hive repository, with BOTH the raw
/// (id-only) markRead and the fixed (owner-scoped) markRead.
class NoteStore {
  final Map<String, Note> _rows = {};

  void add(Note n) => _rows[n.id] = n;

  List<Note> forUser(String userId) =>
      _rows.values.where((n) => n.userId == userId).toList();

  int unreadCount(String userId) =>
      _rows.values.where((n) => n.userId == userId && !n.read).length;

  /// RAW: marks by id alone (the bug).
  void rawMarkRead(String id) {
    final n = _rows[id];
    if (n == null) return;
    n.read = true;
  }

  /// FIXED: only marks read when the note belongs to [actingUserId].
  /// Returns whether a note was actually marked.
  bool markRead(String id, String actingUserId) {
    final n = _rows[id];
    if (n == null || n.userId != actingUserId) return false;
    if (!n.read) n.read = true;
    return true;
  }

  void markAllRead(String userId) {
    for (final n in forUser(userId)) {
      n.read = false == n.read ? true : n.read; // set true if unread
      n.read = true;
    }
  }
}

void main() {
  print('== QA round 20: notification mark-read ownership ==\n');

  // ------------------------------------------------------------------
  // Sanity: unread counts are per-user; a normal mark-read decrements.
  // ------------------------------------------------------------------
  print('-- sanity: per-user unread counts --');
  {
    final s = NoteStore()
      ..add(Note('a1', 'alice'))
      ..add(Note('a2', 'alice'))
      ..add(Note('b1', 'bob'));
    check('alice has 2 unread', s.unreadCount('alice') == 2);
    check('bob has 1 unread', s.unreadCount('bob') == 1);

    check('alice marks her own note (fixed)', s.markRead('a1', 'alice'));
    check('alice now has 1 unread', s.unreadCount('alice') == 1);
    check('bob unaffected', s.unreadCount('bob') == 1);
  }

  // ------------------------------------------------------------------
  // DEMO: raw defect — one user marks ANOTHER user's notification read.
  // ------------------------------------------------------------------
  print('\n-- raw defect: cross-user mark-read leaks --');
  {
    final s = NoteStore()
      ..add(Note('a1', 'alice'))
      ..add(Note('b1', 'bob'));
    // Alice's session marks id 'b1' (bob's) — the id-only API allows it.
    s.rawMarkRead('b1');
    check("RAW BUG: bob's notification got marked read by another actor",
        s.forUser('bob').single.read == true);
    check("RAW BUG: bob's unread badge wrongly dropped to 0",
        s.unreadCount('bob') == 0);
  }

  // ------------------------------------------------------------------
  // FIX: owner-scoped mark-read.
  // ------------------------------------------------------------------
  print('\n-- fixed: mark-read is scoped to the owner --');
  {
    final s = NoteStore()
      ..add(Note('a1', 'alice'))
      ..add(Note('b1', 'bob'));
    final applied = s.markRead('b1', 'alice'); // alice acting on bob's note
    check("alice cannot mark bob's note (returns false)", applied == false);
    check("bob's note stays unread", s.forUser('bob').single.read == false);
    check("bob's unread badge unchanged", s.unreadCount('bob') == 1);

    // Bob himself can, of course.
    check('bob marks his own note', s.markRead('b1', 'bob'));
    check("bob's unread badge now 0", s.unreadCount('bob') == 0);
  }

  print('\n-- fixed: unknown id is a safe no-op --');
  {
    final s = NoteStore()..add(Note('a1', 'alice'));
    check('missing id returns false', !s.markRead('nope', 'alice'));
    check('alice still has 1 unread', s.unreadCount('alice') == 1);
  }

  print('\n-- fixed: double mark-read is idempotent --');
  {
    final s = NoteStore()..add(Note('a1', 'alice'));
    check('first mark ok', s.markRead('a1', 'alice'));
    check('second mark still ok (idempotent)', s.markRead('a1', 'alice'));
    check('unread is 0', s.unreadCount('alice') == 0);
  }

  print('\n-- markAllRead stays per-user (regression) --');
  {
    final s = NoteStore()
      ..add(Note('a1', 'alice'))
      ..add(Note('a2', 'alice'))
      ..add(Note('b1', 'bob'));
    s.markAllRead('alice');
    check('alice fully read', s.unreadCount('alice') == 0);
    check('bob untouched by alice markAll', s.unreadCount('bob') == 1);
  }

  print('\n== $_passed passed, $_failed failed ==');
  if (_failed > 0) {
    throw StateError('notification mark-read edge cases failed');
  }
}
