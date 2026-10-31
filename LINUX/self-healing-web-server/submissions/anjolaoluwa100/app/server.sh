#!/usr/bin/env bash
# Tiny HTTP server. socat listens on 127.0.0.1:8000 and runs this
# same script with "respond" for every request that comes in.
if [ "$1" = "respond" ]; then
    # Read and ignore the request line and headers (they end at a blank line).
    while read -r line && [ "${line%$'\r'}" != "" ]; do :; done
    body="CloudPros Server Running"
    printf 'HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s\n' "$(( ${#body} + 1 ))" "$body"
    exit 0
fi
exec socat TCP-LISTEN:8000,bind=127.0.0.1,reuseaddr,fork EXEC:"$0 respond"
