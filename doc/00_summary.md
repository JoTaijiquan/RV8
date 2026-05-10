> **⚠️ HISTORICAL DOCUMENT** — This captures the design discussion. For the verified final spec, see `doc/05_isa_reference.md` and `doc/04_architecture.md`.

# RV8 Project — Design Discussion Summary

**Date**: 2026-05-10  
**Status**: Phase 1-2 complete (Requirements + ISA Design)

---

## Project Overview

RV8 is a minimal 8-bit educational CPU inspired by the 6502 but using RISC-V naming conventions. It's designed to be built by students on breadboard using discrete 74HC logic chips, capable of running a full BASIC interpreter and ZX Spectrum-style games.

---

## Design Decisions Made (Chronological)

### 1. Why 8-bit instead of 32-bit RV32I?

- RV32I requires ~15,000 gates — impractical for breadboard
- 8-bit reduces gates by ~18× (from ~15,000 to ~848)
- Same educational value for understanding CPU fundamentals
- Matches 6502/Z80 era — proven for education

### 2. Register count: 8 → 4 → 5

- Started with 8 registers (3-bit encoding) = 830 gates
- Reduced to 4 registers (2-bit encoding) = 610 gates, frees opcode bits
- Final: 5 registers (3-bit encoding) to support full BASIC
  - x0=zero, x1=sp, x2=a0, x3=pl, x4=ph
  - Pointer pair {ph,pl} needed for 16-bit addressing

### 3. Instruction format: Variable → Fixed 2-byte

- Variable (1-3 bytes) requires length decoder, complex fetch FSM
- Fixed 2-byte: PC always +2, fetch is trivial (T0+T1+execute)
- Wastes 1 byte on simple instructions but saves ~3 chips
- Every instruction = 2 hex digits — easy for students to hand-assemble

### 4. Accumulator-only model (not register-to-register)

- Register-to-register needs dst mux (+1 chip, +40 gates)
- Accumulator: all ALU results go to a0 implicitly
- Saves encoding bits — don't need dst field in instruction
- Matches 6502 model (proven for 8-bit)
- With only 5 registers, most ops flow through a0 anyway

### 5. Auto-increment pointer (ptr+)

- Critical for BASIC: string scanning, array access, block copy
- 40% fewer instructions in inner loops
- Cost: ~20 gates (16-bit incrementer on ptr pair)
- Decided: YES — worth it

### 6. Branch offset: byte-relative

- Byte-offset (±127 bytes) vs instruction-offset (±254 bytes)
- Byte-offset: simpler hardware (no shift), sufficient range
- ±127 bytes = ~63 instructions of reach — enough for all loops
- For longer jumps: use JMP (ptr)

### 7. Stack: 8-bit SP on fixed page

- 8-bit SP: address = {0x30, SP} — hardwired high byte, zero logic
- 16-bit SP would cost +105 gates for a feature never needed
- 256 bytes = 128 nested calls — more than enough
- Added stack overflow protection: SP wrap triggers NMI (+10 gates)

### 8. Control: Microcode ROM → Hardwired

- Microcode ROM (AT28C16, 150ns): limits clock to ~3 MHz
- Hardwired (8× 74HC logic): works at 20+ MHz, no speed limit
- Same chip count (~22), cheaper ($5 vs $10)
- Hardwired chosen for 3.5 MHz breadboard / 10 MHz PCB targets
- In Verilog: both look identical (case statement)

### 9. Clock: 3.5 MHz breadboard / 10 MHz PCB

- 74HC at 5V: reliable to ~12 MHz on PCB
- Breadboard limited by wiring capacitance to ~5 MHz
- 3.5 MHz chosen (matches ZX Spectrum, comfortable margin)
- PCB version: same chips, just faster clock
- Debug step button for single-cycle execution

### 10. Video: ZX Spectrum style (320×240, 16 colors)

- Compared Apple II, C16, ZX Spectrum, NES
- ZX Spectrum won: simplest video hardware (~8 chips), students build it
- 1bpp bitmap + attribute color (16 colors per 8×8 cell)
- Text mode (40×25) for BASIC
- No co-processor needed — all discrete logic

