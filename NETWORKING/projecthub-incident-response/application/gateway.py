from __future__ import annotations
import http.client
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit
from common import log, read_config, resolve_lab_host


class Handler(BaseHTTPRequestHandler):
    server_version = "ProjectHubEdge/1.0"

    def handle_proxy(self):
        cfg = read_config("gateway")
        path = urlsplit(self.path).path
        upstream_path = path if path == "/health" else cfg["api_prefix"].rstrip("/") + "/" + path.lstrip("/")
        try:
            upstream_ip = resolve_lab_host(cfg["upstream_host"])
            connection = http.client.HTTPConnection(upstream_ip, int(cfg["upstream_port"]), timeout=3)
            length = int(self.headers.get("Content-Length", "0"))
            body = self.rfile.read(length) if length else None
            headers = {k: v for k, v in self.headers.items() if k.lower() not in {"host", "content-length", "connection"}}
            connection.request(self.command, upstream_path, body=body, headers=headers)
            response = connection.getresponse()
            payload = response.read()
            self.send_response(response.status)
            for key, value in response.getheaders():
                if key.lower() not in {"transfer-encoding", "connection", "content-length", "server", "date"}:
                    self.send_header(key, value)
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            log("gateway", f"{self.command} {self.path} -> {cfg['upstream_host']}:{cfg['upstream_port']}{upstream_path} [{response.status}]")
            connection.close()
        except Exception as exc:
            log("gateway", f"upstream failure for {self.path}: {type(exc).__name__}: {exc}")
            payload = json.dumps({"error": "bad_gateway", "detail": str(exc)}).encode()
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

    do_GET = handle_proxy
    do_POST = handle_proxy

    def log_message(self, fmt, *args):
        log("gateway", fmt % args)


def main():
    cfg = read_config("gateway")
    server = ThreadingHTTPServer((cfg["bind_host"], int(cfg["port"])), Handler)
    log("gateway", f"listening on {cfg['bind_host']}:{cfg['port']}")
    try:
        server.serve_forever()
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
