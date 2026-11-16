#!/usr/bin/env python3
"""Portable controller for the ProjectHub network incident lab."""
from __future__ import annotations
import argparse
import base64
import json
import os
import shutil
import signal
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "application"
CONFIG = ROOT / "config"
DEFAULTS = CONFIG / "defaults"
STATE = ROOT / "state"
LOGS = ROOT / "logs"
PID_DIR = STATE / "pids"
PYTHON = sys.executable


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def pid_path(name: str) -> Path:
    return PID_DIR / f"{name}.pid"


def is_running(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except (ProcessLookupError, PermissionError):
        return False


def stop_one(name: str) -> None:
    path = pid_path(name)
    if not path.exists():
        return
    try:
        pid = int(path.read_text().strip())
        if is_running(pid):
            try:
                os.killpg(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            # The Python HTTP servers and worker exit promptly on SIGTERM.
            time.sleep(0.4)
    except (ValueError, ProcessLookupError, PermissionError):
        pass
    path.unlink(missing_ok=True)


def stop_all() -> None:
    for name in ("worker", "gateway", "api", "dns"):
        stop_one(name)
    print("ProjectHub processes stopped.")


def launch(name: str, module: str) -> None:
    PID_DIR.mkdir(parents=True, exist_ok=True)
    log_path = LOGS / f"{name}.log"
    LOGS.mkdir(exist_ok=True)
    handle = log_path.open("a", encoding="utf-8")
    process = subprocess.Popen(
        [PYTHON, str(APP / f"{module}.py")], cwd=ROOT,
        stdin=subprocess.DEVNULL, stdout=handle, stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    handle.close()
    pid_path(name).write_text(str(process.pid) + "\n", encoding="utf-8")


def wait_port(host: str, port: int, timeout: float = 8) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with socket.create_connection((host, port), timeout=0.3):
                return True
        except OSError:
            time.sleep(0.15)
    return False


def start_all() -> int:
    for name in ("dns", "api", "gateway", "worker"):
        path = pid_path(name)
        if path.exists():
            try:
                if is_running(int(path.read_text().strip())):
                    print(f"{name} already appears to be running; stop the lab before starting again.")
                    return 1
            except ValueError:
                pass
            path.unlink(missing_ok=True)
    launch("dns", "dns")
    sys.path.insert(0, str(APP))
    from resolver import resolve
    dns_deadline = time.time() + 5
    while time.time() < dns_deadline:
        try:
            resolve("edge.projecthub.test")
            break
        except OSError:
            time.sleep(0.1)
    else:
        print("Lab DNS listener did not become ready.", file=sys.stderr)
        stop_all()
        return 1
    launch("api", "api")
    api_cfg = read_json(CONFIG / "api.json")
    api_ready = wait_port(api_cfg["bind_host"], int(api_cfg["port"]))
    launch("gateway", "gateway")
    gateway_cfg = read_json(CONFIG / "gateway.json")
    gateway_ready = wait_port(gateway_cfg["bind_host"], int(gateway_cfg["port"]))
    launch("worker", "worker")
    if not api_ready:
        print(f"API did not open {api_cfg['bind_host']}:{api_cfg['port']} (this may be the injected incident).")
    if not gateway_ready:
        print(f"Gateway did not open {gateway_cfg['bind_host']}:{gateway_cfg['port']}.")
    print("ProjectHub processes launched. Use 'status' and the incident checks to assess health.")
    return 0


def request(url: str, method="GET", payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.build_opener(urllib.request.ProxyHandler({})).open(req, timeout=2) as response:
            return response.status, response.read().decode(errors="replace")
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode(errors="replace")


def status() -> int:
    configs = {name: read_json(CONFIG / f"{name}.json") for name in ("api", "gateway")}
    for name, cfg in configs.items():
        host, port = cfg["bind_host"], int(cfg["port"])
        try:
            with socket.create_connection((host, port), timeout=1):
                state = "TCP reachable"
        except OSError as exc:
            state = f"unreachable ({exc})"
        print(f"{name:8} {host}:{port}  {state}")
    cfg = configs["gateway"]
    code, body = request(f"http://{cfg['bind_host']}:{cfg['port']}/health")
    print(f"HTTP health via gateway: {code} {body[:180]}")
    for name in ("dns", "api", "gateway", "worker"):
        path = pid_path(name)
        if path.exists():
            try:
                alive = is_running(int(path.read_text().strip()))
            except ValueError:
                alive = False
            print(f"process {name:8} {'running' if alive else 'not running'}")
        else:
            print(f"process {name:8} not running")
    return 0


def inject(number: int) -> int:
    if number not in range(1, 6):
        print("Incident number must be between 1 and 5.", file=sys.stderr)
        return 2
    STATE.mkdir(exist_ok=True)
    level_file = STATE / "incident-level"
    current = int(level_file.read_text().strip()) if level_file.exists() else 0
    if number != current + 1:
        print(f"Introduce incidents in order. The next incident is {current + 1}.", file=sys.stderr)
        return 2
    stop_all()
    # The fault catalog is intentionally opaque so the injector behaves as a
    # black box during the exercise. It contains only lab-local config edits.
    encoded_catalog = "eNqFjsEOwiAMQP+F84LDi+KvGLMw7RwbAinFuRj/XbgYlpCY3tq893p+s0EbYCc2ukCBT8FZ1rAZ1rRSXnOPboIrjbHnBIHS7alMzIDYH3ibRrJP87NkZOPotb112V0hRUneFcGi1i0dfSAE9ei8w8Igjq2U/9j0SucRBv0q0jttCdAqU6YXhzNgha5EL1/lFWLS"
    catalog = json.loads(zlib.decompress(base64.b64decode(encoded_catalog)))
    change = catalog[number - 1]
    target = CONFIG / change["file"]
    settings = read_json(target)
    settings[change["key"]] = change["value"]
    write_json(target, settings)
    level_file.write_text(str(number) + "\n", encoding="utf-8")
    print(f"Incident {number} has been introduced. The change is intentionally not described here.")
    return start_all()


def reset() -> int:
    stop_all()
    for name in ("api.json", "gateway.json", "hosts.json", "worker.json"):
        shutil.copy2(DEFAULTS / name, CONFIG / name)
    (STATE / "projecthub.sqlite3").unlink(missing_ok=True)
    (STATE / "incident-level").unlink(missing_ok=True)
    if LOGS.exists():
        for path in LOGS.glob("*.log"):
            path.unlink(missing_ok=True)
    print("Baseline configuration and application data restored. Start the lab and verify it before continuing.")
    return 0


def init() -> int:
    STATE.mkdir(exist_ok=True)
    LOGS.mkdir(exist_ok=True)
    PID_DIR.mkdir(exist_ok=True)
    for name in ("api.json", "gateway.json", "hosts.json", "worker.json"):
        target = CONFIG / name
        if not target.exists():
            shutil.copy2(DEFAULTS / name, target)
    # Initialise the SQLite schema using the same application code as the API.
    sys.path.insert(0, str(APP))
    from api import initialise_database
    initialise_database()
    print("ProjectHub lab initialised. No system configuration or firewall rules were changed.")
    return 0


def verify() -> int:
    cfg = read_json(CONFIG / "gateway.json")
    base = f"http://{cfg['bind_host']}:{cfg['port']}"
    checks = [("/health", 200), ("/projects", 200)]
    failed = False
    for path, expected in checks:
        try:
            code, body = request(base + path)
            ok = code == expected
            print(f"{'PASS' if ok else 'FAIL'} {path}: HTTP {code} (expected {expected})")
            if not ok:
                print(body[:300])
                failed = True
        except OSError as exc:
            print(f"FAIL {path}: {exc}")
            failed = True
    return 1 if failed else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("init")
    sub.add_parser("start")
    sub.add_parser("stop")
    sub.add_parser("status")
    sub.add_parser("verify")
    sub.add_parser("reset")
    inject_parser = sub.add_parser("inject")
    inject_parser.add_argument("incident", type=int)
    args = parser.parse_args()
    actions = {"init": init, "start": start_all, "stop": stop_all, "status": status, "verify": verify, "reset": reset}
    result = inject(args.incident) if args.command == "inject" else actions[args.command]()
    raise SystemExit(result if isinstance(result, int) else 0)


if __name__ == "__main__":
    main()
