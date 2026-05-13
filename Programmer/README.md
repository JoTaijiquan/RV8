# Programmer Board — ESP32 NodeMCU

**Purpose**: Flash ROM + UART terminal for all RV8 family CPUs
**Connection**: ESP32 ←USB→ PC | ESP32 ←40-pin bus→ CPU board

---

## Overview

```
PC ←──USB──→ [ESP32 NodeMCU] ←──40-pin ribbon──→ [CPU Board]
                    │
              [PROG/RUN switch]
```

One ESP32 NodeMCU module + 40-pin IDC connector + 1 switch. That's the whole board.

---

## Modes

| Mode | Switch | What happens |
|------|:------:|-------------|
| **PROG** | PROG | ESP32 holds /RST low, drives address+data, writes ROM |
| **RUN** | RUN | ESP32 releases /RST, listens on slot, UART bridge to PC |

---

## ESP32 NodeMCU Pin Mapping

### Data Bus (D[7:0]) — bidirectional, used in both modes

| ESP32 GPIO | Bus Pin | Signal |
|:----------:|:-------:|--------|
| GPIO 32 | 29 | D0 |
| GPIO 33 | 30 | D1 |
| GPIO 25 | 31 | D2 |
| GPIO 26 | 32 | D3 |
| GPIO 27 | 33 | D4 |
| GPIO 14 | 34 | D5 |
| GPIO 12 | 35 | D6 |
| GPIO 13 | 36 | D7 |

### Address Bus (A[15:0]) — output, PROG mode only (RV8/RV801)

| ESP32 GPIO | Bus Pin | Signal |
|:----------:|:-------:|--------|
| GPIO 15 | 21 | A0 |
| GPIO 2 | 22 | A1 |
| GPIO 4 | 23 | A2 |
| GPIO 16 | 24 | A3 |
| GPIO 17 | 25 | A4 |
| GPIO 5 | 26 | A5 |
| GPIO 18 | 27 | A6 |
| GPIO 19 | 28 | A7 |
| GPIO 21 | — | A8 (directly to ROM via bus extension) |
| GPIO 22 | — | A9 |
| GPIO 23 | — | A10 |
| GPIO 34* | — | A11 |
| GPIO 35* | — | A12 |
| GPIO 36* | — | A13 |
| GPIO 39* | — | A14 |

*GPIO 34-39 are input-only on ESP32. Need alternative for A11-A14.

**Revised approach**: Use shift register (74HC595) for high address bits:

```
ESP32 (3 pins: DATA, CLK, LATCH) → 74HC595 → A8-A14 (7 bits)
```

This uses only 3 ESP32 pins for the upper 7 address bits. Total GPIO: 8 (data) + 8 (addr low) + 3 (shift reg) + 3 (control) = **22 GPIO**. Fits easily.

### Control Signals

| ESP32 GPIO | Bus Pin | Signal | Direction |
|:----------:|:-------:|--------|:---------:|
| GPIO 0 | 6 | /RST | output |
| GPIO 2 | 7 | /RD | output |
| GPIO 4 | 8 | /WR | output |
| — | 11 | /SLOT1 | input (RUN mode, detect slot access) |

### Shift Register for A[8:14] (1× 74HC595 on programmer board)

| ESP32 GPIO | 74HC595 Pin | Function |
|:----------:|:-----------:|----------|
| GPIO 23 | 14 (SER) | Serial data |
| GPIO 18 | 11 (SRCLK) | Shift clock |
| GPIO 5 | 12 (RCLK) | Latch output |

74HC595 Q0-Q6 → ROM A8-A14 (directly, or via bus if RV8 has full address on bus)

**Note**: For RV8/RV801 (which have A[15:0] on the 40-pin bus), the shift register is NOT needed — ESP32 drives all address lines directly via the bus. The shift register is only needed for RV808 ROM programming header.

---

## Simplified Pin Map (RV8/RV801 — full address on bus)

| Function | ESP32 GPIOs | Count |
|----------|:-----------:|:-----:|
| D[7:0] | 32,33,25,26,27,14,12,13 | 8 |
| A[7:0] | 15,2,4,16,17,5,18,19 | 8 |
| A[8:14] | 21,22,23,34,35,36,39 | 7* |
| /RST | 0 | 1 |
| /RD | — (directly from bus, optional) | 0 |
| /WR | — (use GPIO for ROM /WE) | 1 |
| /SLOT1 (RUN mode) | input pin | 1 |
| **Total** | | **~20** |

