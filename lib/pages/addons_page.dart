/// Add-ons: Bible texts the reader brought in from elsewhere.
///
/// Reached from Settings. The page is
/// small on purpose: what a module is, a button to pick a file, and one card
/// per text with an on/off switch. Everything the reader needs to judge a text
/// — what it covers, how big it is, what the publisher says, what the app
/// will NOT show from it — is one tap away in its detail sheet.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yahwehs_words/constants/bible_versions.dart'
    show resolvableVersion;
import 'package:yahwehs_words/models/addon.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/pages/home_page.dart';
import 'package:yahwehs_words/providers/main_provider.dart';
import 'package:yahwehs_words/services/addons/addon_registry.dart';
import 'package:yahwehs_words/services/fetch_books.dart';
import 'package:yahwehs_words/services/fetch_verses.dart';
import 'package:yahwehs_words/utils/addons/addon_texts.dart';
import 'package:yahwehs_words/utils/addons/addon_types.dart';
import 'package:yahwehs_words/utils/app_nav.dart';
import 'package:yahwehs_words/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yahwehs_words/utils/pick_module_file.dart';
import 'package:yahwehs_words/utils/version_mapper.dart' show translateBookName;
import 'package:yahwehs_words/widgets/addon_import_sheet.dart';
import 'package:yahwehs_words/widgets/app_empty_state.dart';

/// Start the import flow: pick a file, run the sheet, and — when the reader
/// asks — open the new text in the reader.
Future<void> startAddonImport(BuildContext context) async {
  final settings = context.read<AppSettings>();
  final messenger = ScaffoldMessenger.maybeOf(context);
  final locale = settings.locale;
  final PickedModuleFile? file;
  try {
    file = await pickModuleFile();
  } on ImportRefusal catch (e) {
    messenger?.showSnackBar(SnackBar(
        content: Text(addonProblemText(e.problem, locale, detail: e.detail))));
    return;
  }
  if (file == null || !context.mounted) return;
  final result = await showAddonImportSheet(
    context,
    fileName: file.name,
    bytes: file.bytes,
    locale: locale,
    fontFamily: settings.fontFamily,
  );
  if (result == null || !context.mounted) return;
  if (result.readNow) await readAddonNow(context, result.entry);
}

/// Switch the reader to [entry] and open it, landing on the chapter the
/// reader was already in when the text has it, and on its own first verse when
/// it does not (a New-Testament-only text opened from Genesis, say).
Future<void> readAddonNow(BuildContext context, AddonEntry entry) async {
  final mp = context.read<MainProvider>();
  final locale = context.read<AppSettings>().locale;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final prevBook = mp.currentBook;
  final prevChapter = mp.currentChapter;
  final prevVersion = mp.currentVersion;
  mp.setVersionSwitching(true, to: entry.label);
  try {
    await Future<void>.delayed(Duration.zero);
    mp.setVersion(entry.id);
    await FetchVerses.execute(mainProvider: mp);
    await FetchBooks.execute(mainProvider: mp);
    if (mp.verses.isEmpty) {
      mp.setVersion(prevVersion);
      await FetchVerses.execute(mainProvider: mp);
      await FetchBooks.execute(mainProvider: mp);
      messenger?.showSnackBar(SnackBar(
          content: Text(addonProblemText(ImportProblem.corruptFile, locale))));
      return;
    }
    final en = prevBook == null ? null : (bookNameToEnglish[prevBook] ?? prevBook);
    final target = en == null ? null : translateBookName(en, entry.id);
    final here = (target != null && prevChapter != null)
        ? mp.versesInChapter(target, prevChapter)
        : const [];
    final first = here.isNotEmpty ? here.first : mp.verses.first;
    mp.setCurrentChapter(book: first.book, chapter: first.chapter);
    mp.updateCurrentVerse(verse: first);
  } finally {
    mp.setVersionSwitching(false);
  }
  if (!context.mounted) return;
  pushPage(const HomePage(), routeName: '/HomePage');
}

/// Take [id] off the device. If it is the text on screen, move the reader to
/// the edition the app would choose instead — and say so.
Future<void> removeAddon(BuildContext context, AddonEntry entry) async {
  final mp = context.read<MainProvider>();
  final wasCurrent = mp.currentVersion == entry.id;
  await AddonRegistry.forget(entry.id);
  mp.evictVersionCache(entry.id);
  if (wasCurrent) {
    mp.setVersion(resolvableVersion(entry.id));
    await FetchVerses.execute(mainProvider: mp);
    await FetchBooks.execute(mainProvider: mp);
  }
}

class AddonsPage extends StatefulWidget {
  const AddonsPage({super.key});

  @override
  State<AddonsPage> createState() => _AddonsPageState();
}

class _AddonsPageState extends State<AddonsPage> {
  int? _bytes;

  @override
  void initState() {
    super.initState();
    AddonRegistry.changes.addListener(_refreshBytes);
    _refreshBytes();
  }

  @override
  void dispose() {
    AddonRegistry.changes.removeListener(_refreshBytes);
    super.dispose();
  }

