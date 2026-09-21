#!/usr/bin/env python3
"""Partition test/**/*_test.dart into foreground-sized chunks and run one.

    python3 tools/run_test_chunks.py --list --of 6     # human report
    python3 tools/run_test_chunks.py --json --of 6      # machine-readable
    python3 tools/run_test_chunks.py --check            # coverage gate, no flutter needed
    python3 tools/run_test_chunks.py --chunk 0 --of 6    # run chunk 0 in the foreground

Why this exists
----------------
docs/autonomous-queue.md's `queue:19259` (P3, "known but blocked or
deferred") records four recurrences of the same failure: an autonomous
`claude -p` iteration runs `flutter test` for the whole suite, the call
runs long enough to auto-background under the harness's default Bash
timeout, and the stage ends its turn "waiting for the notification" —
except a one-shot `claude -p` invocation has no later turn for that
notification to arrive into, so the work sits uncommitted until a later
hour's iteration finds and lands it. The item's own recorded fix is to
run the suite as foreground chunks small enough to never hit that
timeout, and to check the exit code of each chunk before moving on. This
tool exists so that chunking is computed once, deterministically, and
checked into the repo, instead of every iteration re-deriving a file
list under time pressure — which is the exact moment reaching for a
background call is tempting.

This tool does not, on its own, stop a future iteration from
backgrounding `flutter test` anyway; the trigger for that lives in the
loop's own prompt/orchestration outside this repo (see queue:19259's
own text). What it removes is the per-iteration reinvention of the
chunking itself.

Chunk sizing is a heuristic, not a guarantee
---------------------------------------------
Chunks are balanced by each file's byte size on disk, used as a proxy
for how long that file's tests take to run. Byte size is not runtime —
a short file with one slow corpus-sweep test can dominate a chunk's
actual wall-clock time despite being small on disk. This tool does not
measure or claim per-file runtimes; if a chunk still risks the harness
timeout in practice, increase `--of` rather than trusting the proxy.

Deliberately not pinned here: how many test files exist, or how long
the full suite takes to run. Both drift as the suite grows, and pinning
either in a docstring, a test, or CI is exactly the mistake this file's
own sibling tools warn against (see tools/queue_open_items.py's
docstring for the general pattern, and queue:19259 for this specific
one: a stated "~11.5 min" and a "120 files" chunk both went stale under
the tree).
"""
import argparse
import glob
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEST_DIR = os.path.join(ROOT, "test")


def discover(test_dir=TEST_DIR):
    """Return sorted repo-relative paths of every test/**/*_test.dart file."""
    pattern = os.path.join(test_dir, "**", "*_test.dart")
    paths = glob.glob(pattern, recursive=True)
    rel = [os.path.relpath(p, ROOT) for p in paths]
    return sorted(rel)


def partition(files, n, sizer=None):
    """Split `files` into `n` chunks, greedy largest-first bin-packing by
    byte size, so a handful of large files spread across chunks instead of
    clustering together. Deterministic: ties break on path (the input
    order after the initial size-descending sort), so two calls on the
    same input always produce the same partition.

    `sizer` defaults to os.path.getsize (repo-relative paths resolved
    against ROOT); tests pass a synthetic dict lookup instead so they
    never touch the filesystem.

    Returns a list of `n` lists (some may be empty if n > len(files)).
    """
    if n < 1:
        raise ValueError("n must be >= 1")

    def size_of(path):
        if sizer is not None:
            return sizer(path)
        return os.path.getsize(os.path.join(ROOT, path))

    ordered = sorted(files, key=lambda p: (-size_of(p), p))
    chunks = [[] for _ in range(n)]
    totals = [0] * n
    for path in ordered:
        i = min(range(n), key=lambda k: (totals[k], k))
        chunks[i].append(path)
        totals[i] += size_of(path)
    for chunk in chunks:
        chunk.sort()
    return chunks


def render_report(chunks):
    lines_out = []
    for i, chunk in enumerate(chunks):
        lines_out.append(f"chunk {i}/{len(chunks)} ({len(chunk)} file(s)):")
        for path in chunk:
            lines_out.append(f"    {path}")
    return "\n".join(lines_out)


def check_partition(files, chunks):
    """Assert every discovered file appears exactly once across chunks, no
    file is duplicated, and no chunk is empty. Returns (ok, message)."""
    seen = {}
    for i, chunk in enumerate(chunks):
        if not chunk:
            return False, f"chunk {i} is empty"
        for path in chunk:
            if path in seen:
                return False, f"{path} appears in both chunk {seen[path]} and chunk {i}"
            seen[path] = i
    missing = sorted(set(files) - set(seen))
    if missing:
        return False, f"{len(missing)} file(s) missing from the partition, e.g. {missing[0]}"
    extra = sorted(set(seen) - set(files))
    if extra:
        return False, f"{len(extra)} file(s) in the partition but not discovered, e.g. {extra[0]}"
    return True, "ok"


def run_chunk(chunk, index, total, flutter_bin="flutter"):
    """Run one chunk's files through `flutter test --reporter compact` in
    the foreground, returning the subprocess exit code."""
    if not chunk:
        print(f"CHUNK {index}/{total}: PASS (empty)")
        return 0
    cmd = [flutter_bin, "test", "--reporter", "compact"] + chunk
    proc = subprocess.run(cmd, cwd=ROOT)
    status = "PASS" if proc.returncode == 0 else "FAIL"
    print(f"CHUNK {index}/{total}: {status}")
    return proc.returncode


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--of", type=int, default=6, help="number of chunks")
    parser.add_argument("--chunk", type=int, help="run only this 0-indexed chunk")
    parser.add_argument("--list", action="store_true", help="print the partition, run nothing")
    parser.add_argument("--json", action="store_true", help="machine-readable partition")
    parser.add_argument(
        "--check",
        action="store_true",
        help="exit 1 unless the partition covers every discovered file exactly once",
    )
    parser.add_argument("--flutter-bin", default="flutter", help=argparse.SUPPRESS)
    args = parser.parse_args(argv)

    if args.of < 1:
        print("run_test_chunks: --of must be >= 1", file=sys.stderr)
        return 2

    files = discover()
    chunks = partition(files, args.of)

    if args.check:
        ok, message = check_partition(files, chunks)
        if not ok:
            print(f"run_test_chunks --check: FAIL ({message})", file=sys.stderr)
            return 1
        print(f"run_test_chunks --check: OK ({len(files)} file(s) across {args.of} chunk(s))")
        return 0

    if args.json:
        print(json.dumps(chunks, indent=2))
        return 0

    if args.list:
        print(render_report(chunks))
        return 0

    if args.chunk is None:
        print("run_test_chunks: --chunk is required unless --list/--json/--check", file=sys.stderr)
        return 2
    if not (0 <= args.chunk < args.of):
        print(f"run_test_chunks: --chunk must be in [0, {args.of})", file=sys.stderr)
        return 2

    return run_chunk(chunks[args.chunk], args.chunk, args.of, flutter_bin=args.flutter_bin)


if __name__ == "__main__":
    sys.exit(main())
