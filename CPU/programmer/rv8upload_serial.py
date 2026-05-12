#!/usr/bin/env python3
"""RV8 Serial Upload — sends binary to CPU bootloader over serial."""
import sys, serial, time

def upload(port, binfile):
    with open(binfile, 'rb') as f:
        data = f.read()
    length = len(data)
    if length > 0x3DFF:
        print("ERROR: max 15871 bytes (ROM $C000-$FDFF)"); return False

    ser = serial.Serial(port, 115200, timeout=5)
    print(f"Waiting for bootloader ready signal...")

    # Wait for 'R'
    while True:
        b = ser.read(1)
        if b == b'R':
            break
        if not b:
            print("Timeout waiting for 'R'. Reset the board?"); return False

    print(f"Got 'R'. Sending {length} bytes...")
    ser.write(bytes([length >> 8, length & 0xFF]))
    time.sleep(0.01)

    # Send data with pacing (5ms per byte for EEPROM write time)
    for i, b in enumerate(data):
        ser.write(bytes([b]))
        time.sleep(0.006)  # slightly more than 5ms EEPROM write
        if (i + 1) % 256 == 0:
            print(f"\r  {(i+1)*100//length}%", end='', flush=True)
    print(f"\r  100%")

    # Wait for 'D'
    resp = ser.read(1)
    ser.close()
    if resp == b'D':
        print("Done! Program loaded and running.")
        return True
    print(f"ERROR: expected 'D', got {resp}"); return False

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: rv8upload_serial.py <port> <file.bin>")
        print("  e.g: rv8upload_serial.py /dev/ttyUSB0 fib.bin")
        sys.exit(1)
    upload(sys.argv[1], sys.argv[2])