  Future<void> _refreshBytes() async {
    final n = await AddonRegistry.bytesUsed();
    if (mounted) setState(() => _bytes = n);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;
    String t(String k, [Map<String, Object> v = const {}]) => addonText(k, locale, v);
    final style = TextStyle(
      fontFamily: settings.fontFamily,
      fontFamilyFallback: kCjkFontFallback,
    );
    return Scaffold(
      appBar: AppBar(title: Text(t('addonsTitle'), style: style)),
      body: ValueListenableBuilder<int>(
        valueListenable: AddonRegistry.changes,
        builder: (context, _, __) {
          final entries = AddonRegistry.all;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Container(
                key: const ValueKey('addons.intro'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.extension_rounded, color: scheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(t('addonIntro'),
                              style: style.copyWith(fontSize: 14.5, height: 1.45)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(t('addonSupported'),
                        style: style.copyWith(
                            fontSize: 12.5,
                            height: 1.4,
                            color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const ValueKey('addons.choose'),
                onPressed: () => startAddonImport(context),
                icon: const Icon(Icons.file_open_rounded),
                label: Text(t('addonChoose')),
              ),
              const SizedBox(height: 18),
              if (entries.isEmpty)
                SizedBox(
                  height: 280,
                  child: AppEmptyState(
                    icon: Icons.menu_book_rounded,
                    title: t('addonEmptyTitle'),
                    body: t('addonEmptyBody'),
                    textStyle: style,
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(t('addonListHeader'),
                      style: style.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary)),
                ),
                for (final e in entries)
                  _AddonCard(entry: e, locale: locale, style: style),
                if (_bytes != null && _bytes! > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Text(t('addonStorage', {'size': formatBytes(_bytes!)}),
                        style: style.copyWith(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AddonCard extends StatelessWidget {
  const _AddonCard({required this.entry, required this.locale, required this.style});

  final AddonEntry entry;
  final String locale;
  final TextStyle style;

  String _coverage(String Function(String) t) {
    if (entry.isFullCanon || entry.legacy) return '';
    if (entry.coversOldTestament && !entry.coversNewTestament) return t('addonOtOnly');
    if (!entry.coversOldTestament && entry.coversNewTestament) return t('addonNtOnly');
    return t('addonPartial');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    String t(String k, [Map<String, Object> v = const {}]) => addonText(k, locale, v);
    final coverage = _coverage(t);
    final facts = <String>[
      if (entry.format != null) t('addonFormat_${entry.format!.name}'),
      t('addonMetaCounts', {'n': entry.verseCount, 'b': entry.legacy ? '?' : entry.books.length}),
      if (coverage.isNotEmpty) coverage,
      if (entry.payloadBytes > 0) formatBytes(entry.payloadBytes),
    ];
    return Card(
      key: ValueKey('addon.card.${entry.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: entry.enabled
                                ? scheme.onSurface
                                : scheme.onSurface.withValues(alpha: 0.5))),
                    const SizedBox(height: 3),
                    Text(facts.join(' · '),
                        style: style.copyWith(
                            fontSize: 12.5, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Tooltip(
                message: t('addonEnabled'),
                child: Switch(
                  key: ValueKey('addon.switch.${entry.id}'),
                  value: entry.enabled,
                  onChanged: (v) async {
                    final mp = context.read<MainProvider>();
                    final wasCurrent = mp.currentVersion == entry.id;
                    if (!await AddonRegistry.setEnabled(entry.id, v)) return;
                    if (!v) {
                      mp.evictVersionCache(entry.id);
                      if (wasCurrent) {
                        mp.setVersion(resolvableVersion(entry.id));
                        await FetchVerses.execute(mainProvider: mp);
                        await FetchBooks.execute(mainProvider: mp);
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    String t(String k, [Map<String, Object> v = const {}]) => addonText(k, locale, v);
    Widget line(String text, {bool muted = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(text,
              style: style.copyWith(
                  fontSize: 13.5,
                  height: 1.45,
                  color: muted ? scheme.onSurfaceVariant : scheme.onSurface)),
        );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetCtx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          key: ValueKey('addon.details.${entry.id}'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(entry.label,
                style: style.copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(t('addonYourFile'),
                style: style.copyWith(fontSize: 12, color: scheme.primary)),
            const SizedBox(height: 14),
            if (entry.description.trim().isNotEmpty && !entry.legacy)
              line(entry.description.trim()),
            if (entry.declaredLanguage.isNotEmpty)
              line('${t('addonDetailLanguage')}: ${entry.declaredLanguage}', muted: true),
            if (entry.sourceFileName.isNotEmpty)
              line('${t('addonDetailSource')}: ${entry.sourceFileName}'
                  '${entry.sourceHash.isEmpty ? '' : '  (${entry.sourceHash})'}',
                  muted: true),
            if (entry.importedAtMs > 0)
              line('${t('addonDetailImported')}: '
                  '${DateTime.fromMillisecondsSinceEpoch(entry.importedAtMs).toLocal().toString().substring(0, 16)}',
                  muted: true),
            if (entry.legacy) line(t('addonLegacy'), muted: true),
            if (entry.strongsPresent) line(t('addonStrongsNote'), muted: true),
            if (entry.versification == AddonVersification.russianPsalms)
              line(t('addonRussianNote'), muted: true),
            line(t('addonShownAsIs'), muted: true),
            line(addonText('aboutLicenseUserSupplied', locale), muted: true),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey('addon.details.read'),
              onPressed: entry.enabled
                  ? () {
                      Navigator.of(sheetCtx).pop();
                      readAddonNow(context, entry);
                    }
                  : null,
              icon: const Icon(Icons.menu_book_rounded),
              label: Text(t('addonRead')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('addon.details.remove'),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: sheetCtx,
                  builder: (d) => AlertDialog(
                    title: Text(t('addonRemoveTitle', {'name': entry.label})),
                    content: Text(t('addonRemoveBody')),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(d, false),
                          child: Text(t('addonCancel'))),
                      FilledButton(
                          key: const ValueKey('addon.remove.confirm'),
                          onPressed: () => Navigator.pop(d, true),
                          child: Text(t('addonRemoveConfirm'))),
                    ],
                  ),
                );
                if (ok == true && sheetCtx.mounted) {
                  Navigator.of(sheetCtx).pop();
                  if (context.mounted) await removeAddon(context, entry);
                }
              },
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(t('addonRemove')),
            ),
          ],
        ),
      ),
    );
  }
}
