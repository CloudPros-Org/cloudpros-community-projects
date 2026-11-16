from __future__ import annotations
import json
import time
import urllib.error
import urllib.request
from common import log, read_config, resolve_lab_host


def request(url, method="GET", payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={"Content-Type": "application/json"})
    with urllib.request.build_opener(urllib.request.ProxyHandler({})).open(req, timeout=3) as response:
        return json.loads(response.read() or b"{}")


def main():
    cfg = read_config("worker")
    delay = float(cfg.get("poll_seconds", 3))
    log("worker", f"starting; API={cfg['api_host']}:{cfg['api_port']}")
    while True:
        try:
            ip = resolve_lab_host(cfg["api_host"])
            base = f"http://{ip}:{int(cfg['api_port'])}"
            result = request(base + "/api/jobs/next")
            job = result.get("job")
            if job:
                log("worker", f"processing task id={job['id']}")
                request(base + f"/api/jobs/{job['id']}/complete", "POST", {})
                log("worker", f"completed task id={job['id']}")
                time.sleep(delay)
            else:
                time.sleep(delay)
        except (OSError, urllib.error.URLError, TimeoutError, ValueError) as exc:
            log("worker", f"API connection failed: {type(exc).__name__}: {exc}")
            time.sleep(delay)


if __name__ == "__main__":
    main()
