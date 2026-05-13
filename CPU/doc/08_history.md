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
| 19:20 | Updated changelog + history with v1.3 |
| 19:20 | Added dataflow diagram + TTL schematic PDF |
| 20:32 | Merged trainer into programmer/ |
| 20:40 | Added full system spec: Trainer, PC, bus slot, BASIC ROM |
| 20:52 | Reorganized: CPU/, Trainer/, Computer/, Rom/ — each with own requirements |
| 20:57 | Bus slot: 30-pin → 40-pin (pins 31-38 reserved N/A) |
| 21:01 | Universal bus slot: 255 devices, device detection, replaceable ROM |
| 21:06 | Renamed rom/ → Rom/ |
| 21:20 | Renamed to RV8-Bus: lives on Trainer/Computer, CPU plugs in as card |
| 21:39 | Computer: analog joystick (X/Y + 4 buttons + 4-bit LED output) |
| 21:48 | Generated CPU netlists: Verilog, JSON, EDIF, BLIF, SPICE |

## 2026-05-13 (Day 4) — CPU Bug Fixes + Lab Expansion

| Time | Event |
|------|-------|
| 00:08 | **rv8_cpu.v fully fixed: 69/69 tests pass** |
| — | Root cause: instruction decode used opcode[7:5] grouping that didn't match actual encoding |
| — | Root cause: ALU only had 3-bit op (8 ops), needed 4-bit (14 ops) for all shift/unary |
| — | Root cause: Verilog `~carry_in` width promotion bug (9-bit NOT instead of 1-bit) |
| — | Root cause: operand timing — S1 execute used stale ir_operand instead of data_in |
| — | Root cause: reg write data mux picked data_in during fetch (mem_rd=1 in S0/S1) |
| — | Root cause: wr_sel hardcoded to a0, no routing to other registers |
| — | Root cause: branch offset didn't account for missed PC increment |
| — | Root cause: PUSH used post-decrement address instead of pre-decrement |
| — | Root cause: multi-cycle ops (RTI/RET) lost opcode when ir_load0 reused ir_opcode |
| — | Fix: added instr_type registered flag in control unit for S2/S3/S4 dispatch |
| — | Fix: added vector_addr register for reset/NMI/IRQ/TRAP vector fetch |
| — | Fix: implemented full RTI (pop flags → pop PCL → pop PCH → load PC) |
| 00:48 | Rewrote Lab 1 Thai version — concise lab-sheet style for middle school |
| 00:53 | Rewrote Lab 2 Thai version — same style |
| 00:57 | Rewrote Lab 3 Thai version — same style + LED pattern guide |
| 01:01 | Added Thai versions to Labs 4–8 in lab-sheet style |
| 01:10 | Created Lab 9: Full ALU (AND/OR/XOR/shift/rotate/INC/DEC/NOT/SWAP) |
| 01:10 | Created Lab 10: Stack + Subroutines (PUSH/POP/JAL/RET) |
| 01:10 | Created Lab 11: Addressing Modes (all memory modes + MOV + const gen) |
| 01:10 | Created Lab 12: Interrupts + Skip (NMI/IRQ/TRAP/RTI — completes 68 ISA) |
| 01:22 | Rewrote 06_build_guide.md for 12-lab structure |
| 01:26 | Added Thai build guide with pin-by-pin wiring tables |
| 01:31 | Added full TTL names to chip list (U1–U25) |

## 2026-05-13 (Day 5) — Board Redesign

| Time | Event |
|------|-------|
| 02:00 | Pushed v1.6 to GitHub (69/69 tests, 12 labs, Thai versions) |
| 09:52 | Board architecture redesign discussion |
| — | Decision: move clock mux (U25) off CPU board → Trainer board |
| — | Decision: CPU board = 26 chips (23 CPU + U24 addr decode + ROM + RAM) |
| — | Decision: crystal oscillator on CPU board, always free-running |
| — | Decision: single-step is Trainer board feature (with visual feedback) |
| — | Decision: 4-board system: CPU, Programmer, Trainer, PC Board |
| — | Programmer board: ESP32, PROG/RUN switch, ROM flash + UART terminal |
| — | Trainer board: clock override, RUN/STEP, LEDs, 7-seg, SD, mini keyboard, PS/2 |
| — | PC Board: expanded I/O, SD, UART, GPIO, banked RAM |
| — | U24 confirmed as 74HC138 (address decode), not 74HC74 |
| 10:47 | Updated all docs to reflect 26-chip, 4-board design |