### 11. Sound: 8-bit DAC (both boards)

- R-2R ladder DAC + LM386 amplifier + LM393 comparator
- Audio OUT: 8-bit DAC → 3.5mm jack (sound + CSAVE)
- Audio IN: 3.5mm jack → comparator → GPIO (CLOAD)
- ~15 kHz sample rate (CPU-driven via IRQ)
- Cost: ~$3, 3 chips
- On BOTH Trainer and PC boards (identical)

### 12. Interrupts: 2 lines (NMI + IRQ)

- 0 interrupts: no background sound possible
- 1 IRQ: sound + vsync share line (complex ISR)
- 2 (NMI + IRQ): each has own handler — clean separation
- NMI = vsync (60 Hz), IRQ = sound timer (15 kHz)
- Cost: +60 gates, 0 extra chips
- Also used for stack overflow detection

### 13. No DMA

- +250 gates, +7 chips (30% bigger CPU)
- Sound works fine via IRQ (3% CPU)
- Screen clear: use hardware scroll register or dirty rectangles
- Not worth the complexity for education

### 14. No hardware multiply/divide

- +150-400 gates
- Every 8-bit BASIC computer (Apple II, ZX Spectrum, C64) worked without it
- Software multiply: 23µs (unnoticeable in BASIC)
- Students learn shift-and-add algorithm (more educational)

### 15. No floating point hardware

- Would 3-4× the gate count (~2500-3500 gates)
- Software FP in ROM: ~3KB, works fine
- Same approach as all 8-bit micros

### 16. Storage: Serial + Cassette + SD card (all on both boards)

- Serial: free (existing UART), 1KB/s, for PC development
- Cassette: via audio in/out jacks (already on board for sound), retro fun
- SD card: on-board module, SPI via GPIO bit-bang, fast + large
- All three methods available on BOTH Trainer and PC boards

### 17. Assembler + Disassembler in ROM

- 58 instructions with regular encoding = tiny lookup table
- Assembler: ~2KB (mnemonics + labels + comments + simple macros)
- Disassembler: ~1KB
- Fits in 16KB ROM alongside full BASIC

### 18. Two build options (modular PCB design)

- **CPU Card**: 26 chips, $48 — universal, never changes
- **Option 1 (Trainer)**: +10 chips, +$16 — LCD, keypad, 7-seg, sound, SD, slot
- **Option 2 (PC)**: +17 chips, +$75 — video, sound, keyboard, gamepads, SD, cassette, slot
- Both boards have: 8-bit sound (in+out), SD card, serial, universal bus slot
- Same CPU card plugs into either board

### 19. Power: 5V USB

- 5V chosen: all standard parts work, more forgiving on breadboard
- USB powered (Type-C or Micro-B)
- Battery: USB power bank (40+ hours) or 18650 + boost
- Total draw: ~185-250mA = <1.3W (no heatsink, low heat)

### 20. Universal Bus Slot (30-pin, on both boards)

- Maps to 0x4000-0x7FFF (16KB address window)
- Full bus: D[7:0], A[13:0], /CS, /RD, /WR, CLK, /IRQ, /NMI, /RESET, 5V
- Hot-pluggable (card detect pin)
- Accepts: ROM cartridges, RAM, I/O cards, co-processors, prototyping cards
- Expandable to 8 sub-slots via expander card (1× 74HC138, $10)
- On BOTH Trainer and PC boards (same connector)

### 21. RISC-V features added (minimal cost)

- ECALL (system call): 0 gates, reuses interrupt mechanism
- EBREAK (breakpoint): 0 gates, reuses halt
- WFI (wait for interrupt): +5 gates, enables low-power sleep
- x0 = zero: RISC-V convention
- Register naming: sp, a0 (RISC-V ABI names)

### 22. PC-relative addressing: REJECTED

- Would need +1-2 chips for address mux expansion
- Only saves 4 bytes per use, rarely needed
- ±127 byte range too limiting for most data access
- ptr method (LI ph + LI pl + LB) works fine

