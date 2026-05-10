# RV8 — Requirements Specification

**Project**: RV8 Minimal Educational CPU  
**Version**: 4.0  
**Date**: 2026-05-10  
**Phase**: Requirements

---

## 1. Project Goals

| # | Goal |
|---|------|
| G1 | Minimum gate count for educational purposes |
| G2 | Fixed 2-byte instruction format (uniform fetch) |
| G3 | 16-bit address bus (64KB addressable space) |
| G4 | 8-bit data bus |
| G5 | 6502-inspired accumulator architecture |
| G6 | RISC-V naming conventions (x0-x4) |
| G7 | Buildable on breadboard (~25 chips CPU) or PCB |
| G8 | Capable of running full BASIC with floating point |
| G9 | 320×240 16-color graphics + 40×25 text, 8-bit D/A sound |
| G10 | Two build options: single-board trainer OR full PC-style computer |

---

## 2. Constraints

| Constraint | Value | Rationale |
|------------|-------|-----------|
| Instruction width | Fixed 2 bytes | Uniform fetch, no length decoder |
| Data width | 8 bits | Matches data bus |
| Address bus | 16 bits | 64KB address space |
| Register count | 7 (x0-x6) | 3-bit encoding (7 used, 1 reserved) |
| x0 | Always zero | RISC-V convention |
| Clock | 3.5 MHz breadboard / 10 MHz PCB | 74HC both targets |
| Pipeline | None (multi-cycle) | Minimal gates |
| Endianness | Little-endian | 6502 convention |
| Architecture | Von Neumann | Shared bus, fewer chips |
| Register model | Accumulator-only | a0 is implicit destination for ALU |
| Pointer auto-increment | Yes | Critical for BASIC string/array ops |
| Branch offset | Byte-relative (±127 bytes) | Simple adder, no shift logic |
| Interrupts | 2 lines (NMI + IRQ) | Background sound + vsync |
| Undefined opcodes | Default to HLT | Safe error behavior |

---

## 3. Register Set

| Encoding | Register | Name | Purpose |
|----------|----------|------|---------|
| 000 | x0 | c0 | Constant generator: 0 (default), 1, -1 (0xFF), 0x80 — selected by instruction context |
| 001 | x1 | sp | Stack pointer (8-bit, page 0x30) |
| 010 | x2 | a0 | Accumulator (implicit ALU destination) |
| 011 | x3 | pl | Pointer low byte |
| 100 | x4 | ph | Pointer high byte |
| 101 | x5 | t0 | Temporary register |
| 110 | x6 | pg | Page register (high byte for page-relative addressing) |
| 111 | — | — | Reserved (read as zero) |

**Constant generator (x0):** When read as source operand, produces:
- `c0` = 0x00 (default, same as old zero register)
- `c1` = 0x01 (via encoding variant)
- `cn` = 0xFF (-1, via encoding variant)
- `ch` = 0x80 (sign bit, via encoding variant)

Eliminates ~20% of LI instructions for common constants. Hardware: 1× 74HC157 (quad 2:1 mux).

### Special Registers (not in register file)

| Register | Width | Purpose |
|----------|-------|---------|
| PC | 16 bits | Program counter (always increments by 2) |
| Flags | 3 bits | Z (zero), C (carry), N (negative) |
| IE | 1 bit | Interrupt enable |
| IR | 16 bits | Instruction register (2 bytes fetched together) |

---

## 4. Memory Map

| Address Range | Size | Purpose |
|---------------|------|---------|
| 0x0000–0x00FF | 256B | **Zero page** (fast globals via `LB/SB [zp+imm]`) |
| 0x0100–0x257F | 9344B | Video bitmap (320×240, 1bpp, starts at 0x0100) |
| 0x2580–0x2977 | 1000B | Video attributes (40×25 color cells, 16 colors) |
| 0x2978–0x2D6F | 1000B | Text buffer (40×25 characters) |
| 0x2D70–0x2FFF | 656B | System variables |
| 0x3000–0x30FF | 256B | Stack (page 0x30, sp indexes here) |
| 0x3100–0x3FFF | ~4KB | BASIC workspace (fixed, always visible) |
| 0x4000–0x7FFF | 16KB | **Universal bus slot** (ROM cart / RAM / I/O / empty=0xFF) |
| 0x8000–0x80FF | 256B | I/O devices (memory-mapped) |
| 0xC000–0xFFFF | 16KB | **Fixed ROM** (BASIC + monitor + drivers, always present) |
| 0xFFF6–0xFFF7 | 2B | TRAP vector (system call / breakpoint) |
| 0xFFF8–0xFFF9 | 2B | (reserved) |
| 0xFFFA–0xFFFB | 2B | NMI vector |
| 0xFFFC–0xFFFD | 2B | RESET vector |
| 0xFFFE–0xFFFF | 2B | IRQ vector |

### Universal Bus Slot (0x4000-0x7FFF)

30-pin edge connector on **both** Trainer and PC boards. Directly exposes system bus.

