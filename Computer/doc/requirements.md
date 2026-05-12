# Full PC Board — Requirements

## Purpose
Complete 8-bit home computer. Runs BASIC, plays games, connects to TV/monitor.

## Target Audience
- High School (15-18), student-built, 10-week project
- Assumes CPU board + trainer already working

## Video

| Parameter | Value |
|-----------|-------|
| Resolution | 320×240 pixels |
| Color | 16 colors per 8×8 cell (ZX Spectrum attribute model) |
| Bitmap | 1bpp, 6144 bytes ($4000-$57FF) |
| Attributes | 768 bytes ($5800-$5AFF): ink(4bit) + paper(4bit) |
| Text mode | 40×25 characters (font in ROM) |
| Output | RGB (accent connector) or composite |
| Refresh | 60 Hz (NMI to CPU for vsync) |

### Video Hardware (~8 chips)
- 74HC161 ×2: horizontal + vertical counters
- 74HC166: parallel-to-serial shift register (pixel output)
- 74HC574: attribute latch
- 74HC138: video timing decode
- 74HC257: video/CPU address mux (shared VRAM)
- SRAM (6264): 8KB video RAM
- Resistor DAC: RGB output (3× 4-bit)

## Keyboard
- PS/2 interface (directly from keyboard)
- 74HC165 shift register to read serial data
- IRQ on keypress
- I/O address: $8010

## Sound
- 8-bit R-2R ladder DAC → LM386 amp → 3.5mm output
- 3.5mm input → LM393 comparator (cassette load)
- CPU-driven via IRQ timer (~15 kHz sample rate)
- I/O address: $800C (same as trainer)

## Gamepads
- 2× NES-style controllers (active low, active high)
- 74HC165 shift register per pad
- I/O address: $8020 (pad 1), $8022 (pad 2)

## Storage
- SD card: SPI via I/O port bit-bang ($8030)
- Cassette: audio in/out jacks (shared with sound)

## Expansion
- 30-pin universal bus slot ($4000-$7FFF, accent shared with VRAM)

## Memory Map (PC Board additions)

```
$4000-$5AFF  Video RAM (bitmap + attributes) — accent shared with bus slot
$8010        Keyboard data/status
$8020-$8022  Gamepad 1 & 2
$8030        SD card SPI port
```

## Chip List (estimated ~17)

| Chip | Qty | Function |
|------|:---:|----------|
| 74HC161 | 2 | H/V counters |
| 74HC166 | 1 | Pixel shift register |
| 74HC574 | 1 | Attribute latch |
| 74HC138 | 1 | Video timing |
| 74HC257 | 2 | Video/CPU address mux |
| 6264 | 1 | 8KB video RAM |
| 74HC165 | 3 | Keyboard + 2× gamepad |
| 74HC595 | 1 | SD card SPI |
| 74HC74 | 1 | Vsync NMI + timing |
| LM386 | 1 | Audio amplifier |
| LM393 | 1 | Audio input |
| R-2R network | — | DAC (sound) + RGB |
