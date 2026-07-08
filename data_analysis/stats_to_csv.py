#!/usr/bin/env python3
"""Parse a *_stats.jsonl file (e.g. twitch_stats.jsonl or youtube_stats.jsonl)
into a CSV. Top-level fields and the nested "stats" object are flattened into
columns. Usage:

    python stats_to_csv.py <stats.jsonl> [output.csv]

If no output path is given, the CSV is written next to the input file with a
.csv extension.

Made with Claude Opus 4.3.
"""
import csv
import json
import sys


def flatten(record):
    """Flatten one JSONL record into a single-level dict of column -> value."""
    row = {}
    for key, value in record.items():
        if isinstance(value, dict):
            row.update(value)
        else:
            row[key] = value
    return row


def main():
    if len(sys.argv) < 3:
        sys.exit("usage: python stats_to_csv.py <stats.jsonl> [output.csv]")

    in_path = sys.argv[1]
    out_path = sys.argv[2] if len(sys.argv) > 2 else in_path.rsplit(".", 1)[0] + ".csv"

    rows = []
    with open(in_path) as f:
        for line_no, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(flatten(json.loads(line)))
            except json.JSONDecodeError as e:
                print(f"skipping malformed line {line_no}: {e}", file=sys.stderr)

    if not rows:
        sys.exit("no records found")

    # Union of all keys so platforms with differing fields still produce a
    # complete header.
    fieldnames = []
    for row in rows:
        for key in row:
            if key not in fieldnames:
                fieldnames.append(key)

    with open(out_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"wrote {len(rows)} rows to {out_path}")


if __name__ == "__main__":
    main()
