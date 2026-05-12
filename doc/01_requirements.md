# RV8 — Requirements

## Goals

| # | Goal |
|---|------|
| G1 | Minimum chip count (27 total) for educational build |
| G2 | Fixed 2-byte instruction format (uniform fetch) |
| G3 | 16-bit address bus (64KB) |
| G4 | 8-bit data bus |
| G5 | Accumulator architecture (all ALU → a0) |
| G6 | Buildable on breadboard with 74HC chips |
| G7 | Single-step debugging (RUN/STEP switch) |
| G8 | Capable of running BASIC interpreter |

## Constraints

| Constraint | Value | Reason |
|-----------|-------|--------|
| Max chips | 27 | Fits 4 breadboards |
| Supply | 5V USB | 74HC + AT28C256 + 62256 all 5V |
| Clock | 3.5 MHz | Safe for breadboard wiring |
| ROM | 32KB (AT28C256) | Program storage, $C000-$FFFF |
| RAM | 32KB (62256) | Data, $0000-$7FFF |
| I/O | Memory-mapped | $8000-$9FFF |

## Memory Map

```
$0000-$7FFF  RAM (32KB)
$8000-$9FFF  I/O (8KB window)
$C000-$FFFF  ROM (16KB visible, banked from 32KB)
$FFF6-$FFF7  TRAP vector
$FFFA-$FFFB  NMI vector
$FFFC-$FFFD  RESET vector
$FFFE-$FFFF  IRQ vector
```

## Registers

| Name | Width | Purpose |
|------|:-----:|---------|
| c0 | 8 | Constant generator (0, 1, $FF, $80) |
| sp | 8 | Stack pointer (stack at page $30) |
| a0 | 8 | Accumulator (ALU destination) |
| pl | 8 | Pointer low byte |
| ph | 8 | Pointer high byte |
| t0 | 8 | Temporary register |
| pg | 8 | Page register (high byte for page-relative) |

## Instruction Groups

| Group | Count | Examples |
|-------|:-----:|---------|
| ALU register | 8 | ADD, SUB, AND, OR, XOR, CMP, ADC, SBC |
| ALU immediate | 7 | ADDI, SUBI, CMPI, ANDI, ORI, XORI, TST |
| Load immediate | 6 | LI sp/a0/pl/ph/t0/pg |
| Load/Store | 14 | LB/SB ptr, ptr+, sp+imm, zp, pg:imm, MOV, PUSH, POP |
| Branch | 7 | BEQ, BNE, BCS, BCC, BMI, BPL, BRA |
| Skip | 4 | SKIPZ, SKIPNZ, SKIPC, SKIPNC |
| Jump | 3 | JMP, JAL, RET |
| Shift/Unary | 8 | SHL, SHR, ROL, ROR, INC, DEC, NOT, SWAP |
| Pointer | 3 | INC16, DEC16, ADD16 |
| System | 8 | CLC, SEC, EI, DI, RTI, TRAP, NOP, HLT |
| **Total** | **68** | |

## Interrupts

| Source | Vector | Edge/Level | Maskable |
|--------|--------|-----------|----------|
| RESET | $FFFC | — | No |
| NMI | $FFFA | Falling edge | No |
| IRQ | $FFFE | Low level | Yes (IE flag) |
| TRAP | $FFF6 | Instruction | — |

## Hardware Boards

| Board | Chips | Cost | Purpose |
|-------|:-----:|:----:|---------|
| CPU board | 27 | ~$21 | Complete CPU + memory |
| Trainer board | ~10 + ESP32 | ~$23 | Programming, debug, basic I/O |
| Full PC board | ~17 | ~$75 | Video, keyboard, sound, gamepads |

All boards connect via 40-pin DIP header ribbon cable.

### Trainer Board

| Feature | Implementation |
|---------|---------------|
| Programming | ESP32 USB-serial → ROM write (PROG mode) |
| Serial terminal | MC6850 UART at $8000 |
| Display | 16×2 LCD + 8 LEDs (accent register) |
| Input | 4×4 hex keypad + 8 DIP switches |
| 7-segment | 4-digit display (address/data monitor) |
| Sound | 8-bit R-2R DAC + LM386 amp + 3.5mm out |
| Audio in | 3.5mm → LM393 comparator (cassette load) |
| Storage | SD card (SPI via ESP32) |
| Bus slot | 30-pin universal expansion |

### Full PC Board

