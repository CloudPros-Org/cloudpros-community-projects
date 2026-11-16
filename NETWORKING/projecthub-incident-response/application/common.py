from __future__ import annotations
import json
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "config"
STATE = ROOT / "state"
LOGS = ROOT / "logs"
DB_PATH = STATE / "projecthub.sqlite3"


def read_config(name: str) -> dict:
    with (CONFIG / f"{name}.json").open(encoding="utf-8") as handle:
        return json.load(handle)


def resolve_lab_host(hostname: str) -> str:
    from resolver import resolve
    return resolve(hostname)


def log(component: str, message: str) -> None:
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    print(f"{stamp} [{component}] {message}", flush=True)
