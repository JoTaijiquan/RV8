# RV8 Project — Task Tracker

**Last updated**: 2026-05-17 00:17
**Focus**: RV8-GR — READY FOR PHYSICAL BUILD

---

## ✅ Completed (RV8-GR)

- [x] Design (21 chips, traced, verified)
- [x] ISA (21 instructions, control byte encoding)
- [x] Verilog model (11/11 pass)
- [x] Assembly integration test (full pipeline pass)
- [x] Assembler (rv8gr_asm.py)
- [x] WiringGuide (bus-centric, no conflicts)
- [x] Instruction trace (verified every signal)
- [x] Understand by Module (4 modules)
- [x] ISA reference (with control byte table)
- [x] Bank switch design (Trainer board, future)
- [x] VCD waveform support

---

## ⬜ TODO — Physical Build

| # | Task | Priority |
|:-:|------|:--------:|
| 1 | Order parts (~฿575) | **NOW** |
| 2 | Build Programmer board (ESP32 + TXB0108) | **NOW** |
| 3 | Build RV8-GR on breadboard | HIGH |
| 4 | Flash test program to ROM | HIGH |
| 5 | First LED blink / Fibonacci | HIGH |
| 6 | Debug (compare scope with VCD waveform) | MEDIUM |

## ⬜ TODO — After Hardware Works

| Task | Priority |
|------|:--------:|
| BASIC interpreter (in ROM) | MEDIUM |
| Trainer board (LEDs, step, SD, bank switch) | MEDIUM |
| Video circuit (Apple II style) | LOW |
| Thai documentation (labs) | LOW |

---

## Parts List (RV8-GR)

| Part | Qty | Source |
|------|:---:|--------|
| 74HC574 (DIP-20) | 3 | บ้านหม้อ |
| 74HC283 (DIP-16) | 2 | Mouser/Shopee |
| 74HC86 (DIP-14) | 2 | บ้านหม้อ |
| 74HC157 (DIP-16) | 4 | บ้านหม้อ |
| 74HC161 (DIP-16) | 5 | บ้านหม้อ |
| 74HC541 (DIP-20) | 2 | Shopee |
| 74HC245 (DIP-20) | 1 | บ้านหม้อ |
| 74HC74 (DIP-14) | 1 | บ้านหม้อ |
| 74HC32 (DIP-14) | 1 | บ้านหม้อ |
| SST39SF010A (PDIP-32) | 1 | Mouser |
| 62256 (DIP-28) | 1 | Shopee |
| Crystal 3.5MHz | 1 | บ้านหม้อ |
| Breadboard ×2 | 2 | Shopee |
| LED + 330Ω ×10 | 10 | บ้านหม้อ |
| **Total** | | **~฿575** |