*A[8:14] only needed in PROG mode. In RUN mode these pins are tri-stated/unused.

---

## PROG Mode — ROM Flash Sequence

```
1. Switch to PROG → ESP32 pulls /RST low
2. PC sends: "FLASH <size>\n" over USB-serial
3. ESP32 receives .bin data
4. For each byte:
   a. Set A[14:0] (address)
   b. Set D[7:0] (data)
   c. /CE=LOW, /OE=HIGH
   d. Pulse /WE LOW for 200ns
   e. Wait for write completion (poll D7 or 10ms delay)
5. Verify: read back all bytes, compare
6. ESP32 sends "OK\n" to PC
7. Switch to RUN → ESP32 releases /RST → CPU boots
```

---

## RUN Mode — UART Terminal Bridge

```
CPU writes to I/O slot:
  PAGE $F0          ; system I/O page
  SB pg:$00         ; write byte → ESP32 sees /SLOT active + data on D[7:0]
  
ESP32 detects:
  /SLOT1 goes LOW + /WR goes LOW → latch D[7:0] → send over USB to PC

PC sends keystroke:
  ESP32 receives byte over USB
  ESP32 waits for CPU to read:
    CPU does: LB pg:$00 → ESP32 drives D[7:0] with received byte

Flow:
  PC terminal ←USB→ ESP32 ←slot I/O→ CPU
```

### I/O Register Map (at slot page $F0):

| Offset | R/W | Function |
|:------:|:---:|----------|
| $00 | R | RX data (read byte from PC) |
| $00 | W | TX data (send byte to PC) |
| $01 | R | Status: bit0=rx_ready, bit1=tx_busy |

---

## RV808 Note

RV808 ROM is wired directly to PC (internal, not on bus). For ROM programming:
- **Option A**: Add 6-pin ROM header on RV808 CPU board (A8-A14 exposed)
- **Option B**: Program ROM off-board with TL866 before inserting
- **Terminal mode works fine** — uses slot on the 40-pin bus, same as RV8

---

## Voltage Level Shifting (CRITICAL)

ESP32 is **3.3V**. The RV8-Bus is **5V** (74HC logic). Direct connection will damage the ESP32.

**Solution**: TXB0108 bidirectional level shifter modules (8-channel, ~$1 each):

```
ESP32 (3.3V) ←→ [TXB0108 ×3] ←→ 40-pin bus (5V)
                 level shifters
```

| Module | Channels | Signals |
|:------:|:--------:|---------|
| TXB0108 #1 | 8 | D[7:0] — bidirectional |
| TXB0108 #2 | 8 | A[7:0] — output (PROG mode) |
| TXB0108 #3 | 4+ | /RST, /WR, /RD, /SLOT1, SYNC |

Wire: TXB0108 VA = 3.3V (ESP32 side), VB = 5V (bus side), GND shared.

---

## Parts List

| Part | Qty | Cost |
|------|:---:|:----:|
| ESP32 NodeMCU (30-pin) | 1 | ~$4 |
| TXB0108 level shifter module (8-ch) | 3 | ~$3 |
| 40-pin IDC connector + ribbon | 1 | ~$2 |
| SPDT toggle switch (PROG/RUN) | 1 | ~$0.50 |
| 74HC595 (shift register, for A8-A14) | 1 | ~$0.30 |
| **Total** | | **~$10** |

---

## PC Software

```bash
# Flash ROM
python3 rv8flash.py /dev/ttyUSB0 program.bin

# Terminal mode
python3 rv8term.py /dev/ttyUSB0
# or just: screen /dev/ttyUSB0 115200
```

---

## Compatibility

| CPU Board | PROG (flash ROM) | RUN (terminal) |
|-----------|:-:|:-:|
| RV8 (26 chips) | ✅ Full address on bus | ✅ Via slot |
| RV801 (8-9 chips) | ✅ Same bus as RV8 | ✅ Via slot |
| RV808 (23 chips) | ⚠️ Need ROM header or off-board | ✅ Via slot |
