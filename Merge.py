#!/usr/bin/env python3
"""
Merge.py

CLI to merge two timing files with two modes:
  1) Add New Timings           -> add      (only add entries that don't exist)
  2) Overwrite and Add Everything -> overwrite (replace existing entries and add new ones)

Files are msgpack-encoded dicts with containers like: animation, effect, part, sound.
Keys for items are resolved similarly to WorkspaceSync:
  - part: use 'pname'
  - others: use '_id' or fallback to 'name'

Usage:
  python Merge.py <source_file> <target_file> <mode> [--output <out_file>]

If --output is omitted, the target file is overwritten in-place.
"""

import argparse
import os
import sys
import msgpack
import json
from typing import Any, Dict, Tuple


EXPECTED_CONTAINERS = ("animation", "effect", "part", "sound")


def load_data(path: str) -> Any:
	if not path or not os.path.exists(path) or os.path.getsize(path) == 0:
		return {}
	try:
		with open(path, "rb") as f:
			return msgpack.load(f, raw=False)
	except Exception:
		# Try JSON as a fallback for debugging/migration cases
		try:
			with open(path, "r", encoding="utf-8") as f:
				return json.load(f)
		except Exception:
			return {}


def save_data(data, path: str):
	os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
	with open(path, "wb") as f:
		msgpack.dump(data, f)


def get_timing_key(timing: dict, container_name: str):
	if not isinstance(timing, dict):
		return None
	if container_name == "part":
		return timing.get("pname")
	return timing.get("_id") or timing.get("name")


def index_list(items, container):
	idx = {}
	ordered = []
	if isinstance(items, list):
		for it in items:
			if isinstance(it, dict):
				k = get_timing_key(it, container)
				if k is not None:
					idx[k] = it
					ordered.append(k)
	return idx, ordered


def merge_data(src: Any, dst: Any, mode: str) -> Tuple[Dict, Dict[str, int]]:
	"""Merge src into dst. Returns merged dict and counters.

	Counters: added, replaced, kept
	"""
	if not isinstance(dst, dict):
		dst = {}
	if not isinstance(src, dict):
		src = {}

	added = 0
	replaced = 0
	kept = 0

	# Ensure all expected containers exist in dst
	for c in EXPECTED_CONTAINERS:
		if c not in dst or not isinstance(dst.get(c), list):
			dst[c] = []

	for container in EXPECTED_CONTAINERS:
		s_list = src.get(container, [])
		d_list = dst.get(container, [])
		d_index, d_order = index_list(d_list, container)

		if not isinstance(s_list, list):
			continue

		for s in s_list:
			if not isinstance(s, dict):
				continue
			key = get_timing_key(s, container)
			if key is None:
				continue

			if key in d_index:
				# exists
				if mode == "overwrite":
					# replace in-place where it appears
					# find position to keep stable order if possible
					try:
						pos = d_order.index(key)
					except ValueError:
						pos = None
					if pos is not None:
						d_list[pos] = s
					else:
						# fallback: rewrite the first matching by identity
						for i, it in enumerate(d_list):
							if get_timing_key(it, container) == key:
								d_list[i] = s
								break
					d_index[key] = s
					replaced += 1
				else:
					# add-only mode
					kept += 1
			else:
				# new entry
				d_list.append(s)
				d_index[key] = s
				d_order.append(key)
				added += 1

		dst[container] = d_list

	return dst, {"added": added, "replaced": replaced, "kept": kept}


def parse_args(argv):
	p = argparse.ArgumentParser(description="Merge two timing files")
	p.add_argument("source", help="Source timing file (msgpack)")
	p.add_argument("target", help="Target timing file to merge into (msgpack)")
	p.add_argument(
		"mode",
		help=(
			"Merge mode: 'add'|'overwrite' or phrases "
			"'Add New Timings'|'Overwrite and Add Everything'"
		),
	)
	p.add_argument("--output", "-o", help="Output file (default: overwrite target)")
	return p.parse_args(argv)


def normalize_mode(mode: str) -> str:
	m = (mode or "").strip().lower()
	if m in ("add", "1", "add new timings"):
		return "add"
	if m in ("overwrite", "2", "overwrite and add everything"):
		return "overwrite"
	# try to map common variations
	if "overwrite" in m:
		return "overwrite"
	if "add" in m:
		return "add"
	raise ValueError(
		"Invalid mode. Use 'add'|'overwrite' or 'Add New Timings'|'Overwrite and Add Everything'"
	)


def main(argv=None):
	args = parse_args(argv or sys.argv[1:])
	try:
		args.mode = normalize_mode(args.mode)
	except ValueError as e:
		print(f"Error: {e}")
		return 2

	src = load_data(args.source)
	dst = load_data(args.target)

	merged, stats = merge_data(src, dst, args.mode)

	out_path = args.output or args.target
	save_data(merged, out_path)

	print(
		(
			f"[Merge] Mode={args.mode} | Source='{os.path.abspath(args.source)}' "
			f"-> Target='{os.path.abspath(args.target)}' -> Output='{os.path.abspath(out_path)}'\n"
			f"         Added={stats['added']} Replaced={stats['replaced']} Kept={stats['kept']}"
		)
	)


if __name__ == "__main__":
	sys.exit(main())