### 23. Classification: RISC-CISC hybrid

- RISC traits: fixed-length, load/store, simple decode, hardwired control
- CISC traits: accumulator, flags, PUSH/POP, auto-increment, few registers
- Best described as "RISC-inspired accumulator machine"

---

## Final Specification Summary

### CPU Core (fixed, never changes)

| Parameter | Value |
|-----------|-------|
| Name | RV8 |
| Data bus | 8-bit |
| Address bus | 16-bit (64KB) |
| Instructions | 68 (fixed 2-byte, direct-encoded) |
| Registers | 7 (c0/const-gen, sp, a0, pl, ph, t0, pg) |
| Flags | Z, C, N + IE |
| ALU | ADD, SUB, ADC, SBC, AND, OR, XOR, CMP, shift, rotate, SWAP |
| Interrupts | NMI + IRQ |
| Clock | 3.5 MHz (breadboard) / 10 MHz (PCB) |
| Gate count | ~873 |
| CPU chips | 20 (74HC, direct-encoded FSM, fetch/execute overlap) |
| Control | Hybrid FSM + direct-encoded bits + conditional skip |
| Performance | ~1.5M instr/sec @ 3.5 MHz (50% faster via overlap) |
| Power | 5V USB, <1.3W |

### Base System (simple and clean)

| Component | Spec | Notes |
|-----------|------|-------|
| CPU | 20 chips (74HC) | Direct-encoded FSM, fetch/execute overlap |
| ROM | 32KB (AT28C256) | **Fixed** — soldered or ZIF socket, always present |
| RAM | 32KB (62256) | Fixed, always present |
| Address decode | 1× 74HC138 | ROM / RAM / I/O / slot select |
| Clock | Crystal + step button | RUN/STEP switch |
| Debug | 13 LEDs (data bus + state + halt + IRQ) | Always visible |
| **CPU card total** | **24 chips, ~$45** | **One PCB, works with any peripheral board** |

### Optional Upgrades (plug-in, not on CPU card)

All upgrades plug into the **Universal Bus Slot** (30-pin, on both Trainer and PC boards):

| Card type | What it adds | Cost |
|-----------|-------------|------|
| ROM cartridge (32KB) | Game / app / data | $6 |
| Banked ROM cartridge (up to 4MB) | Large games, multiple programs | $8 |
| RAM expansion (16-512KB) | More program/data space | $4-8 |
| Sound card (YM2149) | 3-channel music | $10 |
| WiFi card (ESP-01) | Internet access | $5 |
| I/O card (relays, sensors) | Real-world control | $5-10 |
| Prototyping card (blank) | Student's own hardware | $3 |
| Co-processor card | Math accelerator, etc. | $10+ |

Peripheral boards (Trainer / PC) add:

| Peripheral board | What it adds | Cost |
|-----------------|-------------|------|
| Trainer board | LCD + keypad + LEDs + 8-bit sound + SD + cassette + slot | $16 |
| Full PC board | Video + 8-bit sound + keyboard + SD + cassette + gamepads + slot | $75 |

### Design Philosophy

```
┌─────────────────────────────────────────────────────┐
│  CPU CARD (always the same, simple, clean)          │
│  24 chips = CPU + fixed ROM + RAM + clock           │
└──────────────────────┬──────────────────────────────┘
                       │ 40-pin bus connector
          ┌────────────┼────────────┐
          ▼            ▼            ▼
    ┌──────────┐ ┌──────────┐ ┌──────────┐
    │ Trainer  │ │ Full PC  │ │ Custom   │
    │  $16     │ │  $75     │ │  $??     │
    └────┬─────┘ └────┬─────┘ └────┬─────┘
         │             │             │
         ▼             ▼             ▼
    ┌──────────────────────────────────────┐
    │  UNIVERSAL BUS SLOT (30-pin)         │
    │  Same connector on ALL boards        │
    │  Accepts: ROM, RAM, I/O, custom HW   │
    └──────────────────────────────────────┘
```