| Feature | Implementation |
|---------|---------------|
| Video | ZX Spectrum-style: 320×240, 1bpp bitmap + attribute color (16 colors/8×8 cell) |
| Text mode | 40×25 characters for BASIC |
| Video RAM | 6.75KB bitmap + 768B attributes at $4000-$5AFF |
| Video HW | ~8 chips: counters, shift register, attribute latch, sync gen |
| Keyboard | PS/2 interface (74HC165 shift-in) at $8010 |
| Sound | 8-bit R-2R DAC + LM386 + 3.5mm in/out |
| Cassette | Audio save/load via 3.5mm jacks |
| Gamepads | 2× NES-style (74HC165 shift-in) at $8020 |
| Storage | SD card (SPI bit-bang via I/O port) |
| Bus slot | 30-pin universal expansion |

### Universal Bus Slot (30-pin)

| Pin | Signal | Pin | Signal |
|:---:|--------|:---:|--------|
| 1-14 | A[13:0] | 15-22 | D[7:0] |
| 23 | /CS | 24 | /RD |
| 25 | /WR | 26 | CLK |
| 27 | /IRQ | 28 | /NMI |
| 29 | +5V | 30 | GND |

Maps to $4000-$7FFF (16KB window). Accepts:
- ROM cartridges (32KB game/app)
- Banked ROM (up to 4MB)
- RAM expansion (16-512KB)
- Sound card (YM2149)
- WiFi card (ESP-01)
- I/O card (relays, sensors)
- Prototyping card (blank)

### BASIC Interpreter ROM

| Component | Size | Location |
|-----------|------|----------|
| BASIC interpreter | ~12KB | $C000-$EFFF |
| Monitor/debugger | ~2KB | $F000-$F7FF |
| Assembler (mini) | ~1KB | $F800-$FBFF |
| Bootloader | ~512B | $FE00-$FFFF |
| **Total** | ~16KB | Fits in AT28C256 |

Features:
- Line-numbered BASIC (Tiny BASIC style)
- Integer + software floating point
- String handling
- PEEK/POKE for hardware access
- SOUND command (DAC output)
- PLOT/DRAW/CLS (video, PC board only)
- CSAVE/CLOAD (cassette)
- LOAD/SAVE (SD card)

---

## Project Status

| Component | Status | Notes |
|-----------|:------:|-------|
| **CPU Board** | | |
| ISA design (68 instructions) | ✅ | Verified, 69 tests pass |
| Verilog implementation | ✅ | Modular + flat versions |
| Circuit design (27 chips) | ✅ | Pin-level connections |
| KiCad schematic | ✅ | Data-flow layout, 387 wires |
| Simulation (8 labs) | ✅ | Icarus Verilog, all pass |
| Lab sheets | ✅ | 8 labs with procedures |
| Breadboard build | ⬜ | Next step |
| PCB layout | ⬜ | After breadboard verified |
| **Programmer** | | |
| Pico ROM programmer | ✅ | Firmware + upload script |
| ESP32 trainer firmware | ✅ | PROG + RUN modes |
| Serial bootloader | ✅ | In-system programming |
| **Trainer Board** | | |
| ESP32 basic design | ✅ | Level shifting + UART |
| Full trainer (LCD, keypad, 7-seg) | ⬜ | |
| Sound (DAC + amp) | ⬜ | |
| SD card interface | ⬜ | |
| **Full PC Board** | | |
| Video circuit design | ⬜ | ZX Spectrum style |
| Keyboard interface | ⬜ | PS/2 |
| Sound circuit | ⬜ | Shared with trainer |
| Gamepad interface | ⬜ | NES-style |
| PCB layout | ⬜ | |
| **Universal Bus Slot** | | |
| Connector spec (30-pin) | ✅ | Defined |
| ROM cartridge card | ⬜ | |
| RAM expansion card | ⬜ | |
| Prototyping card | ⬜ | |
| **Software** | | |
| Cross-assembler | ✅ | Python, Intel HEX |
| Fibonacci demo | ✅ | Runs on simulator |
| BASIC interpreter | ⬜ | ~12KB, Tiny BASIC style |
| Monitor/debugger | ⬜ | ~2KB |
| Mini assembler (ROM) | ⬜ | ~1KB |
| **Documentation** | | |
| Design docs (00-08) | ✅ | Complete |
| Circuit diagrams (all formats) | ✅ | KiCad, Yosys, ASCII, draw.io |
| Build guide + labs | ✅ | 8 labs with simulation |
