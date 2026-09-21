import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart' show AutoScrollTag;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/constants/ui_strings.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/song.dart';
import 'package:yahwehs_words/pages/songs_page.dart';
import 'package:yahwehs_words/providers/main_provider.dart';
import 'package:yahwehs_words/services/song_service.dart';

/// Characterization test for the Songs page sort picker (`queue:133`).
///
/// `queue:133` (Songs "recent" sort surfaces the wrong songs) is a
/// BLOCKED item waiting on a user decision between two named options.
/// Neither is implemented here — this only pins today's behaviour, so
/// that whichever option the user eventually picks changes exactly the
/// code this test watches, and does so visibly (a red assertion)
/// rather than silently.
///
/// The list is virtualized (`lib/pages/songs_page.dart`, `filtered[i -
/// 2]` inside `ListView.separated`), so only the rows actually built
/// for the current viewport exist as widgets. Every assertion below is
/// therefore over the VISIBLE PREFIX of the sorted list, not the whole
/// catalogue — a tall test viewport is used so that prefix spans more
/// than one source/timestamp, but nothing here assumes full coverage.
///
/// `assets/songs.json` is refreshed daily by `sync-songs.yml`, so no
/// song title, id, count or timestamp is asserted literally — only the
/// ordering invariant each sort key documents on `_sort` in
/// `songs_page.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final locale = AppSettings().locale;
  final sortTooltip = uiStrings['songsSortTooltip']![locale]!;
  final addedLabel = uiStrings['songsSortAdded']![locale]!;
  final titleLabel = uiStrings['songsSortTitle']![locale]!;
  final sourceLabel = uiStrings['songsSortSource']![locale]!;

  // The page also hosts a language-switcher PopupMenuButton<String> in
  // its app bar (tooltip "界面语言" / "Interface language"), so
  // `find.byType(PopupMenuButton<String>)` alone is ambiguous — this
  // picks out the sort picker specifically, by its own tooltip.
  PopupMenuButton<String> sortPicker(WidgetTester tester) {
    return tester.widget<PopupMenuButton<String>>(find.byWidgetPredicate(
        (w) => w is PopupMenuButton<String> && w.tooltip == sortTooltip));
  }

  // Tall and narrow: more rows land inside ListView's cache extent than
  // a phone-height viewport would give us, without pulling in so much
  // width that fewer rows are needed to fill it.
  const tallViewport = Size(390, 4000);

  Future<void> pumpSongsPage(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;

    // See songs_filter_sheet_test.dart: the page reads assets/songs.json
    // via rootBundle, which needs real async time that only runAsync
    // gives. SongService memoises, so the widget's own load() then
    // resolves from cache.
    await tester.runAsync(SongService.load);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: const MaterialApp(home: SongsPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// The song ids currently built as list rows, in on-screen order.
  /// Each row is tagged `AutoScrollTag(key: ValueKey(song.id), ...)`
  /// (songs_page.dart:358-361) precisely so a scroll controller — or a
  /// test — can name a row without reaching into the page's private
  /// state.
  List<String> visibleSongIds(WidgetTester tester) {
    return tester
        .widgetList<AutoScrollTag>(find.byType(AutoScrollTag))
        .map((tag) => (tag.key! as ValueKey<String>).value)
        .toList();
  }

  Future<void> selectSort(WidgetTester tester, String label) async {
    final sortIcon = find.byIcon(Icons.sort);
    expect(sortIcon, findsOneWidget,
        reason: 'the sort picker should be on the search bar');
    await tester.tap(sortIcon);
    await tester.pumpAndSettle();

    final item = find.text(label);
    expect(item, findsOneWidget, reason: 'missing sort option "$label"');
    await tester.tap(item);
    await tester.pumpAndSettle();
  }

  /// 'recent': newest `updatedAt` first, ties broken by title
  /// ascending, per the doc comment on `_sort` in songs_page.dart.
  void expectRecentOrder(List<Song> visible) {
    for (var i = 0; i + 1 < visible.length; i++) {
      final cur = visible[i];
      final next = visible[i + 1];
      final curKey = cur.updatedAt ?? '';
      final nextKey = next.updatedAt ?? '';
      final cmp = curKey.compareTo(nextKey);
      final ok = cmp > 0 || (cmp == 0 && cur.title.compareTo(next.title) <= 0);
      expect(ok, isTrue,
          reason: "'recent' sort: '${cur.id}' (updatedAt=$curKey) should "
              "not sit before '${next.id}' (updatedAt=$nextKey) — newest "
              'updatedAt goes first, ties broken by title ascending, '
              'null/empty timestamps last');
    }
  }

  /// 'added': same shape as 'recent', over `firstSeenAt`.
  void expectAddedOrder(List<Song> visible) {
    for (var i = 0; i + 1 < visible.length; i++) {
      final cur = visible[i];
      final next = visible[i + 1];
      final curKey = cur.firstSeenAt ?? '';
      final nextKey = next.firstSeenAt ?? '';
      final cmp = curKey.compareTo(nextKey);
      final ok = cmp > 0 || (cmp == 0 && cur.title.compareTo(next.title) <= 0);
      expect(ok, isTrue,
          reason: "'added' sort: '${cur.id}' (firstSeenAt=$curKey) should "
              "not sit before '${next.id}' (firstSeenAt=$nextKey) — newest "
              'firstSeenAt goes first, ties broken by title ascending, '
              'null/empty timestamps last');
    }
  }

  /// 'title': ascending.
  void expectTitleOrder(List<Song> visible) {
    for (var i = 0; i + 1 < visible.length; i++) {
      final cur = visible[i];
      final next = visible[i + 1];
      expect(cur.title.compareTo(next.title) <= 0, isTrue,
          reason: "'title' sort: '${cur.title}' should not sit before "
              "'${next.title}' — titles should be ascending");
    }
  }

  /// 'source': catalogue order — source ascending, then
  /// `code ?? title` ascending.
  void expectSourceOrder(List<Song> visible) {
    for (var i = 0; i + 1 < visible.length; i++) {
      final cur = visible[i];
      final next = visible[i + 1];
      final cmp = cur.source.compareTo(next.source);
      final curTiebreak = cur.code ?? cur.title;
      final nextTiebreak = next.code ?? next.title;
      final ok = cmp < 0 || (cmp == 0 && curTiebreak.compareTo(nextTiebreak) <= 0);
      expect(ok, isTrue,
          reason: "'source' sort: '${cur.id}' (source=${cur.source}, "
              "code/title=$curTiebreak) should not sit before '${next.id}' "
              '(source=${next.source}, code/title=$nextTiebreak) — source '
              'ascending, then code (or title when there is no code) '
              'ascending');
    }
  }

  testWidgets('default state: sort is recent, no filter active',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);

    await pumpSongsPage(tester, tallViewport);

    expect(sortPicker(tester).initialValue, 'recent',
        reason: 'the sort picker should default to "recent"');

    // The Filter button swaps to a filled icon once any filter is
    // active; nothing is selected on a fresh page, so it must be the
    // plain outline — the same signal songs_filter_sheet_test.dart
    // uses for "no filter is active".
    expect(find.byIcon(Icons.filter_list), findsOneWidget,
        reason: 'no filter should be active on a fresh page');
    expect(find.byIcon(Icons.filter_list_alt), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets(
      'default state is not persisted: a fresh remount forgets any change',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);

    await pumpSongsPage(tester, tallViewport);
    await selectSort(tester, titleLabel);
    expect(
      sortPicker(tester).initialValue,
      'title',
      reason: 'the tap should have changed the live sort',
    );

    // Tear the page down and build a brand new one — same process, new
    // State object. `queue:133` describes the sort/filter state as
    // NOT persisted; if that ever changes, this is the assertion that
    // should go red rather than pass silently.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
    await pumpSongsPage(tester, tallViewport);

    expect(
      sortPicker(tester).initialValue,
      'recent',
      reason: 'a freshly mounted SongsPage should be back to the "recent" '
          'default, not remember the previous session\'s "title" choice',
    );
    expect(find.byIcon(Icons.filter_list), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('recent sort orders visible rows by updatedAt', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);

    final all = (await tester.runAsync(SongService.load))!;
    final byId = {for (final s in all) s.id: s};

    await pumpSongsPage(tester, tallViewport);
    // 'recent' is already the default; nothing to switch.
    final visibleIds = visibleSongIds(tester);
    expect(visibleIds.length, greaterThan(1),
        reason: 'the viewport should render more than one row to make '
            'an ordering assertion meaningful');
    expectRecentOrder(visibleIds.map((id) => byId[id]!).toList());

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('added sort orders visible rows by firstSeenAt',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);

    final all = (await tester.runAsync(SongService.load))!;
    final byId = {for (final s in all) s.id: s};

    await pumpSongsPage(tester, tallViewport);
    await selectSort(tester, addedLabel);

    final visibleIds = visibleSongIds(tester);
    expect(visibleIds.length, greaterThan(1));
    expectAddedOrder(visibleIds.map((id) => byId[id]!).toList());

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('title sort orders visible rows A-Z', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);

    final all = (await tester.runAsync(SongService.load))!;
    final byId = {for (final s in all) s.id: s};

    await pumpSongsPage(tester, tallViewport);
    await selectSort(tester, titleLabel);

    final visibleIds = visibleSongIds(tester);
    expect(visibleIds.length, greaterThan(1));
    expectTitleOrder(visibleIds.map((id) => byId[id]!).toList());

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('source sort orders visible rows by catalogue', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);

    final all = (await tester.runAsync(SongService.load))!;
    final byId = {for (final s in all) s.id: s};

    await pumpSongsPage(tester, tallViewport);
    await selectSort(tester, sourceLabel);

    final visibleIds = visibleSongIds(tester);
    expect(visibleIds.length, greaterThan(1));
    expectSourceOrder(visibleIds.map((id) => byId[id]!).toList());

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });
}