- Base = minimal and understandable (26 chips)
- Fixed ROM = system (BASIC + monitor, always present)
- Universal slot = content + expansion (hot-pluggable)
- All complexity lives on plug-in cards (not CPU)
- Students start simple, design their own cards as advanced projects
- Same CPU card from day 1 to final project

---

## Instruction Set (64 instructions)

| Group | Instructions |
|-------|-------------|
| ALU (8) | ADD, SUB, AND, OR, XOR, CMP, ADC, SBC |
| Immediate (13) | LI×6, ADDI, SUBI, CMPI, ANDI, ORI, XORI, TST |
| Load/Store (12) | LB/SB ptr, LB/SB ptr+, MOV×2, LB/SB sp+imm, LB/SB zp+imm, LB/SB pg:imm |
| Stack (2) | PUSH, POP |
| Branch (7) | BEQ, BNE, BCS, BCC, BMI, BPL, BRA |
| Jump (3) | JMP(ptr), JAL(ptr), RET |
| Shift/Unary (8) | SHL, SHR, ROL, ROR, INC, DEC, NOT, SWAP |
| Pointer (3) | INC16, DEC16, ADD16 |
| System (8) | CLC, SEC, EI, DI, RTI, TRAP, NOP, HLT |

---

## SDLC Progress

| Phase | Status | Document |
|-------|--------|----------|
| 1. Requirements | ✅ Complete (v4) | `docs/01_requirements.md` |
| 2. ISA Design | ✅ Complete (v3) | `docs/02_isa_design.md` |
| 3. Architecture | ⬜ Next | Datapath, FSM, bus timing |
| 4. Implementation | ⬜ | Verilog RTL |
| 5. Verification | ⬜ | Testbench + simulation |

---

## Key Comparisons

| | 6502 | RV8 | Z80 | RISC-V RV32I |
|--|------|-----|-----|-------------|
| Gates | ~3,500 | **~873** | ~8,500 | ~15,000 |
| Registers | 3 | 7 | 14 | 32 |
| Instruction size | 1-3B | **2B fixed** | 1-4B | 4B fixed |
| Clock (typical) | 1 MHz | **3.5 MHz** | 3.5 MHz | 100+ MHz |
| Buildable on breadboard | ~40 chips | **~20 chips** | ~60 chips | Not practical |
| Cost to build | ~$150 | **$60-120** | ~$200+ | N/A |

---

## Educational Value

- **Jr High (13-15)**: Option 1 Trainer, teacher-guided, 6 weeks
- **High School (15-18)**: Option 2 Full computer, student-built, 10 weeks
- **Key learning**: Binary, logic gates, CPU architecture, assembly, BASIC, electronics
- **Unique value**: Real hardware, single-step visible execution, no abstraction layers

---

## Ecosystem & Learning Path

### Software Tools (free, open source)

| Tool | Purpose | Platform |
|------|---------|----------|
| Web emulator | Run RV8 programs in browser, zero install | JavaScript |
| Visual CPU simulator | Animated datapath, see bits flowing | Web |
| Cross-assembler | Write assembly on PC, output ROM hex | Python/JS |
| ROM builder | Package BASIC + assembler + user code into ROM image | CLI tool |
| C compiler (subset) | Compile simple C to RV8 assembly | PC |
| ROM flasher | Burn hex files to EEPROM via serial | Python |

### Progressive Kit Stages

| Stage | Contents | What student learns | Cost |
|-------|----------|--------------------|----- |
| 1 | ALU kit (2 chips + LEDs + breadboard) | Binary math, logic gates | $5 |
| 2 | Register + clock kit (3 chips) | Flip-flops, state machines | $8 |
| 3 | CPU core kit (full 20 chips) | Fetch-decode-execute cycle | $23 |
| 4 | Memory kit (ROM + RAM + decode) | Address space, programs | $10 |
| 5 | Trainer peripheral kit | I/O, display, keyboard, sound | $16 |
| 6 | PC peripheral kit | Video, full keyboard, gamepads | $75 |

Each stage works standalone and builds on the previous. Student never faces all chips at once.

