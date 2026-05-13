# RV8 Project — Task Tracker

**Last updated**: 2026-05-14 00:44

---

## ✅ Completed

### RV8 (26-chip parallel CPU)
- [x] ISA design (68 instructions)
- [x] Architecture doc
- [x] Verilog model (69/69 tests pass)
- [x] Circuit diagram (pin-level, 26 chips)
- [x] Build guide (12 labs, Thai+English, pin wiring tables)
- [x] KiCad schematic
- [x] Assembler (rv8asm.py)
- [x] Board redesign (removed clock mux, 4-board system)

### RV808 (23-chip Harvard CPU)
- [x] Architecture design (Harvard, page:offset)
- [x] ISA (67 instructions, encoding table)
- [x] Verilog model (44/44 tests pass)
- [x] Circuit diagram (pin-level, 23 chips)
- [x] Build guide (8 labs, Thai+English, pin wiring tables)
- [x] MOV + JMP instructions added
- [x] Memory map (code overlay, ROM banking)
- [x] Expansion slots (4 pre-decoded)

### RV801 (8-9 chip bit-serial)
- [x] Spec document (RV801-A and RV801-B)
- [x] Circuit diagram

### Programmer Board
- [x] Design (ESP32 NodeMCU + 3× TXB0108 level shifters)
- [x] Schematic (GPIO mapping, wiring)
- [x] ESP32 firmware (rv8_programmer.ino)
- [x] PC tools (rv8flash.py, rv8term.py)
- [x] Bootloader (bootloader.asm, alternative method)
- [x] Thai documentation

### Infrastructure
- [x] 40-pin bus spec (SYNC pin 37, 4 slots)
- [x] 5 specialized agents (lead, rtl, docs, hw, sw)
- [x] Session memory (rv8_memory.md)
- [x] README with family comparison

---

## 🔧 In Progress

(nothing currently active)

---

## ⬜ TODO — Hardware Build

| Task | Priority | Agent | Notes |
|------|:--------:|:-----:|-------|
| Build Programmer board | HIGH | hw | ESP32 + TXB0108 + 40-pin, ~$10 |
| Build RV801-B breadboard | HIGH | hw | 9 chips, 1 breadboard, fastest build |
| Build RV8 breadboard | MEDIUM | hw | 26 chips, 4 breadboards |
| Build RV808 breadboard | MEDIUM | hw | 23 chips, 3 breadboards |
| Trainer board build | LOW | hw | After CPU boards work |

## ⬜ TODO — Software

| Task | Priority | Agent | Notes |
|------|:--------:|:-----:|-------|
| rv808asm.py assembler | HIGH | sw | Encode 67 instructions |
| BASIC interpreter (ROM) | HIGH | sw | The "killer app" |
| Test programs (RV808) | MEDIUM | sw | Fibonacci, hello world, etc. |
| RV801 Verilog model | MEDIUM | rtl | Complete the family |
| Monitor ROM (debug tool) | LOW | sw | Memory dump, register view |

## ⬜ TODO — Documentation

| Task | Priority | Agent | Notes |
|------|:--------:|:-----:|-------|
| RV808 ISA reference (full) | MEDIUM | docs | Like RV8's 04_isa_reference.md |
| Trainer board design doc | MEDIUM | docs | LEDs, 7-seg, SD, keyboard spec |
| Bus timing specification | LOW | docs | Setup/hold times for expansion cards |
| Curriculum guide | LOW | docs | 4-semester plan |

## ⬜ TODO — PCB / Production

| Task | Priority | Agent | Notes |
|------|:--------:|:-----:|-------|
| RV808 PCB layout | LOW | hw | JLCPCB, smallest board |
| Video card design | LOW | hw | FPGA/ESP32, text 40×25, HDMI |
| SD card interface | LOW | hw | SPI on expansion slot |
| Sound chip (SN76489) | LOW | hw | On expansion slot |

---

## Priority Order (recommended)

```
1. Build Programmer board → can flash ROM, test any CPU
2. Write rv808asm.py → can write programs for RV808
3. Build RV801-B → quickest physical CPU (9 chips)
4. Write BASIC interpreter → makes the computer useful
5. Build RV808 → elegant 23-chip computer
6. PCB + Video + Sound → full single-board computer
```
