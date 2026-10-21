#!/usr/bin/env python3
"""THANKS CLAUDE!!!!!!!!!

A user clicks **Export Timings** in the Builder > General tab, which copies ONE line to their
clipboard. They send you that line. Run this, paste it, review exactly what will change,
confirm, and it updates truth.txt (the baked-in timing database) and the Modules/ source
folder. A snapshot of the previous state is saved under TimingHistory/ so you can revert.

Usage:
    python ImportTimings.py                 # prompts you to paste the export line
    python ImportTimings.py export.txt      # read the line from a file instead
    python ImportTimings.py --truth PATH    # point at the truth.txt you build with
    python ImportTimings.py --yes           # skip the confirmation prompt

Requires the 'msgpack' package (same one Preprocessor.py uses): pip install msgpack
"""
import argparse
import base64
import json
import os
import shutil
import sys
from datetime import datetime

try:
    import msgpack
except ImportError:
    msgpack = None

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
# The truth.txt you build with. If you pass a different one to Preprocessor.py's
# --timing-file (e.g. an external apc-timings folder), set this or use --truth.
DEFAULT_TRUTH = os.path.join(SCRIPT_DIR, "Timings", "truth.txt")
MODULES_DIR = os.path.join(SCRIPT_DIR, "Modules")
GLOBALS_DIR = os.path.join(MODULES_DIR, "Globals")
HISTORY_DIR = os.path.join(SCRIPT_DIR, "TimingHistory")

# The field each timing type is keyed by (mirrors the Lua Timing:id() overrides).
ID_FIELD = {"animation": "_id", "sound": "_id", "part": "pname", "effect": "ename"}
CATEGORIES = ["animation", "effect", "part", "sound"]
PREFIX = "LUMA1:"


def die(msg):
    print("ERROR:", msg)
    sys.exit(1)


def read_input(args):
    if args.input:
        with open(args.input, "r", encoding="utf-8") as handle:
            return handle.read().strip()
    print("Paste the exported timing line, then press Enter:")
    return sys.stdin.readline().strip()


def decode_payload(line):
    line = line.strip()
    if line.startswith(PREFIX):
        line = line[len(PREFIX):]
    line = line.strip()
    if not line:
        die("No input given.")
    try:
        raw = base64.b64decode(line)
    except Exception as exc:  # noqa: BLE001
        die("Input is not valid base64 (%s). Did you copy the whole line?" % exc)
    try:
        return json.loads(raw.decode("utf-8"))
    except Exception as exc:  # noqa: BLE001
        die("Input did not decode to valid JSON (%s)." % exc)


def as_list(value):
    # Lua's JSON encodes an empty table as {} rather than []; treat non-lists as empty.
    return value if isinstance(value, list) else []


def load_truth(path):
    if not os.path.exists(path):
        print("Note: %s does not exist yet -- it will be created." % path)
        return {"version": 1, "animation": [], "effect": [], "part": [], "sound": []}
    if msgpack is None:
        die("The 'msgpack' package is required to read truth.txt. Run: pip install msgpack")
    with open(path, "rb") as handle:
        obj = msgpack.unpackb(handle.read(), raw=False)
    if not isinstance(obj, dict):
        die("truth.txt did not decode to a map.")
    return obj


def write_truth(path, obj):
    if msgpack is None:
        die("The 'msgpack' package is required to write truth.txt. Run: pip install msgpack")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(msgpack.packb(obj, use_bin_type=True))


def index_by_id(entries, id_field):
    out = {}
    for entry in entries:
        if isinstance(entry, dict) and id_field in entry:
            out[str(entry[id_field])] = entry
    return out


def module_diff(imported, base_dir):
    added, changed = [], []
    for name, source in imported.items():
        path = os.path.join(base_dir, name + ".lua")
        if not os.path.exists(path):
            added.append(name)
        else:
            with open(path, "r", encoding="utf-8", errors="replace") as handle:
                if handle.read() != source:
                    changed.append(name)
    return added, changed


