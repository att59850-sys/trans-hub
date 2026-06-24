import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_hub/widgets/widgets.dart';

/// TH-021 — Widget tests for the self-contained presentation widgets.
///
/// These widgets depend only on the theme and their constructor arguments
/// (no Hive / DataService / get_it), so they can be pumped directly inside a
/// minimal [MaterialApp]. Widgets that read [DataService.instance]
/// (e.g. [CompanyCard]) and DI-backed widgets (e.g. SyncStatusBar) are covered
/// by integration tests where the full app is bootstrapped.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: child))),
    );
  }

  group('RatingBadge', () {
    testWidgets('shows the numeric average and count', (tester) async {
      await pump(tester, const RatingBadge(4.7, 132));
      expect(find.text('4.7'), findsOneWidget);
      expect(find.text('(132)'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('renders an em dash when there are no ratings', (tester) async {
      await pump(tester, const RatingBadge(0, 0));
      expect(find.text('—'), findsOneWidget);
      expect(find.text('(0)'), findsOneWidget);
    });
  });

  group('MetaTag', () {
    testWidgets('shows its icon and label', (tester) async {
      await pump(tester, const MetaTag(Icons.location_on, 'Nationwide'));
      expect(find.text('Nationwide'), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
    });
  });

  group('NewPill', () {
    testWidgets('renders the NEW label', (tester) async {
      await pump(tester, const NewPill());
      expect(find.textContaining('NEW'), findsOneWidget);
    });
  });

  group('StarsRow', () {
    testWidgets('always renders five star icons', (tester) async {
      await pump(tester, const StarsRow(3));
      expect(find.byIcon(Icons.star), findsNWidgets(5));
    });

    testWidgets('honours a custom size', (tester) async {
      await pump(tester, const StarsRow(5, size: 24));
      final icon = tester.widget<Icon>(find.byIcon(Icons.star).first);
      expect(icon.size, 24);
    });
  });

  group('SectionHead', () {
    testWidgets('shows the title', (tester) async {
      await pump(tester, const SectionHead('Popular services'));
      expect(find.text('Popular services'), findsOneWidget);
    });

    testWidgets('renders the trailing widget when provided', (tester) async {
      await pump(
        tester,
        const SectionHead('Bookings', trailing: Text('See all')),
      );
      expect(find.text('Bookings'), findsOneWidget);
      expect(find.text('See all'), findsOneWidget);
    });
  });

  group('EmptyState', () {
    testWidgets('shows icon, title and subtitle', (tester) async {
      await pump(
        tester,
        const EmptyState(Icons.inbox, 'No bookings yet', 'Start exploring.'),
      );
      expect(find.byIcon(Icons.inbox), findsOneWidget);
      expect(find.text('No bookings yet'), findsOneWidget);
      expect(find.text('Start exploring.'), findsOneWidget);
    });

    testWidgets('renders an action when provided', (tester) async {
      await pump(
        tester,
        EmptyState(
          Icons.search,
          'Nothing found',
          'Try another query.',
          action: ElevatedButton(onPressed: () {}, child: const Text('Browse')),
        ),
      );
      expect(find.text('Browse'), findsOneWidget);
    });
  });

  group('StatusBadge', () {
    testWidgets('renders the status label', (tester) async {
      await pump(tester, const StatusBadge('pending'));
      expect(find.text('pending'), findsOneWidget);
    });

    testWidgets('renders an unknown status without crashing', (tester) async {
      await pump(tester, const StatusBadge('quoteRequested'));
      expect(find.text('quoteRequested'), findsOneWidget);
    });
  });
}