| Pin | Signal | Dir | Pin | Signal | Dir |
|-----|--------|-----|-----|--------|-----|
| 1 | GND | PWR | 16 | A8 | Out |
| 2 | VCC (5V) | PWR | 17 | A9 | Out |
| 3 | D0 | Bi | 18 | A10 | Out |
| 4 | D1 | Bi | 19 | A11 | Out |
| 5 | D2 | Bi | 20 | A12 | Out |
| 6 | D3 | Bi | 21 | A13 | Out |
| 7 | D4 | Bi | 22 | /CS | Out |
| 8 | D5 | Bi | 23 | /RD | Out |
| 9 | D6 | Bi | 24 | /WR | Out |
| 10 | D7 | Bi | 25 | CLK | Out |
| 11 | A0 | Bi | 26 | /IRQ | In |
| 12 | A1 | Out | 27 | /NMI | In |
| 13 | A2 | Out | 28 | /RESET | Out |
| 14 | A3 | Out | 29 | CART_DET | In |
| 15 | A4-A7 | Out | 30 | GND | PWR |

Accepts: ROM cartridges, RAM cards, I/O cards, co-processor cards, prototyping cards.  
Hot-pluggable. Slot empty = reads return 0xFF (pull-up resistors).  
Card detect: mechanical switch → readable at I/O register 0x80C2 bit 0.

### Fixed ROM (0xC000-0xFFFF)

- Always present on CPU card (AT28C256, 32KB, soldered or ZIF socket)
- Contains BASIC interpreter, monitor, drivers, assembler
- System always boots from here (reset vector at 0xFFFC)
- Never overridden by cartridge — always accessible

---

## 5. I/O Map

| Address | Device | R/W | Function |
|---------|--------|-----|----------|
| 0x8000 | UART data | R/W | Serial byte in/out |
| 0x8001 | UART status | R | Bit 0=RX ready, Bit 1=TX empty, Bit 2=frame err |
| 0x8002 | UART baud | W | Divisor: 0=115200, 1=57600, 2=38400, 3=19200, 4=9600 |
| 0x8010 | Keyboard data | R | Key scancode (PS/2 or matrix) |
| 0x8011 | Key status | R | Bit 0=key available, Bit 1=shift, Bit 2=ctrl |
| 0x8020 | Video mode | W | 0=text, 1=graphics, 2=mixed |
| 0x8021 | Border color | W | Border color (4-bit, 16 colors) |
| 0x8022 | Scroll Y | W | Vertical scroll offset |
| 0x8030 | Sound DAC | W | 8-bit D/A sample output |
| 0x8031 | Sound freq | W | Tone generator frequency |
| 0x8032 | Sound ctrl | W | Bit 0=DAC enable, Bit 1=tone enable |
| 0x8033 | Sound vol | W | Volume (0-255) |
| 0x8040 | Joypad 1 | R | NES pad: [A][B][Sel][Sta][U][D][L][R] |
| 0x8041 | Joypad 2 | R | NES pad: [A][B][Sel][Sta][U][D][L][R] |
| 0x8042 | Joypad strobe | W | Write 1 then 0 to latch pad state |
| 0x8043 | Joypad 1 out | W | 4-bit digital output (bits 0-3, for LEDs/rumble) |
| 0x8044 | Joypad 2 out | W | 4-bit digital output (bits 0-3, for LEDs/rumble) |
| 0x8050 | Joystick 1 X | R | Analog X axis (0-255, 128=center) |
| 0x8051 | Joystick 1 Y | R | Analog Y axis (0-255, 128=center) |
| 0x8052 | Joystick 1 btn | R | [A][B][Sel][Sta][0][0][0][0] |
| 0x8053 | Joystick 1 out | W | 4-bit digital output (bits 0-3) |
| 0x8054 | Joystick 2 X | R | Analog X axis (0-255, 128=center) |
| 0x8055 | Joystick 2 Y | R | Analog Y axis (0-255, 128=center) |
| 0x8056 | Joystick 2 btn | R | [A][B][Sel][Sta][0][0][0][0] |
| 0x8057 | Joystick 2 out | W | 4-bit digital output (bits 0-3) |
| 0x8060 | GPIO out | W | 8 digital outputs |
| 0x8061 | GPIO in | R | 8 digital inputs |
| 0x8070 | ADC channel | W | Select analog input (0-7) |
| 0x8071 | ADC data | R | 8-bit analog reading |
| 0x8080 | DAC out | W | General-purpose analog output |
| 0x8090 | LCD command | W | HD44780 instruction (Option 1 only) |
| 0x8091 | LCD data | W | HD44780 character (Option 1 only) |
| 0x80A0 | 7-seg display | W | 4-digit hex display (Option 1 only) |
| 0x80B0 | Timer count lo | R | Free-running counter low byte |
| 0x80B1 | Timer count hi | R | Free-running counter high byte |
| 0x80B2 | Timer prescaler | W | Divider: 0=CPU/1, 1=CPU/8, 2=CPU/64, 3=CPU/256 |
| 0x80B3 | Timer compare | W | IRQ fires when count_lo == compare value |
| 0x80B4 | Timer ctrl | W | Bit 0=enable, Bit 1=IRQ enable, Bit 2=reset count |
| 0x80C0 | Slot bank select | W | Select page within multi-bank cartridge (0-255) |
| 0x80C2 | Slot status | R | Bit 0=card present, Bit 1=card writable |
| 0x80F0 | Expansion ID | R | Expansion card identification byte |
| 0x80F1–0x80FF | Expansion I/O | R/W | Expansion card registers (15 bytes) |

