#!/usr/bin/env python3
"""RV8 ROM Upload — Sends binary to Pico programmer over USB-serial."""
import sys, serial, time

CHUNK = 64  # bytes per write command (matches EEPROM page size)

def upload(port, binfile, base=0xC000, verify=True):
    with open(binfile, 'rb') as f:
        data = f.read()

    ser = serial.Serial(port, 115200, timeout=2)
    time.sleep(0.1)

    # Ping
    ser.write(b'P')
    if ser.read(2) != b'OK':
        print("ERROR: Pico not responding"); return False
    print(f"Connected. Uploading {len(data)} bytes to 0x{base:04X}...")

    # Write in chunks
    for offset in range(0, len(data), CHUNK):
        chunk = data[offset:offset+CHUNK]
        addr = base + offset
        hdr = bytes([addr >> 8, addr & 0xFF, len(chunk) >> 8, len(chunk) & 0xFF])
        ser.write(b'W' + hdr + chunk)
        ack = ser.read(1)
        if ack != b'\x06':
            print(f"ERROR at 0x{addr:04X}"); return False
        pct = min(100, (offset + len(chunk)) * 100 // len(data))
        print(f"\r  Writing: {pct}%", end='', flush=True)
    print()

    # Verify
    if verify:
        print("  Verifying...", end='', flush=True)
        for offset in range(0, len(data), CHUNK):
            chunk = data[offset:offset+CHUNK]
            addr = base + offset
            hdr = bytes([addr >> 8, addr & 0xFF, len(chunk) >> 8, len(chunk) & 0xFF])
            ser.write(b'V' + hdr + chunk)
            if ser.read(1) != b'\x06':
                print(f"\n  VERIFY FAILED at 0x{addr:04X}"); return False
        print(" OK")

    ser.close()
    print(f"Done! {len(data)} bytes written to ROM.")
    return True

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: rv8upload.py <port> <file.bin> [base_addr]")
        print("  e.g: rv8upload.py /dev/ttyACM0 fib.bin 0xC000")
        sys.exit(1)
    port = sys.argv[1]
    binfile = sys.argv[2]
    base = int(sys.argv[3], 16) if len(sys.argv) > 3 else 0xC000
    upload(port, binfile, base)
