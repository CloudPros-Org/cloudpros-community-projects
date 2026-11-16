from __future__ import annotations
import ipaddress
import json
import socket
import struct
from common import CONFIG, log

BIND_HOST = "127.0.0.4"
BIND_PORT = 15353


def decode_question(packet: bytes):
    if len(packet) < 17:
        raise ValueError("DNS packet is too short")
    offset = 12
    labels = []
    while True:
        length = packet[offset]
        offset += 1
        if length == 0:
            break
        if length & 0xC0:
            raise ValueError("compressed query names are not supported")
        labels.append(packet[offset:offset + length].decode("ascii"))
        offset += length
    qtype, qclass = struct.unpack("!HH", packet[offset:offset + 4])
    return ".".join(labels).lower(), qtype, qclass, packet[12:offset + 4]


def build_response(packet: bytes) -> bytes:
    transaction_id = packet[:2]
    try:
        name, qtype, qclass, question = decode_question(packet)
        records = json.loads((CONFIG / "hosts.json").read_text(encoding="utf-8"))
        address = records.get(name)
        if qtype != 1 or qclass != 1:
            flags, answer_count, answer = 0x8404, 0, b""  # Not Implemented
        elif address is None:
            flags, answer_count, answer = 0x8403, 0, b""  # NXDOMAIN
        else:
            packed_ip = ipaddress.IPv4Address(address).packed
            answer = b"\xc0\x0c" + struct.pack("!HHIH", 1, 1, 30, len(packed_ip)) + packed_ip
            flags, answer_count = 0x8400, 1
        header = transaction_id + struct.pack("!HHHHH", flags, 1, answer_count, 0, 0)
        log("dns", f"query {name} A -> {address if address else 'NXDOMAIN'}")
        return header + question + answer
    except Exception as exc:
        log("dns", f"invalid DNS query: {type(exc).__name__}: {exc}")
        return transaction_id + struct.pack("!HHHHH", 0x8401, 0, 0, 0, 0)


def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    server.bind((BIND_HOST, BIND_PORT))
    log("dns", f"authoritative lab DNS listening on {BIND_HOST}:{BIND_PORT}/udp")
    try:
        while True:
            packet, address = server.recvfrom(512)
            server.sendto(build_response(packet), address)
    finally:
        server.close()


if __name__ == "__main__":
    main()
