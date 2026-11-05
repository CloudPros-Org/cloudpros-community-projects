#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--respond" ]]; then
    IFS= read -r request_line || true

    while IFS= read -r header; do
        [[ "$header" == $'\r' || -z "$header" ]] && break
    done

    printf 'HTTP/1.1 200 OK\r\n'
    printf 'Content-Type: text/plain\r\n'
    printf 'Content-Length: 24\r\n'
    printf 'Connection: close\r\n'
    printf '\r\n'
    printf 'CloudPros Server Running'
    exit 0
fi

exec socat \
    TCP-LISTEN:8000,bind=127.0.0.1,reuseaddr,fork \
    EXEC:"/bin/bash /opt/cloudpros/server.sh --respond"
