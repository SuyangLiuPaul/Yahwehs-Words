#!/usr/bin/env python3
"""List the GENUINELY open `- [ ]` items in docs/autonomous-queue.md.

    python3 tools/queue_open_items.py           # human report
    python3 tools/queue_open_items.py --json    # machine-readable
    python3 tools/queue_open_items.py --check   # exit 1 on structural anomaly

Why this exists
----------------
The queue keeps closed-out write-ups as kept records inside `<details>`
blocks, complete with their original `- [ ]` checkbox left unticked on
purpose (the live outcome is a separate `[x]` entry above the block, not an
edit to the archived text). A planning pass that just greps for `- [ ]`
cannot tell the two apart, and it has actually dispatched work against an
archived copy three times: a whole feature built without authority on
2026-09-03 against the archived chronology-chart item, and three more hourly
iterations (`c264f210`, `9cad9aff`, `1f91bdf5`) planned against the same
archived line on 2026-09-20/21. See the `[x]` entry beginning "An
interactive Bible chronology chart" in docs/autonomous-queue.md's P3
section for the full incident trail in the queue's own words (its line
number moves as the file grows; grep for the quoted text rather than trust
a cached line number).

The trap is not "does the line contain `<details>`". That same entry's own
note about this trap mentions the tag in backticks, in prose, several
times — a counter that increments on any line *containing* the substring
would misread those prose sentences as structural and end the file
unbalanced, hiding real open items that happen to sit after that note. A
tag is only structural when it OPENS the line:
`line.lstrip().startswith('<details')` / `'</details>'`.
"""
import argparse
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QUEUE_PATH = os.path.join(ROOT, "docs", "autonomous-queue.md")

# The user's work order (2026-08-24), not file order. See queue:49-72.
TIER_ORDER = [
    "BUGS — reported by the user from their own devices",
    "P2 — features the user asked for",
    "P3 — known but blocked or deferred",
    "P1 — Bible study correctness",
    "P0 — scripture accuracy",
    "Blocked on the user — do not attempt",
]

HEADING_RE = re.compile(r"^##\s+(.+?)\s*$")
OPEN_ITEM_RE = re.compile(r"^- \[ \]")


def parse(lines):
    """Walk the file once, tracking structural `<details>` depth and the
    current `## ` heading. Returns (open_items, archived_items, max_depth,
    final_depth), where each item is {line, heading, text}.
    """
    open_items = []
    archived_items = []
    heading = None
    depth = 0
    max_depth = 0
    for i, raw in enumerate(lines, start=1):
        stripped = raw.lstrip()
        m = HEADING_RE.match(raw)
        if m:
            heading = m.group(1)
        if stripped.startswith("<details"):
            depth += 1
            max_depth = max(max_depth, depth)
            continue
        if stripped.startswith("</details>"):
            depth -= 1
            continue
        if OPEN_ITEM_RE.match(raw):
            item = {"line": i, "heading": heading, "text": raw.rstrip("\n")}
            if depth > 0:
                archived_items.append(item)
            else:
                open_items.append(item)
    return open_items, archived_items, max_depth, depth


def load_lines(path=QUEUE_PATH):
    with open(path, encoding="utf-8") as f:
        return f.readlines()


def tier_rank(heading):
    if heading is None:
        return len(TIER_ORDER)
    for i, tier in enumerate(TIER_ORDER):
        if heading == tier or heading.startswith(tier.split(" — ")[0]):
            return i
    return len(TIER_ORDER)


def ordered_by_tier(items):
    return sorted(items, key=lambda it: (tier_rank(it["heading"]), it["line"]))


def render_report(open_items, archived_items, final_depth):
    lines_out = []
    ordered = ordered_by_tier(open_items)
    lines_out.append(f"OPEN — {len(open_items)} item(s), in work order:")
    last_heading = object()
    for it in ordered:
        if it["heading"] != last_heading:
            lines_out.append(f"  ## {it['heading']}")
            last_heading = it["heading"]
        lines_out.append(f"    queue:{it['line']}: {it['text'][:100]}")
    lines_out.append("")
    lines_out.append(f"ARCHIVED — {len(archived_items)} item(s) inside <details>, not backlog:")
    for it in sorted(archived_items, key=lambda x: x["line"]):
        lines_out.append(f"    queue:{it['line']}: {it['text'][:100]}")
    lines_out.append("")
    lines_out.append(f"structural <details> depth at EOF: {final_depth}")
    return "\n".join(lines_out)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    parser.add_argument(
        "--check",
        action="store_true",
        help="exit 1 if structural <details> depth ever goes negative or "
        "does not return to 0 at EOF",
    )
    parser.add_argument("--path", default=QUEUE_PATH, help=argparse.SUPPRESS)
    args = parser.parse_args(argv)

    lines = load_lines(args.path)
    open_items, archived_items, max_depth, final_depth = parse(lines)

    # Re-derive whether depth ever went negative (parse() doesn't report
    # this directly; walk once more, cheaply, for --check's own invariant).
    depth = 0
    went_negative = False
    for raw in lines:
        stripped = raw.lstrip()
        if stripped.startswith("<details"):
            depth += 1
        elif stripped.startswith("</details>"):
            depth -= 1
            if depth < 0:
                went_negative = True

    if args.check:
        ok = (not went_negative) and final_depth == 0
        if not ok:
            print(
                f"queue_open_items --check: structural <details> imbalance "
                f"(final depth {final_depth}, went_negative={went_negative})",
                file=sys.stderr,
            )
            return 1
        print(
            f"queue_open_items --check: OK "
            f"({len(open_items)} open, {len(archived_items)} archived, depth balanced)"
        )
        return 0

    if args.json:
        print(
            json.dumps(
                {
                    "open": ordered_by_tier(open_items),
                    "archived": sorted(archived_items, key=lambda x: x["line"]),
                    "final_depth": final_depth,
                    "went_negative": went_negative,
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0

    print(render_report(open_items, archived_items, final_depth))
    return 0


if __name__ == "__main__":
    sys.exit(main())
