#!/usr/bin/env python3
"""Analyze text file: lines, words, characters, and top character frequencies."""
from collections import Counter
import sys


def main(path: str) -> int:
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        text = fh.read()
    lines = text.splitlines()
    words = text.split()
    chars = [c for c in text if not c.isspace()]
    print(f"File  : {path}")
    print(f"Lines : {len(lines)}")
    print(f"Words : {len(words)}")
    print(f"Chars : {len(text)} (non-space: {len(chars)})")
    print("Top 10 characters:")
    for ch, cnt in Counter(chars).most_common(10):
        print(f"  {ch!r}: {cnt}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: text_stats.py <file>", file=sys.stderr)
        sys.exit(1)
    sys.exit(main(sys.argv[1]))
