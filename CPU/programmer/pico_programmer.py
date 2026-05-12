"""RV8 In-Circuit ROM Programmer — Pico Firmware (MicroPython)
Receives binary over USB-serial, writes to AT28C256 EEPROM.
Protocol: 'W' + addr_hi + addr_lo + length_hi + length_lo + data...
          'R' + addr_hi + addr_lo + length_hi + length_lo → reads back
          'P' → ping (returns 'OK')
"""
import sys
from machine import Pin
from time import sleep_us, sleep_ms

# --- Pin definitions ---
ADDR_PINS = [Pin(i, Pin.OUT) for i in range(15)]  # GP0-GP14 → A0-A14
DATA_PINS = [Pin(i) for i in [15,16,17,18,19,20,21,26]]  # D0-D7
CE = Pin(27, Pin.OUT, value=1)   # /CE (idle high)
OE = Pin(28, Pin.OUT, value=1)   # /OE (idle high)
WE = Pin(22, Pin.OUT, value=1)   # /WE (idle high)

def set_addr(addr):
    for i in range(15):
        ADDR_PINS[i].value((addr >> i) & 1)

def data_output(val):
    for i, p in enumerate(DATA_PINS):
        p.init(Pin.OUT)
        p.value((val >> i) & 1)

def data_input():
    for p in DATA_PINS:
        p.init(Pin.IN)

def read_data():
    val = 0
    for i, p in enumerate(DATA_PINS):
        val |= (p.value() << i)
    return val

def write_byte(addr, data):
    set_addr(addr)
    data_output(data)
    CE.value(0)
    OE.value(1)
    WE.value(0)
    sleep_us(1)
    WE.value(1)
    CE.value(1)
    # Poll D7 for write completion
    data_input()
    CE.value(0)
    OE.value(0)
    for _ in range(200):
        if read_data() == data:
            break
        sleep_us(50)
    OE.value(1)
    CE.value(1)

def read_byte(addr):
    set_addr(addr)
    data_input()
    CE.value(0)
    OE.value(0)
    sleep_us(1)
    val = read_data()
    OE.value(1)
    CE.value(1)
    return val

def main():
    stdin = sys.stdin.buffer
    stdout = sys.stdout.buffer
    while True:
        cmd = stdin.read(1)
        if not cmd:
            continue
        if cmd == b'P':
            stdout.write(b'OK')
        elif cmd == b'W':
            hdr = stdin.read(4)
            addr = (hdr[0] << 8) | hdr[1]
            length = (hdr[2] << 8) | hdr[3]
            data = stdin.read(length)
            for i in range(length):
                write_byte(addr + i, data[i])
            stdout.write(b'\x06')  # ACK
        elif cmd == b'R':
            hdr = stdin.read(4)
            addr = (hdr[0] << 8) | hdr[1]
            length = (hdr[2] << 8) | hdr[3]
            buf = bytes(read_byte(addr + i) for i in range(length))
            stdout.write(buf)
        elif cmd == b'V':  # Verify
            hdr = stdin.read(4)
            addr = (hdr[0] << 8) | hdr[1]
            length = (hdr[2] << 8) | hdr[3]
            data = stdin.read(length)
            ok = all(read_byte(addr + i) == data[i] for i in range(length))
            stdout.write(b'\x06' if ok else b'\x15')  # ACK or NAK

main()
