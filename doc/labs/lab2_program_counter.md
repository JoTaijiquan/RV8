# Lab 2: Program Counter

## Objective
Build a 16-bit program counter that increments on each clock cycle and resets to $0000.

## Components
| Part | Qty | Description |
|------|:---:|-------------|
| 74HC161 | 4 | 4-bit synchronous counter |
| LED + 330Ω | 8 | Address bus low byte display |

## Schematic

```
U1 (PC bits 3:0)    U2 (PC bits 7:4)    U3 (PC bits 11:8)   U4 (PC bits 15:12)
┌──────────┐        ┌──────────┐        ┌──────────┐        ┌──────────┐
│CLK ← CLK │        │CLK ← CLK │        │CLK ← CLK │        │CLK ← CLK │
│/CLR← /RST│        │/CLR← /RST│        │/CLR← /RST│        │/CLR← /RST│
│/LD ← VCC │        │/LD ← VCC │        │/LD ← VCC │        │/LD ← VCC │
│ENT ← VCC │        │ENT ← U1.TC│       │ENT ← U2.TC│       │ENT ← U3.TC│
│ENP ← VCC │        │ENP ← VCC │        │ENP ← VCC │        │ENP ← VCC │
│QA → A0   │        │QA → A4   │        │QA → A8   │        │QA → A12  │
│QB → A1   │        │QB → A5   │        │QB → A9   │        │QB → A13  │
│QC → A2   │        │QC → A6   │        │QC → A10  │        │QC → A14  │
│QD → A3   │        │QD → A7   │        │QD → A11  │        │QD → A15  │
│TC → U2.ENT│       │TC → U3.ENT│       │TC → U4.ENT│       │TC → (nc) │
└──────────┘        └──────────┘        └──────────┘        └──────────┘
```

## Simulate First

```bash
cd sim/
iverilog -o lab2 lab2_pc_tb.v && vvp lab2
gtkwave lab2.vcd
```

**What to check in GTKWave:**
- `pc[15:0]`: increments by 1 each clock
- Carry propagation: pc rolls from $000F → $0010, $00FF → $0100
- Reset: pc snaps to $0000

---

## Procedure

1. Place U1–U4 on breadboard. Connect VCC (pin 16) and GND (pin 8) on each.
2. Connect CLK (from Lab 1) to all four CLK inputs (pin 2).
3. Connect /RST (from Lab 1) to all four /CLR inputs (pin 1).
4. Tie /LD (pin 9) HIGH on all four chips (no parallel load yet).
5. U1: tie ENT (pin 10) and ENP (pin 7) to VCC.
6. U2: connect ENT (pin 10) to U1 TC (pin 15). Tie ENP to VCC.
7. U3: connect ENT to U2 TC. Tie ENP to VCC.
8. U4: connect ENT to U3 TC. Tie ENP to VCC.
9. Connect LEDs to U1 and U2 outputs (A0–A7) for visual feedback.

## Test Procedure

| Test | Action | Expected Result |
|:----:|--------|-----------------|
| 1 | Press RESET | All LEDs off (PC = $0000) |
| 2 | Single-step 1× | A0 LED on (PC = $0001) |
| 3 | Single-step 15× total | A0-A3 all on (PC = $000F) |
| 4 | Single-step 1 more | A0-A3 off, A4 on (PC = $0010) — carry! |
| 5 | Single-step to $00FF | All 8 LEDs on |
| 6 | Single-step 1 more | All off (PC = $0100) — verify U3 increments |
| 7 | Switch to RUN mode | LEDs blur (counting too fast to see) |
| 8 | Press RESET during RUN | All LEDs off immediately |

## Checkoff

- [ ] PC counts 0000 → 0001 → 0002 ... sequentially
- [ ] Carry propagates: U1→U2→U3→U4
- [ ] /RST resets all counters to 0000
- [ ] No glitches on carry transitions (check with scope on U2.QA)

## Notes
- Later we'll connect /LD to load branch targets and ENP/ENT to a control signal for halting.
- For now, the PC just free-runs. This is enough to test ROM fetching in Lab 3.
