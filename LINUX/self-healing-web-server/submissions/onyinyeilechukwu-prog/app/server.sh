#!/usr/bin/env bash
# CloudPros minimal HTTP server (Bash + socat).
# Listens on 127.0.0.1:8000 only and answers every request with 200 OK.

BODY="CloudPros Server Running"

handle() {
  # Read the request line (for example: GET / HTTP/1.1), wait at most 5 seconds.
  IFS= read -r -t 5 request_line || true
  method="${request_line%% *}"
  # Read and discard the remaining request headers until the blank line.
  while IFS= read -r -t 5 line; do
    line="${line%$'\r'}"
    [ -z "$line" ] && break
  done
  printf 'HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: %d\r\nConnection: close\r\n\r\n' "${#BODY}"
  # A HEAD request gets the headers only, no body.
  [ "$method" = "HEAD" ] || printf '%s' "$BODY"
}

# socat starts a new copy of this script with the word "handle" for each connection.
if [ "${1:-}" = "handle" ]; then
  handle
  exit 0
fi

exec socat TCP-LISTEN:8000,bind=127.0.0.1,reuseaddr,fork EXEC:"$0 handle"
