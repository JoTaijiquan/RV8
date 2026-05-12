# RV8 Project History

## 2026-05-10 (Day 1) — Design

| Time | Event |
|------|-------|
| 20:58 | Project started. Requirements + ISA design |
| — | Decided: 8-bit (not 32-bit RV32I) — 18× fewer gates |
| — | Decided: fixed 2-byte instructions (not variable 1-3) |
| — | Decided: accumulator model (not register-to-register) |
| — | Decided: 5 registers → later expanded to 7 |
| — | Decided: hardwired control (not microcode ROM) |
| — | Decided: 8-bit SP on fixed page $30 |
| — | Decided: auto-increment pointer (ptr+) |
| — | Decided: NMI + IRQ (2 interrupt lines) |
| — | Decided: 5V USB power, 3.5 MHz clock |
| — | Rejected: PC-relative, hardware multiply, DMA, FPU |

## 2026-05-11 (Day 2) — Implementation

| Time | Event |
|------|-------|
| 01:25 | ISA v5: direct-encode, fetch overlap, const-gen, conditional skip. 20 chips, 68 instructions |
| 01:26 | RV801 ultra-minimal variant spec (8 chips) |
| 01:51 | Phase 1-2 complete. RV8 (20 chips) + RV801-A/B |
| 02:03 | Phase 3: Architecture — datapath, FSM, timing, chip mapping |
| 02:17 | Architecture verified. Fixed 3 critical + 4 high issues → 21 chips |
| 02:26 | 2nd-pass: fix ptr+, register separation, skip+interrupt → 23 chips |
| 02:31 | Phase 4: Verilog implementation — ALU, regfile, PC, pointer, control |
| 02:35 | Phase 5: Testbench — 6 tests, boot sequence needs work |
| 02:46 | **9 tests pass.** LI, ADDI, SUBI, BNE loop, SB/LB, ptr+, CLC/SEC |
| 02:57 | **30 tests pass.** ALU reg, ALU imm, shift, pointer, branch, store/load |
| 03:01 | **37 tests pass.** +SKIP, PUSH/POP, JMP, JAL/RET, zero-page |
| 03:04 | **43 tests pass.** +ROR, ADC, MOV, sp+imm, NOP, IRQ wake |
| 03:09 | **62 tests pass.** Full ISA coverage |
| 03:18 | **66 tests pass.** +constant generator, NMI |
| 03:22 | **69 tests pass.** +TRAP, RTI. Complete ISA verified ✓ |
| 03:24 | Synthesizable structural version (rv8_synth.v) |
| 03:26 | Repo restructure: rtl/ tb/ doc/ |
| 03:31 | Cross-assembler (rv8asm.py) — Python, Intel HEX, all opcodes |
| 03:47 | Circuit diagram — all 27 chips, pin connections |
| 04:05 | Fibonacci demo runs correctly |
| 23:54 | Add rv8_cpu.v modular implementation |
| 23:58 | Move RV801 docs to rv801/ |

## 2026-05-12 (Day 3) — Hardware + Labs

| Time | Event |
|------|-------|
| 00:03 | Fix chip count: 74HC157 ×3 = 27 total |
| 00:12 | Pico in-circuit ROM programmer |
| 00:26 | UART + bootloader |
| 00:38 | Separate CPU board from trainer board |
| 01:06 | Trainer board: ESP32 NodeMCU + 74HCT245 |
| 01:14 | 40-pin expansion connector |
| 01:23 | Rebrand: "Accumulator-based, RISC-inspired" |
| 02:02 | README rewrite |
| 02:12 | Build guide (8 steps, module-by-module) |
| 02:18 | Lab sheets (8 labs with test procedures) |
| 02:24 | Simulation testbenches (Icarus Verilog, all pass) |
| 02:35 | Sim README for beginners |
| 05:51 | KiCad CPU board schematic (27 chips, 390 nets) |
| 12:10 | All .v files → standard Verilog-2001/2005 |
| 12:11 | Yosys circuit diagrams (SVG) |
| 17:43 | KiCad verified: 18/18 design checks pass |
| 17:50 | KiCad optimized: labels at pin endpoints, 364/364 connected |
| 17:54 | Repo reorganized, changelog + history created |
| 18:00 | Docs 00-02 rewritten as current, numbered 00-08 |
| 18:05 | Fixed: trainer 40-pin, rv801 chip count, README structure |
| 18:20 | Yosys PNG circuit diagrams (6 modules) |
| 18:21 | netlistsvg diagrams (5 modules, clean logic view) |
| 18:26 | KiCad v2: chip wiring with wire stubs + labels |
| 18:28 | ASCII schematic + draw.io block diagram |
| 18:37 | KiCad v3: human-centric data-flow layout, Verilog signal names |