def write_modules(imported, base_dir):
    if imported:
        os.makedirs(base_dir, exist_ok=True)
    for name, source in imported.items():
        with open(os.path.join(base_dir, name + ".lua"), "w", encoding="utf-8", newline="\n") as handle:
            handle.write(source)


def main():
    parser = argparse.ArgumentParser(description="Apply a Aero export string to truth.txt + Modules/.")
    parser.add_argument("input", nargs="?", help="File containing the export line (else you'll paste it).")
    parser.add_argument("--truth", default=DEFAULT_TRUTH, help="Path to truth.txt (default: %(default)s).")
    parser.add_argument("--yes", action="store_true", help="Skip the confirmation prompt.")
    args = parser.parse_args()

    payload = decode_payload(read_input(args))
    timings = payload.get("timings", {}) or {}
    imp_modules = payload.get("modules", {}) or {}
    imp_globals = payload.get("globals", {}) or {}
    if not isinstance(imp_modules, dict):
        imp_modules = {}
    if not isinstance(imp_globals, dict):
        imp_globals = {}

    truth = load_truth(args.truth)
    truth.setdefault("version", 1)
    for category in CATEGORIES:
        truth.setdefault(category, [])

    # Compute the timing diff + the merged result.
    plan = {}
    merged = {}
    for category in CATEGORIES:
        id_field = ID_FIELD[category]
        existing = index_by_id(as_list(truth.get(category)), id_field)
        incoming = index_by_id(as_list(timings.get(category)), id_field)
        added, changed = [], []
        result = dict(existing)
        for tid, entry in incoming.items():
            if tid not in existing:
                added.append(entry.get("name", tid))
            elif existing[tid] != entry:
                changed.append(entry.get("name", tid))
            result[tid] = entry
        merged[category] = result
        plan[category] = (added, changed)

    mod_added, mod_changed = module_diff(imp_modules, MODULES_DIR)
    glob_added, glob_changed = module_diff(imp_globals, GLOBALS_DIR)

    # Show the plan.
    print("\n=== Changes to apply ===")
    total = 0
    for category in CATEGORIES:
        added, changed = plan[category]
        if added or changed:
            total += len(added) + len(changed)
            print("\n[%s] +%d new, ~%d changed" % (category, len(added), len(changed)))
            for name in added:
                print("   + %s" % name)
            for name in changed:
                print("   ~ %s" % name)

    for label, added, changed in (
        ("modules", mod_added, mod_changed),
        ("globals", glob_added, glob_changed),
    ):
        if added or changed:
            total += len(added) + len(changed)
            print("\n[%s] +%d new, ~%d changed" % (label, len(added), len(changed)))
            for name in added:
                print("   + %s" % name)
            for name in changed:
                print("   ~ %s" % name)

    if total == 0:
        print("\nNothing to change -- everything is already up to date.")
        return

    print("\nTotal: %d change(s)." % total)
    if not args.yes:
        answer = input("Apply these changes? [y/N] ").strip().lower()
        if answer not in ("y", "yes"):
            print("Aborted. Nothing was changed.")
            return

    # Snapshot the current state for reverting.
    stamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    snapshot = os.path.join(HISTORY_DIR, stamp)
    os.makedirs(snapshot, exist_ok=True)
    if os.path.exists(args.truth):
        shutil.copy2(args.truth, os.path.join(snapshot, "truth.txt"))
    if os.path.isdir(MODULES_DIR):
        shutil.copytree(MODULES_DIR, os.path.join(snapshot, "Modules"), dirs_exist_ok=True)
    print("Saved snapshot to %s" % snapshot)

    # Apply.
    for category in CATEGORIES:
        truth[category] = list(merged[category].values())
    write_truth(args.truth, truth)
    print("Updated %s" % args.truth)

    write_modules(imp_modules, MODULES_DIR)
    write_modules(imp_globals, GLOBALS_DIR)
    print("Wrote %d module(s), %d global(s)." % (len(imp_modules), len(imp_globals)))

    print("\nDone. Rebuild (bundle + Preprocessor) to bake the new data in.")


if __name__ == "__main__":
    main()