### UART Specifications

| Baud rate | Divisor | Use case |
|-----------|---------|----------|
| 115200 | 0 | Fast PC transfer |
| 57600 | 1 | Fast transfer |
| 38400 | 2 | Reliable at distance |
| 19200 | 3 | Default at boot |
| 9600 | 4 | Maximum compatibility |

Format: 8N1 (8 data bits, no parity, 1 stop bit).

### Keyboard Options

| Build option | Keyboard type | Interface | Extra chips |
|---|---|---|---|
| Option 1 (Trainer) | 4×4 hex matrix + 6 control keys | GPIO direct scan | 0 |
| Option 2 (PC) built-in | Rubber QWERTY matrix (on-board, like ZX Spectrum) | GPIO matrix scan | 0 |
| Option 2 (PC) external | PS/2 keyboard (mini-DIN connector on back) | GPIO (clock+data) + 2 pull-ups | 0 |
| Either + USB keyboard | CH9350 adapter ($3) plugs into PS/2 port | USB→PS/2 | 0 |

PC board has BOTH: built-in rubber keyboard for standalone use + PS/2 port for external keyboard.  
When PS/2 keyboard connected, it overrides the built-in matrix (detected via key status register).

---

## 6. Execution Model

- **Fixed 2-byte fetch**: Every instruction is 2 bytes
- **Fetch/Execute overlap** (6502-style): During execute of instruction N, byte 0 of instruction N+1 is prefetched. Most instructions complete in **2 cycles** (not 3).
  - T0: Fetch byte 1 (operand) + execute previous instruction (overlapped)
  - T1: Fetch byte 0 (opcode) of next instruction + writeback
  - Memory-access instructions: +1 cycle (T2 for mem read/write)
- **Accumulator model**: ALU destination is always a0
- **Pointer register pair**: {ph, pl} forms 16-bit address for indirect access
- **Auto-increment**: ptr+ instructions increment {ph,pl} after access
- **Conditional skip**: SKIPZ/SKIPNZ/SKIPC/SKIPNC cause next instruction to execute as NOP if condition fails (eliminates short branches)
- **Constant generator**: x0 produces 0, 1, -1, or 0x80 depending on instruction encoding
- **Direct-encoded control**: Instruction bit fields wire directly to hardware control signals (minimal decode logic)
- **Interrupts**: 2 lines (NMI + IRQ), checked between instructions
- **Undefined opcodes**: Default to HLT (safe stop)
- **Stack overflow protection**: SP wraps (0x00→0xFF) and sets C flag; NMI triggered on overflow

### Cycle Timing (with overlap)

| Instruction type | Cycles | Notes |
|-----------------|--------|-------|
| ALU / immediate / shift / MOV | **2** | Execute overlaps with next fetch |
| Load/Store (ptr, zp, pg, sp+off) | **3** | +1 for memory access |
| Branch (taken) | **3** | +1 to load new PC |
| Branch (not taken) | **2** | No penalty |
| JMP (ptr) | **2** | Load PC from ptr |
| JAL (ptr) | **4** | Push PC + load new PC |
| RET | **4** | Pop PC |
| PUSH/POP | **3** | Memory access |
| Conditional skip (condition true) | **2** | Next instruction becomes NOP |
| Conditional skip (condition false) | **2** | No effect, continue normally |

Average: **~2.3 cycles/instruction** → **~1.5M instructions/sec at 3.5 MHz**

### Interrupt Behavior

| Line | Type | Trigger | Maskable | Vector |
|------|------|---------|----------|--------|
| NMI | Non-maskable | Falling edge | No | 0xFFFA |
| IRQ | Maskable | Level (active low) | Yes (IE flag) | 0xFFFE |

Interrupt sequence (7 cycles):
1. Finish current instruction
2. Push PCH to stack
3. Push PCL to stack
4. Push Flags+IE to stack
5. Clear IE flag (disable further IRQ)
6. Load PC from vector address
7. Begin executing ISR

### Boot Sequence

1. RESET pin held low → all registers cleared
2. On RESET release: PC loads from 0xFFFC-0xFFFD
3. SP initialized to 0xFF (top of stack page 0x30)
4. IE = 0 (interrupts disabled)
5. Flags = 0 (Z=0, C=0, N=0)
6. CPU begins executing from ROM

### Stack Overflow Protection

