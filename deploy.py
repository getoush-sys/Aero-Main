#!/usr/bin/env python3
"""
Aero build + deploy automation.

Steps:
  1. Bundle       -> Output/Bundled.lua            (luabundler)
  2. Preprocess   -> Output/Preprocessed_Bundled.lua (Preprocessor.py, inlines timings)
  3. Minify       -> Output/Minified_Bundled.lua   (Minifier.py, strips comments + one line)
  4. Publish      -> dist/Aero.lua                 (the loadstring target)
  5. Commit + push to GitHub (origin/main)

Usage:
    python deploy.py                       # full run, commit + push
    python deploy.py -m "fixed X"          # custom commit message
    python deploy.py --no-push             # build + commit, no push
    python deploy.py --no-commit           # build only (updates dist/Aero.lua)
    python deploy.py                       # publish the preprocessed build
    python deploy.py --minify              # publish a minified build
    python deploy.py --no-minify           # compatibility alias for the default
    python deploy.py --no-squeeze          # minify but keep token spacing (safe mode)
    python deploy.py --volt                # also copy to the next Volt script slot

GitHub auth (needed for push): the script reads a token from, in order:
    1. env var  LUMA_GH_TOKEN
    2. a file   .deploy_token  next to this script (git-ignored)
The token is used only to build the push URL; it is never written to git config.
"""

import argparse
import datetime
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ROOT)
import Minifier  # local, pure-stdlib module (sibling of this script)

GITHUB_USER = "PlanetCatYT"
GITHUB_REPO = "Aero"
GITHUB_BRANCH = "main"

BUNDLED = os.path.join(ROOT, "Output", "Bundled.lua")
PREPROCESSED = os.path.join(ROOT, "Output", "Preprocessed_Bundled.lua")
MINIFIED = os.path.join(ROOT, "Output", "Minified_Bundled.lua")
DIST = os.path.join(ROOT, "dist", "Aero.lua")
TIMING_FILE = os.path.join(ROOT, "Timings", "truth.txt")

VOLT_DIR = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Volt", "scripts")


def log(msg):
    print(f"[deploy] {msg}", flush=True)


def die(msg, code=1):
    print(f"[deploy] ERROR: {msg}", file=sys.stderr, flush=True)
    sys.exit(code)


def run(cmd, **kwargs):
    """Run a command in ROOT, streaming output; raise on non-zero exit."""
    log("$ " + (cmd if isinstance(cmd, str) else " ".join(cmd)))
    result = subprocess.run(cmd, cwd=ROOT, **kwargs)
    if result.returncode != 0:
        die(f"command failed (exit {result.returncode})")
    return result


def bundle():
    log("bundling...")
    # luabundler is a global npm bin (luabundler.cmd on Windows); shell=True resolves it.
    run(
        'luabundler bundle Main.lua -p "./?.lua" -p "./?/init.lua" -p "./lib/?.lua" -o "Output/Bundled.lua"',
        shell=True,
    )
    if not os.path.exists(BUNDLED):
        die("Output/Bundled.lua was not produced")
    log(f"bundled ({os.path.getsize(BUNDLED)} bytes)")


def preprocess():
    log("preprocessing...")
    if not os.path.exists(TIMING_FILE):
        die(f"timing file missing: {TIMING_FILE}")
    run(
        [sys.executable, "Preprocessor.py", "-i", "Output/Bundled.lua", "--timing-file", TIMING_FILE],
    )
    if not os.path.exists(PREPROCESSED):
        die("Output/Preprocessed_Bundled.lua was not produced")
    log(f"preprocessed ({os.path.getsize(PREPROCESSED)} bytes)")


