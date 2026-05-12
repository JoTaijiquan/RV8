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
- 40-pin universal bus slot on CPU board (directly on the CPU board, not peripheral boards)

### Universal Bus Slot (40-pin, on CPU board)

The bus slot is the **only** expansion interface. Everything plugs into it:
- Trainer board
- Full PC board
- ROM cartridges
- RAM expansion
- Any peripheral

#### Addressing: Up to 255 devices

The bus uses I/O address space ($8000-$80FF) with 8-bit device select:
- A[7:0] = device/register address (256 addresses)
- Each device responds to its assigned address range
- Device detection: read device ID register at base address
  - $00 = empty slot (pull-down on data bus)
  - $01-$FE = device type ID
  - $FF = reserved

#### Multi-device support

Multiple devices share the bus simultaneously via address decoding:
- Each card has a base address DIP switch or auto-config
- No bus arbitration needed (CPU is always master)
- /CS active only when address matches device's range

#### Pinout (40-pin DIP header)

| Pin | Signal | Pin | Signal |
|:---:|--------|:---:|--------|
| 1 | A0 | 2 | A1 |
| 3 | A2 | 4 | A3 |
| 5 | A4 | 6 | A5 |
| 7 | A6 | 8 | A7 |
| 9 | A8 | 10 | A9 |
| 11 | A10 | 12 | A11 |
| 13 | A12 | 14 | A13 |
| 15 | D0 | 16 | D1 |
| 17 | D2 | 18 | D3 |
| 19 | D4 | 20 | D5 |
| 21 | D6 | 22 | D7 |
| 23 | /CS | 24 | /RD |
| 25 | /WR | 26 | CLK |
| 27 | /IRQ | 28 | /NMI |
| 29 | /RST | 30 | HALT |
| 31 | N/A | 32 | N/A |
| 33 | N/A | 34 | N/A |
| 35 | N/A | 36 | N/A |
| 37 | N/A | 38 | N/A |
| 39 | VCC | 40 | GND |

#### Device detection protocol

```
1. CPU reads $8000 + (device_base)
2. If data = $00 → no device present (bus pull-downs)
3. If data = $01-$FE → device type ID
4. Software enumerates all 255 addresses at boot
```

#### Example device assignments

| Address | Device ID | Device |
|:-------:|:---------:|--------|
| $8000 | $10 | UART (MC6850) — Trainer |
| $8010 | $20 | Keyboard — PC board |
| $8020 | $21 | Gamepad 1 — PC board |
| $8030 | $30 | SD card — any board |
| $8040 | $40 | Sound DAC — any board |
| $8050 | $50 | LCD display — Trainer |
| $8060 | $60 | Video control — PC board |
| $8080 | $80 | ROM bank select — cartridge |
| $80F0 | $F0 | Expansion bus controller |

#### Replaceable ROM

ROM is also on the bus slot. A cartridge can override the on-board ROM:
- Cartridge asserts its own /CE for $C000-$FFFF range
- On-board ROM detects cartridge present (pin 31 = CART_DETECT)
- When cartridge inserted: on-board ROM disabled, cartridge ROM active
- Hot-swap: pull HALT, swap cartridge, release HALT → CPU resets

Maps to full address space:
- $4000-$7FFF: 16KB slot window (RAM/peripheral)
- $8000-$80FF: I/O devices (255 addresses)
- $C000-$FFFF: ROM (replaceable via cartridge)

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