- SP decrements on PUSH/JAL; increments on POP/RET/RTI
- When SP wraps from 0x00 → 0xFF (overflow) or 0xFF → 0x00 (underflow):
  - C flag is set
  - NMI is triggered (non-maskable — cannot be missed)
  - NMI handler can display error and halt
- Cost: ~10 gates (comparator on SP transitions)
- Prevents silent corruption from deep recursion or runaway PUSH

---

## 7. Estimated Gate Count

| Module | Gates |
|--------|-------|
| Register file (6×8 bits + constant gen mux) | ~220 |
| ALU (8-bit, add/sub/and/or/xor/shift/swap) | ~128 |
| PC (16-bit register + incrementer) | ~70 |
| Instruction register (16-bit) | ~60 |
| Prefetch latch (8-bit, fetch/execute overlap) | ~30 |
| Pointer incrementer (16-bit, for ptr+) | ~20 |
| Flags (Z, C, N) + IE + conditional skip logic | ~35 |
| Interrupt logic (NMI edge detect + IRQ mask) | ~60 |
| Stack overflow detect (SP wrap → NMI) | ~10 |
| Stack-relative adder (sp + offset) | ~25 |
| Zero-page / page-relative address mux | ~15 |
| Control: Direct-encoded FSM (minimal decode) | ~80 |
| Address mux (PC vs ptr vs stack vs zp vs page vs vector) | ~80 |
| Bus buffers/misc | ~40 |
| **Total** | **~873 gates** |

### Design tricks applied:
1. **Direct-encoded instructions** — opcode bits wire to hardware controls, eliminates decode chips
2. **Fetch/execute overlap** — prefetch next opcode during execute (+50% throughput)
3. **Constant generator** — x0 produces {0, 1, -1, 0x80}, eliminates ~20% of LI instructions
4. **Conditional skip** — 1 AND gate on write-enable, eliminates short branches

---

## 8. Build Options

### Option 1A: Trainer — Hex Entry (Minimal)

Bare-bones machine code trainer (like KIM-1).

```
┌─────────────────────────────────────────────┐
│  RV8 TRAINER (HEX)                          │
│                                             │
│  [4-digit 7-segment]  [8 data LEDs]         │
│   addr/data display    bus activity          │
│                                             │
│  ┌───┬───┬───┬───┐                         │
│  │ 0 │ 1 │ 2 │ 3 │                         │
│  ├───┼───┼───┼───┤  16 hex keys             │
│  │ 4 │ 5 │ 6 │ 7 │                         │
│  ├───┼───┼───┼───┤                         │
│  │ 8 │ 9 │ A │ B │                         │
│  ├───┼───┼───┼───┤                         │
│  │ C │ D │ E │ F │                         │
│  └───┴───┴───┴───┘                         │
│                                             │
│  [RUN][BRK][RST][STEP][ADDR][DATA][+][-]    │
│                                             │
│  (USB) (Speaker) (SD) [30-pin SLOT]         │
└─────────────────────────────────────────────┘
```

| Feature | Spec |
|---------|------|
| Display | 4-digit 7-segment (address/data) + 8 LEDs |
| Input | 16 hex keys + 8 control buttons |
| Mode | HEX only (machine code entry) |
| Audio | 8-bit DAC + speaker + audio in |
| Storage | SD card + serial + cassette |
| Debug | Step, trace, breakpoint, register dump (via serial) |
| Slot | Universal bus slot (30-pin) |
| ROM | 32KB (shared ROM, auto-detects board) |
| PCB size | ~80mm × 100mm |
| Chips (peripheral) | ~6 |
| Cost (board only) | ~$12 |

### Option 1B: Trainer — Mini Keyboard (ASM + BASIC)

Full-featured trainer with rubber keyboard and LCD (like a programmable calculator).

```
┌─────────────────────────────────────────────────┐
│  RV8 TRAINER (ASM/BASIC)                        │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │  20×4 LCD display                       │    │
│  │  Line 1: status / address               │    │
│  │  Line 2: instruction / code             │    │
│  │  Line 3: output                         │    │
│  │  Line 4: input prompt                   │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │ Q W E R T Y U I O P  [DEL] [ENT]       │    │
│  │ A S D F G H J K L    [SHF] [MOD]       │    │
│  │ Z X C V B N M , .    [SPC] [BRK]       │    │
│  │ 0 1 2 3 4 5 6 7 8 9  [RUN] [STP]       │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  [8 data LEDs]                                  │
│  (USB) (Speaker) (SD) [30-pin SLOT]             │
└─────────────────────────────────────────────────┘
```

| Feature | Spec |
|---------|------|
| Display | 20×4 LCD (HD44780) + 8 LEDs |
| Input | Mini QWERTY rubber matrix (40+ keys) + control keys |
| Modes | HEX, ASM, BASIC (MODE key switches) |
| Audio | 8-bit DAC + speaker + audio in |
| Storage | SD card + serial + cassette |
| Debug | Step, trace, breakpoint, register display on LCD |
| Slot | Universal bus slot (30-pin) |
| ROM | 32KB (shared ROM, auto-detects board) |
| PCB size | ~120mm × 150mm |
| Chips (peripheral) | ~8 |
| Cost (board only) | ~$20 |

