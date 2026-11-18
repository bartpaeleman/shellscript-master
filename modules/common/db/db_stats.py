#!/usr/bin/env python3
"""Analyze SQLite or MySQL database table sizes and row counts."""
import sqlite3
import sys


def analyze_sqlite(db_path: str) -> int:
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;").fetchall()]
    if not tables:
        print("No tables found.")
        return 0
    print(f"{'Table':<30} {'Rows':>12}")
    print("-" * 44)
    for t in tables:
        cnt = cur.execute(f'SELECT COUNT(*) FROM "{t}"').fetchone()[0]
        print(f"{t:<30} {cnt:>12}")
    conn.close()
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: db_stats.py <sqlite_db_path>", file=sys.stderr)
        sys.exit(1)
    sys.exit(analyze_sqlite(sys.argv[1]))
