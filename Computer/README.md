# RV8 Full PC Board

Complete home computer: video, keyboard, sound, gamepads. Runs BASIC.

## Status: Not started

## Specs

| Parameter | Value |
|-----------|-------|
| Video | 320×240, 16 colors (ZX Spectrum style) |
| Text | 40×25 characters |
| Sound | 8-bit DAC + cassette in/out |
| Input | PS/2 keyboard + 2× NES gamepads |
| Storage | SD card + cassette |
| Chips | ~17 |
| Cost | ~$75 |

## Architecture

```
CPU Board (40-pin) ──► PC Board
                         ├── Video: bitmap + attributes → RGB out
                         ├── Keyboard: PS/2 → shift register
                         ├── Sound: DAC → amp → 3.5mm
                         ├── Gamepads: 2× NES → shift register
                         ├── SD card: SPI bit-bang
                         ├── Cassette: audio in/out
                         └── Bus slot: 30-pin expansion
```

## Files

```
pc/
├── README.md              ← this file
├── doc/
│   └── requirements.md    ← detailed requirements
├── (schematic TBD)
└── (firmware TBD)
```
