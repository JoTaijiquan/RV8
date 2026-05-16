# RV8 Project — Task Tracker

**Last updated**: 2026-05-16 23:11
**Focus**: RV8-WR (19 chips, no microcode, cheapest that plays games)

---

## ✅ Completed (RV8-WR)

- [x] Design (19 chips, RAM registers, accumulator, no microcode)
- [x] ISA defined (21 instructions, ~80% RV8 compatible, XOR free)
- [x] Control byte encoding (8-bit + 3 derived gates)
- [x] WiringGuide (bus-centric, 19 chips, verified no conflicts)
- [x] README with chip list and ISA table
- [x] Programmer board (shared, works with all variants)

---

## ⬜ TODO — RV8-WR (next steps in order)

| # | Task | Priority | Notes |
|:-:|------|:--------:|-------|
| 1 | **Instruction trace** (trace ADD, LB, SB, BEQ through hardware) | HIGH | Verify WiringGuide actually works |
| 2 | **Verilog model** (rv8wr_cpu.v, match hardware exactly) | HIGH | Model the 3-cycle, control-byte-driven design |
| 3 | **Testbench** (all 21 instructions) | HIGH | Prove ISA works |
| 4 | **Assembler** (rv8wr_asm.py) | HIGH | Need it to write programs |
| 5 | **Build Programmer board** (physical) | HIGH | Need it to flash ROM |
| 6 | **Order parts** (19 chips + ROM + RAM) | MEDIUM | ~$15 total |
| 7 | **Breadboard build** | MEDIUM | The real test |
| 8 | **First program** (LED blink or Fibonacci) | MEDIUM | Proof of life |
| 9 | **Understand by Module** (Thai+English) | MEDIUM | For students |
| 10 | **BASIC interpreter** | LOW | After hardware proven |

---

## ⬜ TODO — Other variants (lower priority)

| Task | Variant | Notes |
|------|---------|-------|
| Verilog for RV8-R | RV8-R | Same as RV8 minus register chips |
| WiringGuide for RV8-R | RV8-R | Same as RV8 minus registers |
| Complete RV8 microcode (all 35 instr) | RV8 | Currently 8/8, need all 35 |

---

## Priority Order (RV8-WR focus)

```
1. Instruction trace (verify hardware paths)
2. Verilog model (prove design in simulation)
3. Testbench (all 21 instructions pass)
4. Assembler (write programs)
5. Build Programmer board
6. Order chips
7. Build on breadboard
8. First program running!
```

---

## Parts to order (RV8-WR)

| Part | Qty | Source | Est. cost |
|------|:---:|--------|:---------:|
| 74HC574 (DIP-20) | 3 | บ้านหม้อ | ฿30 |
| 74HC283 (DIP-16) | 2 | Mouser/Shopee | ฿40 |
| 74HC86 (DIP-14) | 2 | บ้านหม้อ | ฿15 |
| 74HC157 (DIP-16) | 4 | บ้านหม้อ | ฿30 |
| 74HC161 (DIP-16) | 4 | บ้านหม้อ | ฿30 |
| 74HC541 (DIP-20) | 2 | Shopee/RS | ฿25 |
| 74HC245 (DIP-20) | 1 | บ้านหม้อ | ฿10 |
| 74HC74 (DIP-14) | 1 | บ้านหม้อ | ฿8 |
| SST39SF010A (PDIP-32) | 1 | Mouser | ฿100 |
| 62256 (DIP-28) | 1 | Shopee | ฿50 |
| Crystal 3.5MHz | 1 | บ้านหม้อ | ฿15 |
| Breadboard | 2 | Shopee | ฿150 |
| LED + 330Ω | 10 | บ้านหม้อ | ฿20 |
| Misc (caps, resistors, wires) | — | — | ฿50 |
| **Total** | | | **~฿575 (~$16)** |
