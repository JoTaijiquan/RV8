# RV8-GR — Bank Switch (Run Code from RAM)

**+1 chip (74HC86). Enables loading and running programs from RAM.**

---

## How it works:

```
BANK=0 (boot, default):
  Fetch: PC → ROM ($8000+)
  Data:  operand → RAM ($0000+)
  Registers: $0000-$0007 (safe in RAM)

BANK=1 (after loading program):
  Fetch: PC XOR'd → RAM ($0100+)
  Data:  operand → RAM ($0000+) (unchanged!)
  Registers: $0000-$0007 (still safe, data path unchanged)
```

## Hardware:

```
U22 (74HC86, new chip):
  Gate 1: PC_A15 XOR BANK → address bus A15 (during fetch only)
  Gates 2-4: spare

BANK bit: stored in U20 spare FF (or U14 spare bit)
  Set by: special control byte (e.g., $03 = JUMP + BRANCH = "set bank + jump")
  Clear by: reset (/RST clears BANK to 0)
```

## Memory map (BANK=1):

```
RAM:
  $0000-$0007: registers (always, data path)
  $0008-$00FF: stack + variables (data path)
  $0100-$7FFF: user program (fetch path, loaded from SD/PC)

ROM:
  $8000-$FFFF: boot loader + system routines
  (still accessible via BANK=0 or system call)
```

## Boot sequence:

```
1. Power on → BANK=0, PC=$8000 (ROM)
2. ROM boot code initializes hardware
3. ROM code reads program from SD (via Programmer board I/O)
4. ROM code writes program to RAM at $0100+
5. ROM code sets BANK=1
6. ROM code jumps to $8100 (XOR'd = $0100 in RAM)
7. User program runs from RAM!
8. User program can call ROM routines by: clear BANK, call, set BANK
```

## Calling ROM from RAM:

```asm
; In RAM program, need to call ROM routine:
    ; Save BANK state, clear BANK, call ROM, restore BANK
    ; Simplified: use a "syscall" trap that ROM handles
    li    $FF         ; syscall number
    j     $80        ; jump to syscall handler (in ROM, BANK=0 area)
```

Actually simpler: ROM routines at $0000-$00FF are in RAM space too. Put a **jump table** at $00F0-$00FF in RAM that ROM fills at boot:

```
RAM[$F0] = jump to print_char (in ROM)
RAM[$F2] = jump to read_key (in ROM)
...
```

User program calls: `j $F0` → executes jump table → reaches ROM routine.

## Chip count:

```
RV8-GR base: 21 logic chips
+ U22 (74HC86): bank switch XOR = +1
Total: 22 logic chips + ROM + RAM = 24 packages
```

## Revised comparison:

| Feature | Without bank | With bank (+1 chip) |
|---------|:---:|:---:|
| Run from ROM | ✅ | ✅ |
| Run from RAM | ❌ | ✅ |
| Load from SD | ❌ | ✅ |
| Registers safe | ✅ | ✅ |
| Chips | 21 | **22** |
| Total | 23 | **24** |

## Optional — not required for basic build. Add later when SD card support is needed.

---

## PREFERRED: Bank switch on TRAINER BOARD (not CPU board)

**CPU board stays at 21 chips. Bank switch lives on Trainer board.**

```
CPU Board (21 chips, pure, simple):
  PC → A[15:0] → RV8-Bus (no bank logic)

Trainer Board (via RV8-Bus):
  Intercepts A15 on bus
  XOR(A15, BANK) → routes to ROM/RAM
  BANK flip-flop set by I/O write ($FF00)
  SD card (SPI) for loading programs
  LEDs, step button, etc.
```

### How CPU sets BANK (via I/O write on bus):
```asm
li    $01
sb    $FF         ; write to Trainer I/O address → BANK=1
j     $00         ; PC=$8100, XOR'd by Trainer → fetches from RAM $0100
```

### Why this is better:
- CPU board is universal (works with or without Trainer)
- No CPU hardware change for bank switch
- Trainer board adds features non-invasively via bus
- Same CPU board works with Programmer board (no bank needed)
- SD card, bank switch, LEDs all on one expansion board

### Memorize for future Trainer board design:
- Bank switch XOR on A15 (1 gate from 74HC86)
- BANK flip-flop (1 FF from 74HC74) set by bus write to $FF00
- SD card SPI interface (directly on Trainer board)
- Load sequence: Trainer reads SD → writes to RAM via bus → sets BANK → releases CPU
