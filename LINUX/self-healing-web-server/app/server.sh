#!/bin/bash
# Define the body content
BODY="CloudPros Server Running"
# Calculate length for content-length header
LEN=$(echo -n "$BODY" | wc -c)

# Send a perfectly compliant HTTP 200 OK response
echo -e "HTTP/1.1 200 OK\r"
echo -e "Content-Type: text/plain\r"
echo -e "Content-Length: $LEN\r"
echo -e "Connection: close\r"
echo -e "\r"
echo -n "$BODY"
