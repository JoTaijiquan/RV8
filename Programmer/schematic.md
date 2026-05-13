# Programmer Board — Schematic Reference

ESP32 NodeMCU → TXB0108 level shifters → 40-pin RV8-Bus (5V)

---

## 1. ESP32 GPIO Pin Assignment

### Data Bus D[7:0] — via TXB0108 #1 (bidirectional)

| ESP32 GPIO | TXB0108 #1 Ch | Bus Pin | Signal |
|:----------:|:-------------:|:-------:|--------|
| GPIO 32 | A1/B1 | 17 | D0 |
| GPIO 33 | A2/B2 | 18 | D1 |
| GPIO 25 | A3/B3 | 19 | D2 |
| GPIO 26 | A4/B4 | 20 | D3 |
| GPIO 27 | A5/B5 | 21 | D4 |
| GPIO 14 | A6/B6 | 22 | D5 |
| GPIO 12 | A7/B7 | 23 | D6 |
| GPIO 13 | A8/B8 | 24 | D7 |

### Address Bus A[7:0] — via TXB0108 #2 (ESP32→bus, PROG mode)

| ESP32 GPIO | TXB0108 #2 Ch | Bus Pin | Signal |
|:----------:|:-------------:|:-------:|--------|
| GPIO 15 | A1/B1 | 1 | A0 |
| GPIO 2 | A2/B2 | 2 | A1 |
| GPIO 4 | A3/B3 | 3 | A2 |
| GPIO 16 | A4/B4 | 4 | A3 |
| GPIO 17 | A5/B5 | 5 | A4 |
| GPIO 5 | A6/B6 | 6 | A5 |
| GPIO 18 | A7/B7 | 7 | A6 |
| GPIO 19 | A8/B8 | 8 | A7 |

### Address Bus A[14:8] — via 74HC595 shift register → TXB0108 #3

| 74HC595 Output | TXB0108 #3 Ch | Bus Pin | Signal |
|:--------------:|:-------------:|:-------:|--------|
| Q0 | A1/B1 | 9 | A8 |
| Q1 | A2/B2 | 10 | A9 |
| Q2 | A3/B3 | 11 | A10 |
| Q3 | A4/B4 | 12 | A11 |
| Q4 | A5/B5 | 13 | A12 |
| Q5 | A6/B6 | 14 | A13 |
| Q6 | A7/B7 | 15 | A14 |

### Control Signals — via TXB0108 #3 (remaining channel)

| ESP32 GPIO | TXB0108 #3 Ch | Bus Pin | Signal | Direction |
|:----------:|:-------------:|:-------:|--------|:---------:|
| GPIO 0 | A8/B8 | 28 | /RST | ESP32→bus |

### Direct Control (active only in PROG mode, directly to ROM)

| ESP32 GPIO | Destination | Signal |
|:----------:|-------------|--------|
| GPIO 21 | ROM /WE | Write enable (active low pulse) |

### Shift Register Control (ESP32 → 74HC595, 3.3V side)

| ESP32 GPIO | 74HC595 Pin | Function |
|:----------:|:-----------:|----------|
| GPIO 23 | 14 (SER) | Serial data in |
| GPIO 18 | 11 (SRCLK) | Shift clock |
| GPIO 5 | 12 (RCLK) | Latch (output register clock) |

> **Note**: GPIO 18 and GPIO 5 are shared with A6/A5 address lines. In PROG mode, firmware sequences: (1) shift out A[14:8] via 595, (2) then drive A[7:0] directly. No conflict since 595 latches hold.

### GPIO Summary

| Function | GPIOs | Count |
|----------|-------|:-----:|
| D[7:0] | 32,33,25,26,27,14,12,13 | 8 |
| A[7:0] | 15,2,4,16,17,5,18,19 | 8 |
| 74HC595 (SER,SRCLK,RCLK) | 23,18,5 | 3* |
| /RST | 0 | 1 |
| ROM /WE | 21 | 1 |
| **Total** | | **18** |

*Shared with address bus (sequenced in firmware).

---

## 2. TXB0108 Level Shifter Wiring

### Power Connections (all 3 modules identical)

| TXB0108 Pin | Connection | Voltage |
|:-----------:|------------|:-------:|
| VCCA (VA) | ESP32 3.3V rail | 3.3V |
| VCCB (VB) | Bus VCC (pin 39) | 5V |
| OE | Tied to VCCA (3.3V) | Always enabled |
| GND | Common ground | 0V |

### Module Allocation

```
                 3.3V side          5V side
               ┌──────────┐
ESP32 D[7:0] ──┤ TXB0108  ├── Bus D[7:0]  (pins 17-24)
               │   #1     │   (bidirectional)
               └──────────┘

               ┌──────────┐
ESP32 A[7:0] ──┤ TXB0108  ├── Bus A[7:0]  (pins 1-8)
               │   #2     │   (output only)
               └──────────┘

               ┌──────────┐
595 Q[6:0]   ──┤ TXB0108  ├── Bus A[14:8] (pins 9-15)
ESP32 /RST   ──┤   #3     ├── Bus /RST    (pin 28)
               └──────────┘
```