### Trainer comparison

| | 1A (Hex) | 1B (Mini KB) |
|--|----------|-------------|
| Display | 7-segment (4 digits) | 20×4 LCD |
| Input | Hex keypad (16+8 keys) | Mini QWERTY (40+ keys) |
| Modes | HEX only | HEX + ASM + BASIC |
| Can type BASIC? | No (serial only) | ✅ Yes (on-board) |
| Can type assembly? | No (hex bytes only) | ✅ Yes (mnemonics) |
| Size | Small (80×100mm) | Medium (120×150mm) |
| Cost (board) | $12 | $20 |
| Total (CPU+board) | **$60** | **$68** |
| Best for | Learning fetch-execute, machine code | Full standalone programming |

### Option 2: PC-Style Full Computer

A complete home computer (like ZX Spectrum / Apple II).

```
┌─────────────────────────────────────────────────────────┐
│  RV8 COMPUTER                                           │
│                                                         │
│  ┌─────────────────────────────────────────────┐        │
│  │                                             │        │
│  │         TV / Monitor (320×240)              │        │
│  │         16 colors, text + graphics          │        │
│  │                                             │        │
│  └─────────────────────────────────────────────┘        │
│                                                         │
│  ┌─────────────────────────────────────────────┐        │
│  │  Full QWERTY keyboard (PS/2 or USB)         │        │
│  └─────────────────────────────────────────────┘        │
│                                                         │
│  [Gamepad 1] [Gamepad 2] [Joystick 1] [Joystick 2]     │
│  [Serial]    [Audio out]  [Video out]  [GPIO]           │
└─────────────────────────────────────────────────────────┘
```

| Feature | Spec |
|---------|------|
| Display | 320×240 16-color graphics + 40×25 text on TV/VGA |
| Input | Full QWERTY keyboard (PS/2) |
| Audio | 8-bit DAC, amplified speaker output |
| Controllers | 2× NES gamepads + 2× analog joysticks |
| Serial | USB-UART for program loading |
| ROM | 16KB (monitor + full BASIC + drivers) |
| RAM | 32KB (VRAM + BASIC programs + free) |
| Video | Composite or VGA output |
| Power | 5V 2A supply |
| Debug | Step button + 8 LEDs on data bus |
| Cost | ~$110 (breadboard) / ~$125 (PCB) |
| Purpose | Run BASIC, play games, full computer experience |

### Shared CPU Core (identical for both options)

| Component | Option 1 | Option 2 |
|-----------|----------|----------|
| CPU chips | 20 | 20 |
| Clock | 3.5 MHz + step | 3.5 MHz + step (or 10 MHz PCB) |
| ROM | AT28C256 (32KB) | AT28C256 (32KB) — **same ROM image** |
| RAM | 62256 (32KB) | 62256 (32KB) |
| Address decode | 1× 74HC138 | 1× 74HC138 |
| **CPU subtotal** | **~24 chips** | **~24 chips** |

The ROM auto-detects which peripheral board is connected and adjusts I/O accordingly.

### Peripheral differences

| Peripheral | Option 1 (Trainer) | Option 2 (PC) |
|------------|-------------------|---------------|
| Display | 7-seg (4 chips) + LCD (1) | Video circuit (8 chips) + **VGA & composite out** |
| Keyboard | 4×4 rubber matrix + 6 control keys | Rubber QWERTY matrix (on-board) + PS/2 port (external) |
| Sound | **8-bit DAC out + audio in (3 chips)** | 8-bit DAC out + audio in (3 chips) |
| Controllers | None | Gamepads + joysticks (2 chips) |
| **SD card (on-board)** | **✅ SPI via GPIO (0 chips)** | **✅ SPI via GPIO (0 chips)** |
| Storage (extra) | Serial + cassette (audio in/out) | Serial + cassette (audio in/out) |
| **Universal bus slot** | **✅ 30-pin** | **✅ 30-pin** |
| Debug LEDs | 8 LEDs (1 chip) | 8 LEDs (1 chip) |
| **Peripheral subtotal** | **~10 chips** | **~15 chips** |
| **Total system** | **~36 chips** | **~41 chips** |
| **Total cost** | **~$64** | **~$120** |

---

## 9. Design Principles

1. **Minimal**: Every gate must justify its existence
2. **Uniform**: Fixed 2-byte instructions, predictable timing
3. **Accumulator-centric**: Simple data flow, easy to trace
4. **Educational**: Can be understood and built by students
5. **Practical**: Runs full BASIC, plays games (Option 2)
6. **6502 spirit**: Accumulator, stack page, pointer pair
7. **RISC-V naming**: Familiar to modern students
8. **Safe**: Undefined opcodes halt, boot sequence defined
9. **Debuggable**: Step button, LED outputs, monitor program
10. **Scalable**: Same CPU core for trainer and full computer

