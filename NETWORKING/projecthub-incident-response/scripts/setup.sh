#!/bin/sh
set -eu
ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 is required. Install Python 3.10 or newer, then rerun this script." >&2
  exit 1
fi
python3 - <<'PY'
import socket
import sys
if sys.version_info < (3, 10):
    raise SystemExit("Python 3.10 or newer is required.")
checks = [
    ("127.0.0.2", 18080, socket.SOCK_STREAM, "ProjectHub edge TCP"),
    ("127.0.0.3", 18081, socket.SOCK_STREAM, "ProjectHub API TCP"),
    ("127.0.0.1", 18099, socket.SOCK_STREAM, "ProjectHub fault-test TCP"),
    ("127.0.0.4", 15353, socket.SOCK_DGRAM, "ProjectHub lab DNS UDP"),
]
for host, port, kind, label in checks:
    with socket.socket(socket.AF_INET, kind) as sock:
        if kind == socket.SOCK_STREAM:
            result = sock.connect_ex((host, port))
            if result == 0:
                raise SystemExit(f"{label} port {host}:{port} is already in use.")
        else:
            try:
                sock.bind((host, port))
            except OSError as exc:
                raise SystemExit(f"{label} port {host}:{port} is unavailable: {exc}")
print("Python", sys.version.split()[0], "detected; required lab ports are available.")
PY
python3 scripts/labctl.py init
printf '\nSetup complete. Start the services with: sh scripts/start.sh\n'
