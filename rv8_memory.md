# RV8 Project — Session Memory

**Last updated**: 2026-05-15 06:31

---

## Active Designs

| Variant | Chips | Architecture | Control | MIPS@10MHz | Status |
|---------|:-----:|-------------|---------|:----------:|:------:|
| **RV802** | 25+ROM+RAM=27 | Register-register (RISC-V) | Flash microcode | 3.0 | ✅ Verilog + WiringGuide |
| **RV8-G** | 27+ROM+RAM=29 | Accumulator | Pure gates | 2.5 | ✅ Verilog (34/34) |

## RV802 (primary build target)

- 8 general-purpose registers (r0=zero, r7=sp)
- 35 instructions, 4 classes (ALU reg, immediate, memory, control)
- Single internal bus, Flash microcode sequences all transfers
- SST39SF010A (70ns, PDIP-32) for control
- Verilog: 19/21 pass (BRA offset + r3 minor fix pending)
- WiringGuide: verified buildable, no bus conflicts, 10MHz timing OK

## RV8-G (no-programmer alternative)

- 5 registers (a0, t0, sp, pl, ph)
- 30 instructions, opcode bits = control wires
- Pure 74HC gates, no EEPROM/Flash for control
- Verilog: 34/34 pass
- WiringGuide: needs rewrite (subagent found issues in old version)

## Programmer Board

- ESP32 NodeMCU + 3× TXB0108 level shifters (~$10)
- PROG mode: flash ROM via 40-pin bus
- RUN mode: UART terminal bridge
- Works with both RV802 and RV8-G

## Folder Structure

```
/home/jo/kiro/RV8/
├── RV802/          ← 25-chip RISC-V style (primary)
│   ├── rv802_cpu.v
│   ├── tb/tb_rv802_cpu.v
│   ├── doc/00_design.md
│   ├── doc/WiringGuide.md (table format)
│   ├── doc/WiringGuide_json.md (JSON format)
│   └── README.md
├── RV8G/           ← 27-chip pure gates
│   ├── rv8g_cpu.v
│   ├── tb/tb_rv8g_cpu.v
│   ├── doc/00_design.md
│   ├── doc/01_control_trace.md
│   ├── doc/WiringGuide.md
│   └── README (in project README)
├── RV808G/         ← 20-chip Harvard (design study only)
├── Programmer/     ← ESP32 programmer board
├── Old_Design/     ← Archived (RV8, RV801, RV808)
├── .kiro/agents/   ← 5 agents (lead, rtl, docs, hw, sw)
├── README.md
├── CHANGELOG.md
├── HISTORY.md
├── rv8_memory.md   ← this file
└── rv8_task.md
```

## Key Decisions Made

1. Accept EEPROM/Flash for control (RV802) — enables simple hardware + rich ISA
2. Pure gates (RV8-G) costs same chips as Flash version — value is "no programmer"
3. Single-bus architecture (RV802) eliminates mux chips — microcode handles sequencing
4. RISC-V style registers eliminate complex addressing modes
5. Original RV8 (68 instr, accumulator) was unbuildable as documented → archived
6. SST39SF010A (70ns, PDIP-32) available from Mouser, ships to Thailand

## Agents

| Agent | Model | Role |
|-------|-------|------|
| lead | (default) | System architect |
| rtl | qwen3-coder-next | Verilog RTL |
| docs | glm-5 | Documentation |
| hw | glm-5 | Hardware |
| sw | qwen3-coder-next | Software |