---

## 10. ROM Contents

### Option 1: Trainer ROM (32KB — same ROM as PC, full featured)

| Offset | Size | Content |
|--------|------|---------|
| 0x0000 | 1.5KB | Monitor (hex mode: edit, step, run, dump, trace, breakpoint) |
| 0x0600 | 512B | Assembly mode (guided entry, disassemble) |
| 0x0800 | 512B | Boot + hardware init + drivers |
| 0x0A00 | 3KB | Floating point library |
| 0x1600 | 2KB | Math functions (SIN, COS, SQR, LOG, EXP) |
| 0x1E00 | 1KB | String handling |
| 0x2200 | 1.5KB | Tokenizer + line editor |
| 0x2800 | 1.5KB | Expression parser |
| 0x2E00 | 2KB | Statement executor |
| 0x3600 | 2KB | Assembler (mnemonics + labels + comments + macros) |
| 0x3E00 | 1KB | Disassembler |
| 0x4200 | 256B | Storage driver (serial + cassette + SD) |
| 0x4300 | 256B | Mode switcher + LCD/7-seg driver |
| 0x4400 | ~27KB | Free (same ROM works for both trainer and PC) |
| 0x7FFA | 6B | Vectors (NMI, RESET, IRQ) |

Note: Trainer and PC use the **same 32KB ROM**. The ROM detects which board it's on (via I/O register) and adjusts output (LCD vs video, keypad vs keyboard).

### Option 2: Full Computer ROM (16KB)

| Offset | Size | Content |
|--------|------|---------|
| 0x0000 | 512B | Monitor (hex edit, dump, step, run) |
| 0x0200 | 512B | Boot + hardware init + drivers |
| 0x0400 | 3KB | Floating point library |
| 0x1000 | 2KB | Math functions (SIN, COS, SQR, LOG, EXP) |
| 0x1800 | 1KB | String handling |
| 0x1C00 | 1.5KB | Tokenizer + line editor |
| 0x2200 | 1.5KB | Expression parser |
| 0x2800 | 2KB | Statement executor |
| 0x3000 | 768B | Video + sound + keyboard drivers |
| 0x3300 | 2KB | Assembler (mnemonics + labels + comments + simple macros) |
| 0x3B00 | 1KB | Disassembler |
| 0x3F00 | 256B | Storage driver (serial + cassette + SD card) |
| 0x3FFA | 6B | Vectors (NMI, RESET, IRQ) |

### Assembler Features

| Feature | Supported | ROM cost |
|---------|-----------|----------|
| All 60 mnemonics | ✅ | ~230B (table) |
| Register names (A0, SP, PL, PH) | ✅ | ~50B |
| Hex literals ($FF) and decimal (255) | ✅ | ~100B |
| Labels (forward + backward) | ✅ | ~300B + RAM symbol table |
| Comments (; to end of line) | ✅ | ~20B |
| Simple macros (.def NAME = ...) | ✅ | ~500B + RAM macro table |
| Parameterized macros | ❌ | — |
| Include files | ❌ | — |
| Expressions in operands | ❌ | — |

### Disassembler Features

- Opcode → mnemonic + operand display
- Hex dump alongside (addr: XX XX  MNEMONIC)
- Branch target shown as absolute address
- Undefined opcodes shown as `???`

---

## 11. External Storage

### Three storage options (all supported)

| Method | Hardware | Speed | Capacity | Use case |
|--------|----------|-------|----------|----------|
| **Serial upload** | UART (already present) | 9600 baud = 1KB/s | PC disk (unlimited) | Development, bulk transfer |
| **Cassette** | 3.5mm audio jack + cable | 1200 baud = 150B/s | Any recorder/phone | Cheap, retro, offline |
| **SD card** | SD module on GPIO (SPI bit-bang) | ~5KB/s | 32GB | Fast, large, portable |

### Serial Upload/Download

Uses existing UART. No extra hardware.

```basic
SAVE *                ' Send program to PC via serial (hex format)
LOAD *                ' Receive program from PC via serial
```

PC side: any terminal program with send/receive file (PuTTY, minicom, custom Python script).

### Cassette Interface

Audio encoding (Kansas City standard / ZX Spectrum style):
- 1200 Hz = logic 0, 2400 Hz = logic 1
- Header tone (5 seconds) for sync
- 8-bit bytes, LSB first

Hardware: 1 resistor + 1 capacitor + 3.5mm jack (output)  
Input: comparator (1× LM393, $0.30) + 3.5mm jack

```basic
CSAVE "GAME1"         ' Save to cassette (press record first)
CLOAD "GAME1"         ' Load from cassette (press play)
```

Works with any phone/recorder — students can share programs as audio files!

| Part | Cost |
|------|------|
| 2× 3.5mm audio jack | $1 |
| 1× LM393 comparator | $0.30 |
| Resistors + caps | $0.20 |
| **Total** | **$1.50** |

### SD Card

SPI bit-banged through GPIO port. No extra chips.

