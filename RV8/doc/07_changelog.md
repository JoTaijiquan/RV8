# RV8 Changelog

## v1.7 — 2026-05-13 11:15
- Board redesign: CPU board reduced from 27 to 26 chips
- Removed U25 (clock mux) from CPU board — single-step moved to Trainer board
- CPU board now always free-running (crystal oscillator, no switches)
- U24 confirmed as 74HC138 (address decode for ROM/RAM/I/O)
- Defined 4-board system: CPU, Programmer, Trainer, PC Board
- Programmer board: ESP32, PROG/RUN switch, ROM flash + UART terminal
- Trainer board: clock override, step button, 6× 7-seg, 23 LEDs, SD, keyboard, PS/2
- SYNC pin (pin 37) on 40-pin bus — Trainer uses for instruction-level step
- Programmer board works with all CPU variants (RV8, RV801, RV808)
- Fixed 03_architecture.md: 2× 74HC138, gate count ~720
- Rewrote Lab 1 (crystal oscillator only, no 74HC157)
- Updated all docs: README, requirements, circuit, build guide, labs, history

## v1.6 — 2026-05-13 01:36
- Expanded from 8 labs to 12 labs — full 68-instruction ISA coverage
- Lab 9: Full ALU (AND/OR/XOR/shift/rotate/INC/DEC/NOT/SWAP)
- Lab 10: Stack + Subroutines (PUSH/POP/JAL/RET)
- Lab 11: Addressing Modes (zero-page, sp+imm, pg:imm, MOV, const gen, LI all regs)
- Lab 12: Interrupts + Skip (NMI/IRQ/TRAP/RTI/SKIP/EI/DI/HLT/NOP)
- Rewrote Thai versions for all 12 labs in concise lab-sheet style (middle school friendly)
- Updated 06_build_guide.md: 12-lab structure with pin-by-pin wiring tables (Thai)
- Added full chip list with U-numbers and TTL names (U1–U25 + ROM + RAM)
- Instruction coverage table: Lab 8→15, Lab 9→38, Lab 10→42, Lab 11→58, Lab 12→68

## v1.5 — 2026-05-13 00:08
- Fixed rv8_cpu.v: all 69 testbench assertions pass (was broken, 0 passing)
- Rewrote instruction decode: explicit opcode range matching (not broken [7:5] grouping)
- Expanded ALU to 4-bit op: added ROL, ROR, INC, DEC, NOT, SWAP natively
- Fixed Verilog ~carry_in width promotion bug in SUB/SBC
- Added operand_mux: correct operand source per pipeline stage (data_in in S1, ir_operand in S2+)
- Fixed register write data path: memory reads only in S2, not during fetch
- Added wr_sel, alu_b_sel control signals for proper register/ALU routing
- Added sp_inc/sp_dec to regfile, ptr_add to pointer module
- Fixed branch offset (+1 for missed PC increment)
- Fixed PUSH pre-decrement addressing (addr_src=7)
- Implemented vector fetch (S5/S6) for reset, NMI, IRQ, TRAP
- Implemented RTI: pop flags/PCL/PCH with flags restore
- Added instr_type registered flag for multi-cycle instruction tracking
- Fixed skip condition mapping to match actual opcode encoding
- Fixed constant generator select bits (operand[4:3] not [3:2])

## v1.4 — 2026-05-12 21:48
- RV8-Bus: 40-pin universal backplane on Trainer/Computer boards
- CPU board plugs into RV8-Bus as a card (not the host)
- 255 devices, device detection (ID register), replaceable ROM
- Pin 31 = CART_DETECT for hot-swap ROM cartridges
- Project reorganized: CPU/, Trainer/, Computer/, Rom/ with own requirements
- Full system spec: Trainer (LCD, keypad, sound), PC (video, keyboard, joysticks)
- Computer: analog joystick ports (X/Y + 4 buttons + 4-bit LED output per port)
- CPU netlists generated: Verilog, JSON, EDIF, BLIF, SPICE
- Rom/ project: BASIC interpreter + monitor + assembler requirements

## v1.3 — 2026-05-12 19:20
- KiCad schematic v3: human-centric data-flow layout matching rv8_cpu.v
- Signal names in schematic match Verilog (pc_inc, alu_result, ptr_out)
- Layout follows pipeline: Fetch → Decode → Execute → Memory → Control
- Added PNG diagrams (Yosys + Graphviz)
- Added netlistsvg diagrams (clean digital logic, 5 modules)
- Added ASCII chip wiring diagram + draw.io block diagram
- Docs 00-02 rewritten as current (removed historical warnings)
- All docs renumbered 00-08 for sequential reading
- Fixed: trainer 40-pin (was 34), rv801 chip count, README structure

## v1.2 — 2026-05-12 17:50
- KiCad schematic optimized: labels at pin endpoints, 364/364 nets connected
- Yosys circuit diagrams (SVG) for all 5 modules
- All .v files converted to standard Verilog-2001/2005
- KiCad verified: 18/18 design checks pass
- Repo reorganized: clean doc/ structure, historical docs to reference/

## v1.1 — 2026-05-12 02:35
- Lab sheets: 8 labs with simulation-first workflow
- Simulation testbenches (Icarus Verilog, labs 1-8 all pass)
- Build guide: 8 steps, module-by-module with tests
- KiCad CPU board schematic (27 chips, 390 nets)
- SYNC signal added to circuit doc and 40-pin connector
- Beginner-friendly sim README

## v1.0 — 2026-05-12 01:14
- CPU board finalized: 23 CPU + 4 system = 27 chips
- 40-pin DIP expansion connector
- Trainer board: ESP32 NodeMCU + 74HCT245 level shifting
- Pico in-circuit ROM programmer + bootloader
- Branding: "Minimal 8-bit CPU — Accumulator-based, RISC-inspired"

## v0.9 — 2026-05-11 23:54
- Modular rv8_cpu.v (top-level with sub-modules)
- RV801 docs separated to rv801/

## v0.8 — 2026-05-11 04:05
- Fibonacci demo runs correctly (0,1,1,2,3,5,8,13,21,34,55)
- Circuit diagram: all 27 chips with pin connections
- Cross-assembler: Python, Intel HEX output, all 68 opcodes
- Synthesizable structural version (rv8_synth.v)

## v0.5 — 2026-05-11 03:22
- **69 tests ALL PASS** — complete ISA verified
- 68 instructions: ALU, load/store, branch, skip, shift, pointer, system
- TRAP, RTI, NMI, IRQ, constant generator all working
- Architecture: 17 states, 23 CPU chips, ~730 gates

## v0.3 — 2026-05-11 02:46
- First working CPU: 9 tests pass
- Verilog implementation compiles and simulates
- Basic instructions: LI, ADDI, SUBI, BNE, SB/LB

## v0.1 — 2026-05-10 20:58
- Initial requirements and ISA design
- Key decisions: 8-bit, fixed 2-byte, accumulator, hardwired control
- Direct-encoded opcodes, no microcode
- Rejected: PC-relative, hardware multiply, DMA, FPU, variable-length
- Target: 20 CPU chips (later revised to 23, then 27 total)
