# Lab 3: ROM and Instruction Fetch

## Objective
Connect program ROM to the PC so the CPU fetches bytes sequentially from memory.

## Components
| Part | Qty | Description |
|------|:---:|-------------|
| AT28C256 | 1 | 32KB EEPROM (program ROM) |
| 74HC138 | 1 | 3-to-8 address decoder |
| 74HC245 | 1 | Octal bus transceiver (data bus buffer) |
| LED + 330Ω | 8 | Data bus display |

## Pre-Lab
Program the AT28C256 with this test pattern (using TL866 or Pico programmer):
```
Address  Data    (Purpose)
$C000    $AA     (10101010 — alternating bits)
$C001    $55     (01010101 — complement)
$C002    $01     (ascending)
$C003    $02
$C004    $04
$C005    $08
$C006    $10
$C007    $20
$C008    $40
$C009    $80
$C00A    $FF     (all ones)
$C00B    $00     (all zeros)
```

## Schematic

```
PC A[14:0] ──────────────────────► AT28C256 A[14:0]
PC A[15] ────────────────────────► 74HC138 input A (for decode)
PC A[14] ────────────────────────► 74HC138 input B
PC A[13] ────────────────────────► 74HC138 input C

74HC138:
  G1 = VCC, /G2A = GND, /G2B = GND
  /Y6 + /Y7 → ROM /CE (active when A[15:13] = 110 or 111)

AT28C256:
  A[14:0] ← PC
  /CE ← decode output
  /OE ← GND (always reading for now)
  D[7:0] → 74HC245 A-side

74HC245:
  A[7:0] ← ROM D[7:0]
  B[7:0] → data bus → LEDs
  DIR = VCC (A→B, ROM to bus)
  /OE = GND (always enabled for now)
```

## Simulate First

```bash
cd sim/
iverilog -o lab3 lab3_rom_tb.v && vvp lab3
gtkwave lab3.vcd
```

**What to check in GTKWave:**
- `pc`: counts up
- `data_bus`: shows ROM contents matching the test pattern ($AA, $55, $01...)
- Each clock cycle fetches the next byte

---

## Procedure

1. Insert AT28C256 (pre-programmed). Connect VCC (pin 28) and GND (pin 14).
2. Wire PC outputs A0–A14 to ROM address pins A0–A14.
3. Insert 74HC138. Wire A15→A, A14→B, A13→C. Tie G1=VCC, /G2A=/G2B=GND.
4. Connect 74HC138 /Y6 and /Y7 (OR together with a wire-AND or gate) to ROM /CE.
   - Simple: just connect /Y7 to ROM /CE (covers $E000-$FFFF).
   - Or tie ROM /CE to GND for now (always selected) since PC starts at $0000 but ROM responds to all addresses when /CE=LOW.
5. Tie ROM /OE to GND (always outputting).
6. Insert 74HC245. Wire ROM D[7:0] to A-side. B-side is the data bus.
7. Tie 74HC245 DIR=VCC (A→B), /OE=GND.
8. Connect 8 LEDs to data bus (B-side of 245).

## Test Procedure

| Test | Action | Expected Result |
|:----:|--------|-----------------|
| 1 | Press RESET, then single-step 1× | LEDs show $AA (10101010) |
| 2 | Step again | LEDs show $55 (01010101) |
| 3 | Step again | LEDs show $01 (00000001) |
| 4 | Continue stepping | Pattern: $02, $04, $08, $10, $20, $40, $80 |
| 5 | Step to byte 10 | LEDs show $FF (all on) |
| 6 | Step to byte 11 | LEDs show $00 (all off) |
| 7 | Press RESET | Back to $AA on next step |
| 8 | RUN mode | LEDs blur (fetching at 3.5 MHz) |

## Checkoff

- [ ] Data bus shows correct ROM contents in sequence
- [ ] Reset returns to first byte
- [ ] All 8 data bits correct (verify $AA and $55 carefully)
- [ ] No bus contention (245 drives cleanly)

## Notes
- The PC starts at $0000 but ROM is mapped at $C000+. For this test, either:
  - Program ROM so address $0000 has $AA (ignore mapping), OR
  - Pre-load PC to $C000 by tying some /LD inputs (advanced), OR
  - Just tie ROM /CE low so it responds to all addresses (simplest for testing)
- In the final build, the PC will start at the reset vector ($FFFC) which points to $C000.
- The 74HC245 will later be controlled by /RD signal. For now it's always on.