```
GPIO wiring:
  Out bit 0 → MOSI
  Out bit 1 → SCK
  Out bit 2 → CS
  In  bit 0 ← MISO
```

Simple custom filesystem (not FAT — saves ~1.5KB ROM):
- 64 file slots × 256 bytes each = 16KB directory area on SD
- Each file: name (8 chars) + start sector + length
- Max file size: 32KB (entire RAM image)

```basic
SAVE "GAME1"          ' Save BASIC program to SD
LOAD "GAME1"          ' Load from SD
DIR                   ' List files on SD
DELETE "OLD"          ' Remove file
BSAVE "CODE",&H4000,&H4100  ' Save binary block
BLOAD "CODE",&H4000          ' Load binary to address
```

| Part | Cost |
|------|------|
| SD card module (with level shifter) | $2.50 |
| SD card (any size) | $3 |
| **Total** | **$5.50** |

---

## 12. Physical Build Targets

### Breadboard (both options)

| Parameter | Option 1 | Option 2 |
|-----------|----------|----------|
| Breadboards | 4 | 7 |
| Clock | 3.5 MHz | 3.5 MHz |
| Decoupling caps | 3 | 3 |
| Build time | 4-5 weeks | 8-10 weeks |

### PCB (both options)

| Parameter | Option 1 | Option 2 |
|-----------|----------|----------|
| PCB layers | 2 | 2 |
| Clock | 10 MHz | 10 MHz |
| Decoupling caps | 5 (grouped) | 7 (grouped) |
| Board size | 100×100mm | 150×100mm |
| PCB cost | ~$10 | ~$15 |

### Clock System (both options)

```
                 ┌─────────────┐
  Crystal ───────┤             │
  (3.5/10 MHz)  │  74HC157    ├──── CPU clock
                │  (2:1 mux)  │
  Step button ──┤             │
  (debounced)   └─────────────┘
                       ▲
                  Mode switch
                  (RUN / STEP)
```

### Debug Features (both options)

| Feature | Implementation |
|---------|---------------|
| 8× LEDs on data bus | 8 LEDs + 330Ω resistors on D[7:0] |
| 2× LEDs on state | State counter bits → LEDs |
| 1× LED clock | Clock line → LED (visible in step mode) |
| 1× LED HALT | Halt signal → LED |
| 1× LED IRQ | In-ISR flag → LED |
| Step button | Debounced, advances 1 clock cycle |
| RUN/STEP switch | Selects clock source |
| RESET button | Resets CPU to boot vector |

### Power System

| Source | Voltage | Regulation | Use case |
|--------|---------|-----------|----------|
| USB (Type-C or Micro-B) | 5V direct | None needed | Desktop use, always-on |
| Li-ion 18650 (3.7V) | 3.7-4.2V | Boost to 5V (MT3608) | Portable |
| USB power bank | 5V direct | None needed | Portable, simplest |
| 4× AA batteries (6V) | 6V | 7805 regulator | No USB available |

Design target:
- **5V operation** (all standard parts)
- **Low heat**: Total system draw ~185mA @ 5V = 0.9W (no heatsink needed)
- **Low noise**: No switching regulator on board; use external USB or linear reg
- Power LED + reverse polarity protection (1N5817 Schottky diode)
- Auto-power-off: optional (sleep on HLT, wake on button/serial)

| Spec | Value |
|------|-------|
| Operating voltage | 5V ±5% |
| Current draw | ~185mA (Option 1) / ~250mA (Option 2) |
| Power dissipation | <1.3W (no heatsink) |
| Battery life (10000mAh bank) | ~40+ hours |
| Battery life (2500mAh 18650) | ~10 hours |

### Expansion Slot

Edge connector or pin header for hardware expansion:

```
Expansion Bus (active at 0x80F0-0x80FF):
  D[7:0]     — 8-bit data bus (active accent)
  A[3:0]     — 4-bit address (16 registers per card)
  /CS_EXP    — Chip select (active when 0x80Fx accessed)
  R/W        — Read/Write direction
  CLK        — System clock
  /IRQ       — Interrupt request (active low, active-ored)
  /RESET     — System reset
  VCC, GND   — Power (5V, up to 200mA)
  Total: 20 pins
```

| Pin | Signal | Direction |
|-----|--------|-----------|
| 1 | GND | Power |
| 2 | VCC (5V) | Power |
| 3-10 | D[7:0] | Bidirectional |
| 11-14 | A[3:0] | Output (from CPU) |
| 15 | /CS_EXP | Output |
| 16 | R/W | Output |
| 17 | CLK | Output |
| 18 | /IRQ | Input (active low) |
| 19 | /RESET | Output |
| 20 | GND | Power |

Expansion card examples:
- Extra ROM (bank-switched, 64KB+)
- WiFi module (ESP8266)
- Real-time clock (DS1307)
- Additional serial ports
- Parallel printer port
- Music synthesizer (YM2149 / SN76489)

---

## 13. Performance

