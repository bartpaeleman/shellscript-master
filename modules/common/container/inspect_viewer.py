#!/usr/bin/env python3
"""Pretty-print key fields from `docker inspect` JSON output."""
import json
import sys


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as exc:
        print(f"Invalid JSON: {exc}", file=sys.stderr)
        return 1

    if not isinstance(data, list) or not data:
        print("No container inspection data.")
        return 0

    for item in data:
        name = item.get("Name", "").lstrip("/")
        state = item.get("State", {})
        config = item.get("Config", {})
        net = item.get("NetworkSettings", {})
        print(f"=== Container: {name} ===")
        print(f"  ID     : {item.get('Id', '')[:12]}")
        print(f"  Image  : {config.get('Image', '')}")
        print(f"  Status : {state.get('Status', '')} (Running: {state.get('Running', False)})")
        print(f"  Ports  : {json.dumps(net.get('Ports', {}))}")
        print(f"  Mounts : {json.dumps([m.get('Source', '') + ':' + m.get('Destination', '') for m in item.get('Mounts', [])])}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
