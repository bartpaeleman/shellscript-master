#!/usr/bin/env python3
"""Generate a clean README.md for a web project."""
import os
import sys


def main(target_dir: str) -> int:
    name = os.path.basename(os.path.abspath(target_dir))
    out = os.path.join(target_dir, "README.md")
    content = f"""# {name}

Web project scaffolded by `scripter +webmaster`.

## Structure
- `index.php` — Entrypoint
- `assets/css/style.css` — Stylesheet
- `assets/js/app.js` — Frontend script
- `includes/` — Shared PHP includes
- `config/` — Configuration files
"""
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(content)
    print(f"Generated {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "."))