| Platform | Clock | Instr/sec | BASIC lines/sec | Equivalent |
|----------|-------|-----------|-----------------|------------|
| Breadboard | 3.5 MHz | ~1.0M | ~300 | ZX Spectrum |
| PCB | 10 MHz | ~2.8M | ~850 | BBC Micro |

---

## 14. Success Criteria

- [ ] All 64 instructions execute correctly in simulation
- [ ] Total gate count < 900 (excluding memory)
- [ ] Option 1: Monitor + mini assembler works (hex edit, assemble, step, run)
- [ ] Option 2: Full BASIC interpreter runs with floating point
- [ ] Option 2: Assembler with labels, comments, and simple macros works
- [ ] Option 2: Disassembler correctly decodes all 55 instructions
- [ ] Option 2: 320×240 16-color graphics and 40×25 text mode work
- [ ] Option 2: 8-bit D/A sound with background playback via IRQ
- [ ] Option 2: NES gamepads and analog joysticks read correctly
- [ ] Option 2: SAVE/LOAD works via serial, cassette, and SD card
- [ ] Both: Debug step button allows single-cycle execution
- [ ] Both: Stable at 3.5 MHz on breadboard
- [ ] Both: Stable at 10 MHz on PCB
- [ ] Both: Undefined opcodes halt safely
- [ ] Both: Fully documented for educational use

---

## 15. Curriculum Roadmap

| Week | Theory | Build | Program |
|------|--------|-------|---------|
| 1 | Binary, logic gates, Boolean algebra | — | — |
| 2 | Flip-flops, registers, counters | Build register + LED display | — |
| 3 | ALU design, adders, logic ops | Build 8-bit ALU | — |
| 4 | State machines, sequencing | Build clock + state counter | — |
| 5 | CPU architecture, fetch-execute | Wire CPU core (PC, IR, regs, ALU) | — |
| 6 | Control logic, instruction decode | Wire control (decoders, AND/OR) | Test NOP/HLT |
| 7 | Memory interfacing, address decode | Add ROM + RAM | Hand-enter first program |
| 8 | I/O, serial communication | Add UART | "Hello World" via serial |
| — | **Option 1 complete here** | — | — |
| 9 | Video signals, timing | Build video circuit | Draw pixels |
| 10 | Sound, DAC, interrupts | Add DAC + enable IRQ | Play tones |
| 11 | Input devices, polling vs interrupt | Add keyboard + gamepads | First game |
| 12 | Software: BASIC internals | — | Write/modify BASIC programs |

---

## 16. Documentation Deliverables

| Document | Format | Purpose |
|----------|--------|---------|
| Full schematic | PDF/KiCad | Wiring reference |
| Chip pinout cheat sheet | 1-page PDF | Quick lookup during build |
| Instruction set card | 1-page PDF | Assembly programming reference |
| Memory map poster | A3 poster | Address space at a glance |
| BASIC quick reference | 2-page PDF | Programming guide |
| Troubleshooting guide | PDF | "LED shows X, means Y" |
| Build photos (step by step) | Web/PDF | Visual assembly guide |
| Verilog source | GitHub | Simulation and FPGA synthesis |
| ROM hex files | .hex | Ready to burn to EEPROM |

---

## 17. Ecosystem

### Software Tools (free, open source)

| Tool | Purpose |
|------|---------|
| Web emulator/simulator | Run RV8 in browser with animated datapath visualization |
| Cross-assembler | Write assembly on PC, output ROM hex file |
| ROM builder | Package BASIC + user code into flashable ROM image |
| C compiler (subset) | Compile simple C (int, char, if, while, functions) to RV8 |
| ROM flasher | Burn hex files to EEPROM via serial connection |

### Progressive Kit Stages

| Stage | What | Cost | Cumulative |
|-------|------|------|-----------|
| 1 | ALU (2 chips + LEDs) | $5 | $5 |
| 2 | Registers + clock (3 chips) | $8 | $13 |
| 3 | CPU core (22 chips total) | $25 | $38 |
| 4 | Memory (ROM + RAM + decode) | $10 | $48 |
| 5 | Trainer peripherals | $16 | $64 |
| 6 | PC peripherals | $75 | $123 |

### Community Platform

- Program library (download/share games, tools, demos)
- ROM image repository (pre-made cartridges)
- Expansion card designs (open-source schematics)
- Forum / Discord (questions, show-and-tell)
- Challenge ladder (progressive problems: "blink LED" → "write Tetris")
- Student showcase (gallery of completed projects)

### FPGA Version

Same RV8 ISA implemented in Verilog, runs on iCE40 FPGA ($25).
Students can modify the CPU design itself — add instructions, change timing,
experiment with architecture. Same programs run on both hardware and FPGA.

---

## 18. Out of Scope

- Hardware multiply/divide
- Floating point hardware
- DMA
- Cache
- Multi-core
- Privilege levels
- Interrupt nesting / priority logic (beyond 2 lines)
- MMU / memory protection

---

*Next Phase: Architecture Design Document (Phase 3)*
