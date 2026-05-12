# Trainer Board — Requirements

## Purpose
Educational tool for learning assembly programming and hardware I/O.
Students enter hex code, single-step, observe registers on LEDs/7-seg.

## Target Audience
- Jr High (13-15), teacher-guided, 6-week course
- Assumes CPU board already built and tested

## Hardware Requirements

### Display
- 16×2 character LCD (HD44780 compatible)
- 8 individual LEDs (accent register or data bus monitor)
- 4-digit 7-segment display (shows address or data)

### Input
- 4×4 hex keypad (0-F) for hex entry
- 8 DIP switches (manual data input)
- RUN/STEP switch (directly controls CPU clock mux)
- RESET button

### Sound
- 8-bit R-2R ladder DAC (output)
- LM386 amplifier → 3.5mm jack
- 3.5mm audio input → LM393 comparator (cassette CLOAD)

### Storage
- SD card via ESP32 (SPI, accessed through serial commands)
- Cassette save/load via audio jacks

### Communication
- USB-serial via ESP32 (115200 baud)
- MC6850 UART mapped at $8000 (CPU can read/write directly)

### Expansion
- Has RV8-Bus (40-pin) — CPU board plugs in, plus ROM/peripheral slots

## I/O Memory Map

```
$8000  MC6850 status/data (UART)
$8002  LCD command/data
$8004  LED output register (accent)
$8006  Switch input register
$8008  7-segment data (accent via shift)
$800A  Keypad status/data
$800C  DAC output (sound)
$800E  Comparator input (audio in, bit 0)
```

## Chip List (estimated)

| Chip | Qty | Function |
|------|:---:|----------|
| ESP32 NodeMCU | 1 | USB, ROM programming, SD |
| 74HCT245 | 1 | Level shift (3.3V↔5V) |
| MC6850 | 1 | UART |
| 74HC574 | 1 | LED output latch |
| 74HC245 | 1 | Switch input buffer |
| 74HC595 | 2 | Address shift (PROG) + 7-seg |
| 74HC138 | 1 | I/O address decode |
| 74HC922 | 1 | Keypad encoder |
| R-2R + LM386 | — | Sound DAC + amp |
| LM393 | 1 | Audio input comparator |
