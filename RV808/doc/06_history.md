# RV808 Project History

## 2026-05-13 — Design Day

| Time | Event |
|------|-------|
| 17:37 | Idea: RV808 variant with 8-bit multiplexed address bus |
| 17:40 | Explored Option A (shared AD) vs Option B (separate A+D) |
| 17:44 | Insight: ISA already multiplexes addresses (LI ph, LI pl) — hardware should match |
| 17:51 | Explored approaches: multiplexed bus, page register, Harvard, pure 256-byte |
| 17:54 | Selected Harvard approach: internal ROM fetch + paged data bus |
| 17:59 | Confirmed: BASIC + games feasible at 10 MHz (~800 lines/sec) |
| 18:01 | Decided: same ISA philosophy, ~90% compatible with RV8 |
| 18:07 | Deep design: auto-latch, all-574 vs hybrid, ALU bottleneck analysis |
| 18:11 | Created design notes (RV808/doc/00_design_notes.md) |
| 18:15 | Honest assessment: RV808 better for PCB product, RV8 better for teaching |
| 18:18 | Decided: keep both — RV8 for education, RV808 for production |
| 18:22 | Explored: can we run code from RAM? Yes — overlay at $4000-$7FFF, 0 extra chips |
| 18:28 | Confirmed: ROM always at $0000-$3FFF for interrupts/drivers, RAM overlay above |
| 18:31 | Deep architecture doc: ISA encoding, state machine, datapath, BOM |
| 18:38 | Compared RV8 vs RV808: 26 vs 23 chips, ~720 vs ~590 gates |
| 18:40 | Decided: RAM on CPU board (self-contained), external bus = I/O only |
| 18:43 | Confirmed: code from RAM works, ROM banking works, 0 extra chips |
| 18:46 | Killed Lite/Full split — just "RV808: 23 chips" |
| 18:50 | Defined expansion slots via page mapping ($80-$FF on external bus) |
| 18:58 | Defined 40-pin bus (future-proof, 8 pins reserved) |
| 19:00 | Philosophy: "RV8 teaches how a CPU works. RV808 teaches how to design one." |
| 19:04 | Saved all design notes and pushed to GitHub |
| 19:23 | Discussed RAM budget: 16KB data-only + 16KB code+data, display fits in 1KB |
| 19:28 | Started Verilog implementation |
| 19:46 | Verilog model complete: rv808_cpu.v |
| 19:50 | Testbench: 33/33 pass (basic instructions) |
| 19:55 | Expanded testbench: 40/40 pass (JAL/RET, TRAP/RTI, NMI, IRQ, loops) |
| 20:03 | Circuit diagram complete (pin-level, 23 chips) |
| 20:09 | Build guide (8 labs), changelog, history, summary |
| 20:15 | Rewrote build guide: full Thai version with pin tables matching RV8 standard |
| 20:15 | Added pinout diagrams, chip wiring tables, power table, student tips |
| 21:11 | Updated summary, changelog, history |

### Key decisions made:

1. Harvard fetch (ROM internal) — no bus penalty for instruction fetch
2. Page:offset data access — matches ISA elegance, 1-cycle access
3. 4 registers only (a0, t0, sp, pg) — eliminated pl/ph pointer
4. RAM on CPU board — self-contained, external bus for I/O only
5. Code overlay ($4000-$7FFF) — run from RAM, 0 extra chips
6. ROM banking — 64KB+ via spare flip-flop bits, 0 extra chips
7. 40-pin bus with pre-decoded slots — plug-and-play expansion
8. Same connector as RV8 — physical compatibility
