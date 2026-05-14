# RV8 Project — Task Tracker

**Last updated**: 2026-05-15 06:31

---

## ✅ Completed

- [x] RV802 design (25 chips, RISC-V, Flash microcode)
- [x] RV802 Verilog model (19/21 pass)
- [x] RV802 WiringGuide (verified buildable, both formats)
- [x] RV8-G design (27 chips, pure gates)
- [x] RV8-G Verilog model (34/34 pass)
- [x] RV8-G control trace (proven fits in gates)
- [x] Programmer board (ESP32 + TXB0108, firmware, PC tools)
- [x] Project restructure (Old_Design archive, focus on RV802 + RV8-G)

---

## ⬜ TODO — RV802 (primary)

| Task | Priority | Notes |
|------|:--------:|-------|
| Fix Verilog (BRA + r3 test) | HIGH | 2 minor issues |
| Microcode table generator (Python) | HIGH | Generates Flash .bin from ISA definition |
| Assembler (rv802asm.py) | HIGH | Encode 35 instructions |
| Build guide (labs, Thai+English) | MEDIUM | Step-by-step breadboard |
| Breadboard build | MEDIUM | Physical verification |
| BASIC interpreter (ROM) | MEDIUM | The "killer app" |

## ⬜ TODO — RV8-G (secondary)

| Task | Priority | Notes |
|------|:--------:|-------|
| WiringGuide rewrite (honest) | MEDIUM | Current one has issues |
| Assembler (rv8g_asm.py) | LOW | 30 instructions |
| Build guide | LOW | After RV802 is proven |

## ⬜ TODO — System

| Task | Priority | Notes |
|------|:--------:|-------|
| Build Programmer board physically | HIGH | ESP32 + TXB0108 + 40-pin |
| Video circuit design (Apple II style) | LOW | Counters + shift reg, shared RAM |
| Sound (SN76489) | LOW | Expansion slot |
| Keyboard (PS/2) | LOW | Expansion slot |
| BASIC interpreter | MEDIUM | ~8-12KB ROM |

---

## Priority Order

```
1. Fix RV802 Verilog (2 tests)
2. Build Programmer board (physical)
3. Write rv802asm.py assembler
4. Write microcode generator
5. Build RV802 on breadboard
6. Write BASIC interpreter
7. Video + sound + keyboard (full computer)
```
