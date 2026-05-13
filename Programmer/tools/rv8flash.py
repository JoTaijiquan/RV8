#!/usr/bin/env python3
"""RV8 ROM Flash Tool — sends binary to ESP32 programmer via serial."""

import sys
import serial

BAUD = 115200
TIMEOUT = 30

def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <port> <file.bin>")
        sys.exit(1)

    port, binfile = sys.argv[1], sys.argv[2]

    with open(binfile, "rb") as f:
        data = f.read()

    size = len(data)
    if size == 0 or size > 32768:
        print(f"Error: file size {size} bytes (must be 1-32768)")
        sys.exit(1)

    print(f"Flashing {binfile} ({size} bytes) to {port}...")

    ser = serial.Serial(port, BAUD, timeout=TIMEOUT)

    # Send: 'F' + length_hi + length_lo + data
    header = bytes([ord('F'), (size >> 8) & 0xFF, size & 0xFF])
    ser.write(header)

    # Wait for ACK ('K') before sending data
    ack = ser.read(1)
    if ack != b'K':
        print(f"Error: expected ACK 'K', got {ack!r}")
        ser.close()
        sys.exit(1)

    # Send data with progress bar
    chunk_size = 64
    sent = 0
    while sent < size:
        end = min(sent + chunk_size, size)
        ser.write(data[sent:end])
        sent = end
        pct = sent * 100 // size
        bar = '#' * (pct // 2) + '-' * (50 - pct // 2)
        print(f"\r[{bar}] {pct:3d}%", end='', flush=True)

    print()

    # Wait for done ('D')
    resp = ser.read(1)
    ser.close()

    if resp == b'D':
        print("OK — flash complete.")
    else:
        print(f"Error: expected 'D', got {resp!r}")
        sys.exit(1)

if __name__ == "__main__":
    main()
