from __future__ import annotations
import os
import secrets
import socket
import struct

DNS_HOST = os.environ.get("PROJECTHUB_DNS_HOST", "127.0.0.4")
DNS_PORT = int(os.environ.get("PROJECTHUB_DNS_PORT", "15353"))


def encode_query(hostname: str) -> tuple[bytes, int]:
    query_id = secrets.randbelow(65536)
    labels = hostname.rstrip(".").split(".")
    qname = b"".join(bytes([len(label)]) + label.encode("ascii") for label in labels) + b"\x00"
    header = struct.pack("!HHHHHH", query_id, 0x0100, 1, 0, 0, 0)
    return header + qname + struct.pack("!HH", 1, 1), query_id


def resolve(hostname: str) -> str:
    packet, query_id = encode_query(hostname)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as client:
        client.settimeout(2)
        client.sendto(packet, (DNS_HOST, DNS_PORT))
        response, _ = client.recvfrom(512)
    if len(response) < 12 or response[:2] != struct.pack("!H", query_id):
        raise OSError(f"invalid DNS response for {hostname}")
    flags = struct.unpack("!H", response[2:4])[0]
    questions, answers = struct.unpack("!HH", response[4:8])
    rcode = flags & 0x000F
    if rcode == 3:
        raise OSError(f"DNS NXDOMAIN: {hostname}")
    if rcode != 0 or answers < 1:
        raise OSError(f"DNS lookup failed for {hostname} (rcode={rcode})")
    offset = 12
    for _ in range(questions):
        while response[offset] != 0:
            offset += response[offset] + 1
        offset += 5  # terminating zero plus QTYPE and QCLASS
    # The lab only returns one A record and uses the standard name pointer.
    if response[offset:offset + 2] == b"\xc0\x0c":
        offset += 2
    record_type, record_class, ttl, length = struct.unpack("!HHIH", response[offset:offset + 10])
    offset += 10
    if record_type != 1 or record_class != 1 or length != 4:
        raise OSError(f"unexpected DNS answer for {hostname}")
    return socket.inet_ntoa(response[offset:offset + 4])
