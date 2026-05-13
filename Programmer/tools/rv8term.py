#!/usr/bin/env python3
"""RV8 Serial Terminal — bidirectional UART bridge to CPU."""

import sys
import threading
import serial

BAUD = 115200

def reader(ser):
    """Read from serial, print to screen."""
    try:
        while ser.is_open:
            data = ser.read(ser.in_waiting or 1)
            if data:
                sys.stdout.buffer.write(data)
                sys.stdout.buffer.flush()
    except (serial.SerialException, OSError):
        pass

def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <port>")
        sys.exit(1)

    port = sys.argv[1]
    ser = serial.Serial(port, BAUD, timeout=0.1)
    print(f"RV8 Terminal on {port} @ {BAUD} baud. Ctrl+C to exit.")

    t = threading.Thread(target=reader, args=(ser,), daemon=True)
    t.start()

    try:
        import tty, termios
        fd = sys.stdin.fileno()
        old = termios.tcgetattr(fd)
        tty.setraw(fd)
        try:
            while True:
                ch = sys.stdin.buffer.read(1)
                if ch:
                    ser.write(ch)
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old)
    except KeyboardInterrupt:
        pass
    finally:
        ser.close()
        print("\nDisconnected.")

if __name__ == "__main__":
    main()
