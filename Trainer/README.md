# RV8 Trainer Board

Programming, debugging, and basic I/O board. Plugs into CPU board via 40-pin connector.

## Status: Design complete (ESP32 basic), full version pending

## Specs

| Parameter | Value |
|-----------|-------|
| MCU | ESP32 NodeMCU (USB-serial + ROM programming) |
| Level shift | 74HCT245 (3.3V ↔ 5V) |
| Chips | ~10 + ESP32 |
| Cost | ~$23 |
| Power | 5V from CPU board |

## Features

| Feature | Chip/Method | I/O Address |
|---------|-------------|:-----------:|
| Serial terminal | MC6850 UART | $8000 |
| ROM programming | ESP32 + 74HC595 (PROG mode) | — |
| Display | 16×2 LCD (HD44780) | $8002 |
| LEDs | 74HC574 (8 output LEDs) | $8004 |
| Switches | 74HC245 (8 input DIP) | $8006 |
| 7-segment | 4-digit (74HC595 shift) | $8008 |
| Hex keypad | 4×4 matrix (74HC922) | $800A |
| Sound out | 8-bit R-2R DAC + LM386 | $800C |
| Audio in | LM393 comparator (cassette) | $800E |
| SD card | SPI via ESP32 | via serial |
| Bus slot | Plugs into CPU board 40-pin universal bus | — |
| I/O decode | 74HC138 | — |

## Modes

| Mode | Switch | Function |
|------|:------:|----------|
| PROG | ON | ESP32 drives ROM, CPU in reset |
| RUN | OFF | CPU runs, ESP32 provides UART |

## Files

```
trainer/
├── README.md              ← this file
├── doc/
│   └── requirements.md    ← detailed requirements
├── (firmware TBD)
└── (schematic TBD)
```