### Bypass Capacitors

- 100nF ceramic on each VCCA and VCCB pin (6 caps total)

---

## 3. 74HC595 Shift Register — A[8:14]

### Pinout Wiring

| 74HC595 Pin | Name | Connection |
|:-----------:|------|------------|
| 14 | SER (data in) | ESP32 GPIO 23 |
| 11 | SRCLK (shift clock) | ESP32 GPIO 18 |
| 12 | RCLK (latch clock) | ESP32 GPIO 5 |
| 10 | /SRCLR (clear) | Tied to VCC (3.3V) — never clear |
| 13 | /OE (output enable) | Tied to GND — always enabled |
| 16 | VCC | 3.3V (ESP32 regulator) |
| 8 | GND | GND |
| 15 | Q0 | TXB0108 #3 A1 → Bus A8 |
| 1 | Q1 | TXB0108 #3 A2 → Bus A9 |
| 2 | Q2 | TXB0108 #3 A3 → Bus A10 |
| 3 | Q3 | TXB0108 #3 A4 → Bus A11 |
| 4 | Q4 | TXB0108 #3 A5 → Bus A12 |
| 5 | Q5 | TXB0108 #3 A6 → Bus A13 |
| 6 | Q6 | TXB0108 #3 A7 → Bus A14 |
| 7 | Q7 | NC (unused) |
| 9 | Q7' (serial out) | NC |

### Shift Sequence (firmware)

```
For address bits A[14:8]:
  1. Shift 7 bits MSB-first into SER (GPIO 23), pulsing SRCLK (GPIO 18)
  2. Pulse RCLK (GPIO 5) → outputs Q0-Q6 update simultaneously
  3. Outputs held until next latch pulse
```

---

## 4. PROG/RUN Switch Circuit

### Circuit

```
                    ESP32 GPIO 0
                         │
         ┌───────────────┤
         │               │
    [PROG]    SPDT      [RUN]
         │   switch      │
         │               │
        GND            3.3V
         │               │
         └───────┬───────┘
                 │
          TXB0108 #3 A8 ──── Bus /RST (pin 28)
```

### Logic

| Switch Position | GPIO 0 | /RST (bus) | Effect |
|:---------------:|:------:|:----------:|--------|
| PROG | LOW (GND) | LOW | CPU held in reset, ESP32 drives bus |
| RUN | HIGH (3.3V) | HIGH | CPU runs, ESP32 tri-states bus pins |

### Implementation Detail

- GPIO 0 drives TXB0108 #3 channel 8 → level-shifted to 5V → bus pin 28 (/RST)
- In RUN mode: ESP32 sets all address/data GPIOs to INPUT (hi-Z)
- In PROG mode: ESP32 sets address/data GPIOs to OUTPUT, drives ROM

> **Note**: GPIO 0 also affects ESP32 boot mode. The switch must be in RUN position (HIGH) during ESP32 power-up/reset to boot normally. Pull-up resistor (10kΩ to 3.3V) recommended.

---

## 5. Power Section

### Power Distribution

```
USB 5V (from ESP32 NodeMCU USB connector)
  │
  ├──► ESP32 onboard 3.3V regulator → 3.3V rail
  │         │
  │         ├── ESP32 MCU
  │         ├── TXB0108 ×3 VCCA pins
  │         ├── 74HC595 VCC
  │         └── 10kΩ pull-up on GPIO 0
  │
  └──► Bus VCC (pin 39) → 5V rail
            │
            ├── TXB0108 ×3 VCCB pins
            ├── CPU board (74HC logic)
            └── ROM, RAM
```

### Connections

| Source | Destination | Voltage | Notes |
|--------|-------------|:-------:|-------|
| ESP32 USB 5V (VIN pin) | Bus pin 39 (VCC) | 5V | Powers entire CPU board |
| ESP32 3.3V pin | TXB0108 VCCA (×3) | 3.3V | Low-voltage side reference |
| ESP32 3.3V pin | 74HC595 VCC | 3.3V | Shift register logic level |
| Bus pin 40 | ESP32 GND | 0V | Common ground, star topology |

### Current Budget

| Load | Estimated Current |
|------|:-----------------:|
| ESP32 NodeMCU | ~80 mA |
| CPU board (26× 74HC) | ~100 mA |
| TXB0108 ×3 | ~15 mA |
| 74HC595 | ~5 mA |
| ROM + RAM | ~50 mA |
| **Total** | **~250 mA** |

USB port supplies 500 mA — sufficient with margin.

---

## Quick Reference — Full Signal Path

```
ESP32 GPIO ──(3.3V)──► TXB0108 A-side ──(5V)──► 40-pin Bus ──► CPU Board

ESP32 GPIO ──(3.3V)──► 74HC595 ──(3.3V)──► TXB0108 #3 A-side ──(5V)──► Bus A[14:8]
```