### Curriculum (12 modules)

| Module | Topic | Weeks | Kit stage |
|--------|-------|-------|-----------|
| 1 | Number systems (binary, hex, ASCII) | 1 | Paper only |
| 2 | Logic gates (AND, OR, NOT, truth tables) | 1 | Stage 1 |
| 3 | Building an ALU (add, subtract, compare) | 1 | Stage 1 |
| 4 | Memory and state (flip-flops, registers) | 1 | Stage 2 |
| 5 | How a CPU works (fetch-decode-execute) | 2 | Stage 3 |
| 6 | Machine code by hand (hex entry) | 1 | Stage 4 |
| 7 | Assembly language programming | 2 | Stage 5 |
| 8 | BASIC programming | 2 | Stage 5/6 |
| 9 | Making a game (graphics + input + sound) | 2 | Stage 6 |
| 10 | Design your own hardware (expansion card) | 2 | Universal slot |
| 11 | Networking and IoT | 1 | WiFi card |
| 12 | Operating systems concepts | 1 | Full system |

### Physical Computing Projects

| Project | Teaches | Hardware needed |
|---------|---------|----------------|
| Traffic light controller | State machines, timing | 3 LEDs + slot card |
| Temperature logger | ADC, data storage, display | Sensor + SD |
| Music synthesizer | Waveforms, DAC, math | Sound system (on-board) |
| Robot controller | PWM, sensors, feedback | Motor driver card |
| Weather station | I2C sensors, display | Sensor card + LCD |
| Home automation | Relays, scheduling, RTC | Relay card |
| Oscilloscope | ADC sampling, real-time display | ADC + video |
| Game console | Graphics, input, game design | Full PC system |

### FPGA Version (advanced)

| Parameter | Value |
|-----------|-------|
| Board | iCE40 FPGA (Lattice iCEstick, $25) |
| Purpose | Same RV8 ISA in Verilog, modify CPU design in minutes |
| Use case | "What if I add a new instruction?" → edit → synthesize → test |
| Compatibility | Same programs run on FPGA and breadboard versions |
| Educational value | Bridge from hardware build to chip design |

### Community Platform

| Feature | Purpose |
|---------|---------|
| Program library (web) | Download/share games, tools, demos |
| ROM image repository | Flash pre-made cartridges |
| Expansion card designs | Open-source schematics for slot cards |
| Forum / Discord | Questions, show-and-tell, collaboration |
| Challenge ladder | Progressive problems from "blink LED" to "write Tetris" |
| Student showcase | Gallery of completed projects |

### Student Journey

```
  ┌─────────────────────────────────────────────────────────────┐
  │                                                             │
  │  Simulator (free)                                           │
  │  → Understand CPU in browser, write first program           │
  │       ↓                                                     │
  │  Stage 1-2 ($13)                                            │
  │  → Build ALU + registers, see bits on LEDs                  │
  │       ↓                                                     │
  │  Stage 3-4 ($35)                                            │
  │  → Complete CPU runs first program!                         │
  │       ↓                                                     │
  │  Stage 5 ($16)                                              │
  │  → Trainer: hex entry, assembly, monitor, sound             │
  │       ↓                                                     │
  │  Stage 6 ($75)                                              │
  │  → Full computer: BASIC, games, video, keyboard             │
  │       ↓                                                     │
  │  Universal slot                                             │
  │  → Design own hardware cards (imagination unlimited)        │
  │       ↓                                                     │
  │  FPGA version ($25)                                         │
  │  → Modify the CPU itself (become a chip designer)           │
  │       ↓                                                     │
  │  Share online                                               │
  │  → Community, collaboration, inspiration                    │
  │                                                             │
  └─────────────────────────────────────────────────────────────┘

  From "what is binary?" to "I designed my own computer"
  — all on one platform, one ISA, one ecosystem.
```

---

## Files

```
/home/jo/kiro/riscv/docs/
├── 01_requirements.md    (v4, complete)
├── 02_isa_design.md      (v3, complete)
└── 00_summary.md         (this file)
```
