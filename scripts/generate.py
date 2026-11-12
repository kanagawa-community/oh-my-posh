#!/usr/bin/env python3
"""Write themes/kanagawa-<variant>.omp.json (and kanagawa-dynamic.omp.json) from scripts/layout.omp.json and the shared palette.

Usage: scripts/generate.py [path/to/palette.json]   (default: ../.github/palette.json)
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VARIANTS = ["wave", "dragon", "lotus"]
PLACEHOLDER = '"palette": {}'

# Oh My Posh palette name -> palette role. A name that is not a role is written as is.
ANSI = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]
PALETTE = {
    **{c: f"term.{c}" for c in ANSI},
    **{f"bright-{c}": f"term.bright_{c}" for c in ANSI},
    "git-added": "vcs.added",
    "git-removed": "vcs.removed",
    "git-changed": "vcs.changed",
    **{f"diag-{d}": f"diag.{d}" for d in ("ok", "error", "warning", "info", "hint")},
    "special": "ui.special",
    "dim": "syn.comment",
    "lang": "syn.type",
    "tool": "syn.identifier",
    "mode-normal": "syn.fun",
    "mode-visual": "syn.keyword",
}


def roles(variant):
    """Map each role to its hex color; a role missing from the palette raises KeyError later."""
    return {role: c["hex"] for c in variant["colors"].values() for role in c["usage"]}


def entries(r, pad):
    return ",\n".join(f'{" " * pad}"{k}": "{r[v]}"' for k, v in PALETTE.items())


def theme(layout, palette):
    # The layout holds an empty palette on one line; Prettier keeps the expanded form.
    assert PLACEHOLDER in layout, f"{PLACEHOLDER} not found in layout.omp.json"
    return layout.replace(PLACEHOLDER, palette, 1)


# The dynamic theme picks its palette from the environment: $KANAGAWA_MODE=light gives lotus,
# otherwise $KANAGAWA_DARK=dragon gives dragon, and anything else gives wave.
SELECT = (
    '{{ if eq .Env.KANAGAWA_MODE "light" }}lotus'
    '{{ else if eq .Env.KANAGAWA_DARK "dragon" }}dragon{{ else }}wave{{ end }}'
)


def main():
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT.parent / ".github" / "palette.json"
    variants = json.loads(path.read_text())["variants"]
    layout = (ROOT / "scripts" / "layout.omp.json").read_text()
    out = ROOT / "themes"
    out.mkdir(exist_ok=True)
    for v in VARIANTS:
        palette = f'"palette": {{\n{entries(roles(variants[v]), 4)}\n  }}'
        (out / f"kanagawa-{v}.omp.json").write_text(theme(layout, palette))
        print(f"themes/kanagawa-{v}.omp.json")
    lists = ",\n".join(f'      "{v}": {{\n{entries(roles(variants[v]), 8)}\n      }}' for v in VARIANTS)
    palettes = f'"palettes": {{\n    "template": {json.dumps(SELECT)},\n    "list": {{\n{lists}\n    }}\n  }}'
    (out / "kanagawa-dynamic.omp.json").write_text(theme(layout, palettes))
    print("themes/kanagawa-dynamic.omp.json")


if __name__ == "__main__":
    main()
