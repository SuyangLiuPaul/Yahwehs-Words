#!/usr/bin/env python3
"""Copy the add-on importer's SHARED files from Words into Sword.

The importer's pure-Dart half (parsers, SQLite reader, normaliser), its model,
store and registry are identical in both apps except for the package prefix
(`yahwehs_words` ↔ `yahwehs_sword`). Words is where they are edited; this
copies them across so the two cannot drift, and `--check` fails when they have.

NOT shared, because the two apps look different and differ in what surrounds
them: the Add-ons page, the import sheet, the catalog wiring in
`bible_versions.dart`, `addon_store_config.dart` (Sword keeps its old
IndexedDB database name so earlier imports survive the upgrade), and
`test/addons/addon_integration_test.dart` and `test/addons/addons_ui_test.dart`
(each app tests its own catalog and its own screens).

    python3 tools/sync_addon_files.py            # copy
    python3 tools/sync_addon_files.py --check    # fail on drift
"""
import os
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SWORD = os.path.join(os.path.dirname(HERE), "Sword-study-english-20261015")

SHARED = [
    "lib/models/addon.dart",
    "lib/utils/addons/addon_canon.dart",
    "lib/utils/addons/addon_payload.dart",
    "lib/utils/addons/addon_texts.dart",
    "lib/utils/addons/addon_types.dart",
    "lib/utils/addons/book_name_resolver.dart",
    "lib/utils/addons/canon_fit.dart",
    "lib/utils/addons/markup_normaliser.dart",
    "lib/utils/addons/mybible_book_numbers.dart",
    "lib/utils/addons/parse_module.dart",
    "lib/utils/addons/parse_mybible.dart",
    "lib/utils/addons/parse_mysword.dart",
    "lib/utils/addons/parse_plain.dart",
    "lib/utils/addons/parse_support.dart",
    "lib/utils/addons/parse_theword.dart",
    "lib/utils/addons/parse_zefania.dart",
    "lib/utils/addons/sqlite_reader.dart",
    "lib/utils/pick_module_file.dart",
    "lib/services/addons/addon_import_service.dart",
    "lib/services/addons/addon_registry.dart",
    "lib/services/addons/addon_store.dart",
    "lib/services/addons/addon_store_backend.dart",
    "lib/services/addons/addon_store_io.dart",
    "lib/services/addons/addon_store_web.dart",
    "tools/make_addon_fixtures.py",
    "tools/gen_addon_canon.py",
    "test/addons/sqlite_reader_test.dart",
    "test/addons/sqlite_reader_hostile_test.dart",
    "test/addons/markup_normaliser_test.dart",
    "test/addons/parsers_test.dart",
    "test/addons/mybible_book_numbers_test.dart",
    "test/addons/canon_fit_test.dart",
    "test/addons/addon_canon_test.dart",
]
FIXTURE_DIR = "test/fixtures/addons"


def convert(text):
    return text.replace("yahwehs_words", "yahwehs_sword")


def main():
    check = "--check" in sys.argv
    drift = []
    files = list(SHARED)
    for n in sorted(os.listdir(os.path.join(HERE, FIXTURE_DIR))):
        files.append(f"{FIXTURE_DIR}/{n}")
    for rel in files:
        src = os.path.join(HERE, rel)
        dst = os.path.join(SWORD, rel)
        data = open(src, "rb").read()
        if rel.endswith((".dart", ".py")):
            data = convert(data.decode("utf-8")).encode("utf-8")
        cur = open(dst, "rb").read() if os.path.exists(dst) else None
        if cur != data:
            drift.append(rel)
            if not check:
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                open(dst, "wb").write(data)
    if check:
        if drift:
            print("Sword's add-on files drifted from Words':", *drift, sep="\n  ")
            sys.exit(1)
        print(f"{len(files)} shared add-on files match")
    else:
        print(f"copied {len(drift)} of {len(files)} files to {SWORD}")


if __name__ == "__main__":
    main()
