# RV8 Project — Task Tracker

**Last updated**: 2026-05-16 19:30

---

## ✅ Completed

- [x] RV8 design (27 chips, RISC-V reg-reg, Flash microcode)
- [x] RV8 Verilog model (19/21 pass)
- [x] RV8 WiringGuide (verified, address conflict fixed)
- [x] RV8 ISA reference (RISC-V aligned, 35 instructions)
- [x] RV8 instruction trace (found step counter + 2nd Flash needed)
- [x] RV8 Understand_by_Module.md (student guide)
- [x] RV8-W design (24 chips, accumulator, no microcode, 5 MIPS)
- [x] RV8-W ISA (RISC-V naming, 25 instructions)
- [x] RV8-S design (20 chips, serial ALU, same ISA as RV8)
- [x] RV8-S WiringGuide (20 chips, issues noted)
- [x] RV8-G archived (broken hardware, 32 chips honest)
- [x] Programmer board (ESP32 + TXB0108, firmware, PC tools)
- [x] RV8-Bus defined (40-pin, compatible with all variants)
- [x] Reference summary (Gigatron, SAP-1, Nand2Tetris)

---

## 🔧 Decision Needed

**Which variant to build first?**

| | RV8-S | RV8-W | RV8 |
|--|:---:|:---:|:---:|
| Chips | 20 | 24 | 27 |
| Speed | 1 MIPS | 5 MIPS | 2.17 MIPS |
| Complexity | Low | Medium | High |
| Games | ⚠️ simple | ✅ | ✅ |

---

## ⬜ TODO — Whichever variant chosen

| Task | Priority | Notes |
|------|:--------:|-------|
| Complete instruction trace (verify ALL signals) | HIGH | Prevent another redesign |
| Fix Verilog to match hardware | HIGH | Current model is behavioral |
| Microcode generator (if RV8/RV8-S) | HIGH | Flash .bin content |
| Assembler (Python) | HIGH | Write programs |
| Build Programmer board physically | HIGH | Need it to flash anything |
| First program (Fibonacci) | MEDIUM | Proof of life |
| Build guide (labs, Thai+English) | MEDIUM | For students |
| Breadboard build | MEDIUM | Physical verification |

## ⬜ TODO — After CPU works

| Task | Priority | Notes |
|------|:--------:|-------|
| BASIC interpreter | MEDIUM | ~8-12KB ROM |
| Video circuit (Apple II style) | LOW | Shared RAM, counters + shift reg |
| Sound (SN76489) | LOW | Expansion slot |
| Keyboard (PS/2) | LOW | Expansion slot |
| Trainer board | LOW | Single-step, LEDs, 7-seg |

---

## Priority Order

```
1. DECIDE which variant to build
2. Complete instruction trace for chosen variant
3. Build Programmer board (physical)
4. Write assembler
5. Write microcode generator (if needed)
6. Build CPU on breadboard
7. First program running!
8. BASIC interpreter
9. Full computer (video + sound + keyboard)
```