def minify(squeeze=True):
    log("minifying...")
    if not os.path.exists(PREPROCESSED):
        die(f"preprocessed file missing: {PREPROCESSED}")
    in_len, out_len, comments, nls, _ = Minifier.minify_file(
        PREPROCESSED, MINIFIED, squeeze=squeeze
    )
    pct = (1 - out_len / in_len) * 100 if in_len else 0
    extra = f", {nls} directive newline(s) kept" if nls else ""
    log(
        f"minified ({in_len:,} -> {out_len:,} bytes, -{pct:.1f}%, "
        f"{comments:,} comments stripped{extra})"
    )
    return MINIFIED


def publish_dist(source=PREPROCESSED):
    os.makedirs(os.path.dirname(DIST), exist_ok=True)
    shutil.copyfile(source, DIST)
    log(f"published dist/Aero.lua ({os.path.getsize(DIST)} bytes)")


def deploy_volt(source=PREPROCESSED):
    if not os.path.isdir(VOLT_DIR):
        log(f"volt dir not found ({VOLT_DIR}); skipping volt deploy")
        return
    nums = []
    for name in os.listdir(VOLT_DIR):
        m = re.match(r"Preprocessed_Bundled (\d+)\.lua$", name)
        if m:
            nums.append(int(m.group(1)))
    slot = (max(nums) + 1) if nums else 1
    target = os.path.join(VOLT_DIR, f"Preprocessed_Bundled {slot}.lua")
    shutil.copyfile(source, target)
    log(f"deployed to Volt slot {slot}")


def get_token():
    token = os.environ.get("LUMA_GH_TOKEN")
    if token:
        return token.strip()
    token_file = os.path.join(ROOT, ".deploy_token")
    if os.path.exists(token_file):
        with open(token_file, "r", encoding="utf-8") as f:
            return f.read().strip()
    return None


def git(*args, capture=False):
    return subprocess.run(
        ["git", *args], cwd=ROOT,
        capture_output=capture, text=True,
    )


def commit_and_push(message, do_push):
    # Stage everything (junk is excluded by .gitignore).
    git("add", "-A")

    status = git("status", "--porcelain", capture=True)
    if not status.stdout.strip():
        log("no changes to commit")
    else:
        run(["git", "commit", "-m", message])
        log("committed")

    if not do_push:
        log("skipping push (--no-push)")
        return

    token = get_token()
    if not token:
        die(
            "no GitHub token found. Set env var LUMA_GH_TOKEN or create a .deploy_token "
            "file next to this script (it is git-ignored)."
        )
    push_url = f"https://{GITHUB_USER}:{token}@github.com/{GITHUB_USER}/{GITHUB_REPO}.git"
    # Pass the URL directly so the token never lands in git config or the remote.
    result = subprocess.run(["git", "push", push_url, GITHUB_BRANCH], cwd=ROOT)
    if result.returncode != 0:
        die("git push failed")
    log(f"pushed to {GITHUB_USER}/{GITHUB_REPO}@{GITHUB_BRANCH}")


def main():
    parser = argparse.ArgumentParser(description="Aero build + deploy")
    parser.add_argument("-m", "--message", help="commit message")
    parser.add_argument("--no-commit", action="store_true", help="build only, do not commit")
    parser.add_argument("--no-push", action="store_true", help="commit but do not push")
    minify_group = parser.add_mutually_exclusive_group()
    minify_group.add_argument("--minify", action="store_true", help="minify before publishing")
    minify_group.add_argument("--no-minify", action="store_true", help="keep preprocessed output (default)")
    parser.add_argument("--no-squeeze", action="store_true", help="minify but keep token spacing")
    parser.add_argument("--volt", action="store_true", help="also copy to the next Volt slot")
    args = parser.parse_args()

    bundle()
    preprocess()
    if args.minify:
        source = minify(squeeze=not args.no_squeeze)
    else:
        source = PREPROCESSED
    publish_dist(source)
    if args.volt:
        deploy_volt(source)

    if args.no_commit:
        log("done (build only)")
        return

    message = args.message or f"Build {datetime.datetime.now():%Y-%m-%d %H:%M:%S}"
    commit_and_push(message, do_push=not args.no_push)
    log("done")


if __name__ == "__main__":
    main()
