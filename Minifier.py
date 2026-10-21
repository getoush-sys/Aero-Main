#!/usr/bin/env python3
"""
Lua / Luau source minifier.

Strips comments and collapses the whole script to a single line, WITHOUT
breaking string literals. It is a real tokenizer pass, not a regex substitution:
it walks the source, keeps every string literal verbatim (short "..."/'...' and
long [[ ]] / [=[ ]=]), and only removes the `--` line comments and `--[[ ]]`
block comments that are genuinely comments -- so a `--` inside "a--b" or a
[[ long -- string ]] survives untouched.

Two modes:
  squeeze=True  (default)  also removes the spaces between tokens that cannot
                           fuse. It KEEPS the ones that must stay: between two
                           words (`local x`), where it would form a `--`
                           (`a - -b`), a `[[`, or a numeric concat (`1 .. 2`).
  squeeze=False            comments stripped + everything on one line, but every
                           space between tokens is left in place (bulletproof,
                           slightly larger output).

Luau mode directives (`--!native`, `--!optimize`, `--!strict`, ...) are kept on
their own line so a top-of-chunk directive keeps working.

CLI:
    python Minifier.py -i Output/Preprocessed_Bundled.lua -o dist/Aero.lua
    python Minifier.py -i in.lua                 # -> stdout
    python Minifier.py -i in.lua --no-squeeze
"""

import argparse
import sys

_WS = " \t\r\n\f\v"


def _is_word(c):
    return c != "" and (
        ("a" <= c <= "z") or ("A" <= c <= "Z") or ("0" <= c <= "9") or c == "_"
    )


def _is_digit(c):
    return c != "" and "0" <= c <= "9"


def minify(src, squeeze=True):
    """Return (minified_text, comments_stripped, newlines_kept)."""
    n = len(src)
    out = []        # finished string parts
    buf = []        # current run of emitted code chars (flushed as one part)
    comments = 0
    kept_newlines = 0

    state = {"prev": "", "pending": False}  # last emitted char; unresolved space

    def flush_buf():
        if buf:
            out.append("".join(buf))
            buf.clear()

    def resolve(right):
        # Decide what to do with a pending (collapsed) space before char `right`.
        if not state["pending"]:
            return
        state["pending"] = False
        prev = state["prev"]
        if prev == "" or right == "":
            return  # leading / trailing -> drop
        if squeeze:
            keep = (
                (_is_word(prev) and _is_word(right))        # two words would fuse
                or (prev == "-" and right == "-")           # would form a -- comment
                or (prev == "[" and right == "[")           # would form a [[ long string
                or (prev == "." and (_is_digit(right) or right == "."))  # numeric concat
                or (right == "." and (_is_digit(prev) or prev == "."))
            )
        else:
            keep = True
        if keep:
            buf.append(" ")
            state["prev"] = " "

    def emit_code_char(c):
        resolve(c)
        buf.append(c)
        state["prev"] = c

    def emit_protected(text):
        if not text:
            return
        resolve(text[0])
        flush_buf()
        out.append(text)
        state["prev"] = text[-1]

    i = 0
    while i < n:
        c = src[i]

        # ---- short string  "..."  '...' ----
        if c == '"' or c == "'":
            q = c
            j = i + 1
            while j < n:
                d = src[j]
                if d == "\\":           # escape: skip backslash + next char
                    j += 2
                    continue
                j += 1
                if d == q or d == "\n":  # closing quote (or unterminated at EOL)
                    break
            emit_protected(src[i:j])
            i = j
            continue

        # ---- long bracket string  [[ ]] / [=[ ]=] ----
        if c == "[":
            k = i + 1
            eq = 0
            while k < n and src[k] == "=":
                eq += 1
                k += 1
            if k < n and src[k] == "[":
                close = "]" + "=" * eq + "]"
                end = src.find(close, k + 1)
                end = n if end == -1 else end + len(close)
                emit_protected(src[i:end])
                i = end
                continue
            emit_code_char("[")          # just an indexing bracket
            i += 1
            continue

        # ---- comments ----
        if c == "-" and i + 1 < n and src[i + 1] == "-":
            p = i + 2
            # block comment --[[ ]] / --[=[ ]=]
            if p < n and src[p] == "[":
                k = p + 1
                eq = 0
                while k < n and src[k] == "=":
                    eq += 1
                    k += 1
                if k < n and src[k] == "[":
                    close = "]" + "=" * eq + "]"
                    end = src.find(close, k + 1)
                    i = n if end == -1 else end + len(close)
                    comments += 1
                    state["pending"] = True   # acts as whitespace separator
                    continue
            # line comment
            nl = src.find("\n", p)
            line_end = n if nl == -1 else nl
            if p < n and src[p] == "!":
                # Luau directive -> keep it on its own line
                directive = src[i:line_end].rstrip("\r")
                emit_protected("\n" + directive + "\n")
                kept_newlines += 2
            else:
                comments += 1
                state["pending"] = True
            i = line_end
            continue

        # ---- whitespace ----
        if c in _WS:
            state["pending"] = True
            i += 1
            continue

        # ---- ordinary code char ----
        emit_code_char(c)
        i += 1

    flush_buf()
    return "".join(out), comments, kept_newlines


def minify_file(inp, outp=None, squeeze=True):
    """Minify file `inp`; write to `outp` if given, else return the text.
    Returns (in_len, out_len, comments, newlines_kept)."""
    with open(inp, "r", encoding="utf-8", errors="surrogateescape") as f:
        src = f.read()
    text, comments, nls = minify(src, squeeze=squeeze)
    if outp is not None:
        with open(outp, "w", encoding="utf-8", errors="surrogateescape", newline="") as f:
            f.write(text)
    return len(src), len(text), comments, nls, text


def main():
    ap = argparse.ArgumentParser(
        description="Strip comments and collapse a Lua/Luau script to one line."
    )
    ap.add_argument("-i", "--input", required=True)
    ap.add_argument("-o", "--output", help="output file (default: stdout)")
    ap.add_argument(
        "--no-squeeze",
        action="store_true",
        help="keep all token spacing (only strip comments + newlines)",
    )
    args = ap.parse_args()

    in_len, out_len, comments, nls, text = minify_file(
        args.input, args.output, squeeze=not args.no_squeeze
    )
    if args.output:
        pct = (1 - out_len / in_len) * 100 if in_len else 0
        sys.stderr.write(
            f"[minify] {in_len:,} -> {out_len:,} bytes (-{pct:.1f}%), "
            f"{comments:,} comments stripped"
            + (f", {nls} directive newline(s) kept" if nls else "")
            + "\n"
        )
    else:
        sys.stdout.write(text)


if __name__ == "__main__":
    main()
