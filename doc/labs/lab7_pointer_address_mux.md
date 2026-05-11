# Lab 7: Pointer Register and Address Mux

## Objective
Build the 16-bit pointer register and address multiplexer to access RAM.

## Components
| Part | Qty | Description |
|------|:---:|-------------|
| 74HC161 | 2 | 4-bit counter (pointer low/high with auto-increment) |
| 74HC157 | 2 | Quad 2:1 mux (address source select) |
| 62256 | 1 | 32KB static RAM |
| LED + 330Ω | 8 | Data bus (reuse from earlier) |

## Concept

The address bus can be driven by different sources:
```
addr_sel=0: PC      → fetch instructions from ROM
addr_sel=1: pointer → read/write data in RAM
```

The pointer register {ph, pl} holds a 16-bit address and can auto-increment.

## Schematic

```
U11 (pl, pointer low):
  D[3:0] ← data bus [3:0] (for loading)
  /LD ← pl_load
  ENT ← ptr_inc
  ENP ← ptr_inc
  CLK ← CLK
  Q[3:0] → mux input B (low nibble)
  TC → U12.ENT (carry to high)

U12 (ph, pointer high):
  D[3:0] ← data bus [3:0]
  /LD ← ph_load
  ENT ← U11.TC
  ENP ← ptr_inc
  CLK ← CLK
  Q[3:0] → mux input B (high nibble)

U16 (address mux low byte):
  1A[3:0] = PC[3:0],  1B[3:0] = pl[3:0]
  2A[3:0] = PC[7:4],  2B[3:0] = pl[7:4]*
  S = addr_sel
  Y → address bus [7:0]

U17 (address mux high byte):
  1A[3:0] = PC[11:8], 1B[3:0] = ph[3:0]
  2A[3:0] = PC[15:12],2B[3:0] = ph[7:4]*
  S = addr_sel
  Y → address bus [15:8]

* Note: 74HC161 is 4-bit. Full 8-bit pointer needs 4× 161 total.
  For this lab, use 4-bit pointer (256-byte range) to keep it simple.
  Final build uses cascaded pairs.

62256 RAM:
  A[14:0] ← address bus
  D[7:0] ↔ data bus
  /CE ← decode (active for $0000-$7FFF)
  /OE ← /RD
  /WE ← /WR
```

## Procedure

1. Insert U11, U12 (74HC161). Connect VCC/GND.
2. Wire U11 TC → U12 ENT (carry chain).
3. Insert U16, U17 (74HC157). Connect VCC/GND.
4. Wire PC outputs to mux "A" inputs (addr_sel=0 selects PC).
5. Wire pointer outputs to mux "B" inputs (addr_sel=1 selects pointer).
6. Wire mux Y outputs to address bus.
7. Add addr_sel toggle switch to mux S pins.
8. Insert 62256 RAM. Wire address bus to A[14:0], data bus to D[7:0].
9. Wire RAM /CE to address decode (or tie LOW for testing).
10. Add /RD and /WR manual pushbuttons for RAM control.

## Test Procedure

| Test | Action | Expected Result |
|:----:|--------|-----------------|
| 1 | addr_sel=0 (PC mode) | Address bus shows PC count (ROM fetch works as before) |
| 2 | addr_sel=1 (pointer mode) | Address bus shows pointer value |
| 3 | Load pointer with $2000 (ph=$20, pl=$00) | Address bus = $2000 |
| 4 | Put $42 on data bus, pulse /WR | RAM[$2000] = $42 |
| 5 | Release data bus, pulse /RD | Data bus shows $42 (read back) |
| 6 | Pulse ptr_inc | Address becomes $2001 |
| 7 | Write $55 to $2001, read back | Data bus shows $55 |
| 8 | Switch to addr_sel=0 | Back to PC/ROM fetch mode |

## Checkoff

- [ ] Address mux selects PC (S=0) or pointer (S=1) correctly
- [ ] Pointer loads a value and outputs it to address bus
- [ ] Pointer auto-increments with carry (pl→ph)
- [ ] RAM write + read back works at pointer address
- [ ] Switching between PC and pointer doesn't corrupt either

## Notes
- In the final CPU, addr_sel is controlled by the state machine (S0/S1 = PC for fetch, S2 = pointer for load/store).
- The full address mux has more sources (stack, zero-page, page-relative). This lab tests the two most important: PC and pointer.
- RAM and ROM coexist on the same data bus — the address decode ensures only one responds at a time.
