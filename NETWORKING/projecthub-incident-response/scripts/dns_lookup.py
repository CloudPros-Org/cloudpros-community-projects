#!/usr/bin/env python3
"""Query the isolated ProjectHub DNS listener."""
from __future__ import annotations
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "application"))
from resolver import resolve

if len(sys.argv) != 2:
    print(f"Usage: {Path(sys.argv[0]).name} <hostname>", file=sys.stderr)
    raise SystemExit(2)
try:
    print(f"{sys.argv[1]} -> {resolve(sys.argv[1])}")
except OSError as exc:
    print(f"Lookup failed: {exc}", file=sys.stderr)
    raise SystemExit(1)
