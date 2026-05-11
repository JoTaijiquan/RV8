# RV8: Minimal 8-bit CPU — RISC-inspired, accumulator-based

## What is This?

This is a **tiny computer processor** (CPU) written in a language called **Verilog**. It works just like the CPU inside your phone or laptop — but simple enough to understand!

A CPU does only 3 things:
1. **Fetch** — Read the next instruction from memory
2. **Decode** — Figure out what the instruction means
3. **Execute** — Do the work (add numbers, load data, etc.)

Our CPU does all 3 steps in **one clock tick** (called "single-cycle").

---

## 🧱 Parts of Our CPU

Think of the CPU like a LEGO set. Each piece has one job:

```
┌─────────────────────────────────────────────────────┐
│                    CPU                                │
│                                                      │
│  ┌────┐    ┌──────┐    ┌─────┐    ┌─────┐          │
│  │ PC │───▶│ IMEM │───▶│CTRL │    │ IMM │          │
│  └────┘    └──────┘    └─────┘    └─────┘          │
│    │                       │          │              │
│    ▼                       ▼          ▼              │
│  ┌────────────┐    ┌─────────┐    ┌──────┐         │
│  │  PC + 4    │    │  REG    │───▶│ ALU  │         │
│  └────────────┘    │  FILE   │    └──────┘         │
│                    └─────────┘       │              │
│                         ▲            ▼              │
│                         │       ┌──────┐            │
│                         └───────│ DMEM │            │
│                                 └──────┘            │
└─────────────────────────────────────────────────────┘
```

| Part | Full Name | What It Does | Real-Life Analogy |
|------|-----------|-------------|-------------------|
| PC | Program Counter | Points to the current instruction | A bookmark in a recipe book |
| IMEM | Instruction Memory | Stores the program | The recipe book itself |
| CTRL | Control Unit | Decides what to do | The chef reading the recipe |
| REG FILE | Register File | 32 small storage boxes (x0–x31) | Bowls on the counter |
| IMM | Immediate Generator | Extracts numbers from instructions | Reading a number from the recipe |
| ALU | Arithmetic Logic Unit | Does math and logic | A calculator |
| DMEM | Data Memory | Stores data (like variables) | The pantry/fridge |

---

## 📋 Instructions Our CPU Understands

Our CPU knows **10 instructions** (real RISC-V CPUs know ~50):

### Math Instructions
| Instruction | Example | What It Does |
|-------------|---------|-------------|
| ADD | `add x3, x1, x2` | x3 = x1 + x2 |
| SUB | `sub x4, x1, x2` | x4 = x1 - x2 |
| AND | `and x5, x1, x2` | x5 = x1 AND x2 (bitwise) |
| OR | `or x6, x1, x2` | x6 = x1 OR x2 (bitwise) |
| ADDI | `addi x1, x0, 5` | x1 = x0 + 5 (add a number directly) |

### Memory Instructions
| Instruction | Example | What It Does |
|-------------|---------|-------------|
| LW | `lw x7, 0(x0)` | Load a word from memory into x7 |
| SW | `sw x3, 0(x0)` | Store x3's value into memory |

### Control Instructions (Jumping Around)
| Instruction | Example | What It Does |
|-------------|---------|-------------|
| BEQ | `beq x1, x2, 8` | If x1 == x2, jump forward 8 bytes |
| JAL | `jal x1, 16` | Jump forward 16 bytes, save return address |
| LUI | `lui x1, 0x12345` | Load a big number into upper bits of x1 |

---

## 🔢 How Instructions Are Encoded (Machine Code)

Every instruction is a **32-bit number**. The CPU reads bits in specific positions:

```
For ADD x3, x1, x2:

 31      25 24  20 19  15 14 12 11   7 6     0
┌─────────┬──────┬──────┬─────┬──────┬────────┐
│ 0000000 │ 00010│ 00001│ 000 │ 00011│0110011 │
│ funct7  │  rs2 │  rs1 │func3│  rd  │ opcode │
└─────────┴──────┴──────┴─────┴──────┴────────┘
         = 0x002081B3
```

- **opcode** (bits 0–6): What type of instruction
- **rd** (bits 7–11): Destination register
- **rs1, rs2** (bits 15–19, 20–24): Source registers
- **funct3, funct7**: Specifies the exact operation

---

## 🧪 Try It Yourself!

### Step 1: Install the Simulator

You need **Icarus Verilog** (free!):

- **Linux**: `sudo apt install iverilog`
- **Mac**: `brew install icarus-verilog`
- **Windows**: Download from http://bleyer.org/icarus/

### Step 2: Run the Test Program

```bash
cd /home/jo/kiro
iverilog -o sim riscv_cpu.v tb_riscv_cpu.v
vvp sim
```

You should see:
```
=== RISC-V CPU Test Results ===
x1 = 5 (expect 5)
x2 = 3 (expect 3)
x3 = 8 (expect 8)
x4 = 2 (expect 2)
x5 = 1 (expect 1)
x6 = 7 (expect 7)
x7 = 8 (expect 8)
x8 = 0 (expect 0)
x9 = 42 (expect 42)
>>> ALL TESTS PASSED <<<
```

### Step 3: View the Waveform (Optional)

```bash
gtkwave riscv_cpu.vcd
```

This shows you signals changing over time — like watching the CPU think!

---

## 📝 Walkthrough: What the Test Program Does

Let's trace through the program step by step:

```
Clock 1:  addi x1, x0, 5     →  x1 = 0 + 5 = 5
Clock 2:  addi x2, x0, 3     →  x2 = 0 + 3 = 3
Clock 3:  add  x3, x1, x2    →  x3 = 5 + 3 = 8
Clock 4:  sub  x4, x1, x2    →  x4 = 5 - 3 = 2
Clock 5:  and  x5, x1, x2    →  x5 = 101 & 011 = 001 = 1
Clock 6:  or   x6, x1, x2    →  x6 = 101 | 011 = 111 = 7
Clock 7:  sw   x3, 0(x0)     →  memory[0] = 8
Clock 8:  lw   x7, 0(x0)     →  x7 = memory[0] = 8
Clock 9:  beq  x1, x1, +8    →  x1 == x1? YES! Skip next instruction
Clock 10: (skipped!)          →  x8 stays 0
Clock 11: addi x9, x0, 42    →  x9 = 42
```

Notice at Clock 9: since x1 equals x1, the CPU **jumps over** the next instruction. That's how computers make decisions!

---

## 🎯 Exercises for Students

### Exercise 1: Change the Numbers
Edit `tb_riscv_cpu.v` and change:
```verilog
CPU.IMEM.mem[0] = 32'h00500093; // addi x1, x0, 5
```
to load a different number (e.g., 10 = 0x00A00093). What changes?

### Exercise 2: Add More Instructions
After the existing program, add:
```verilog
CPU.IMEM.mem[11] = 32'h00940933; // add x18, x8, x9
```
What will x18 contain?

### Exercise 3: Make an Infinite Loop
Can you write a `beq` that jumps back to itself? (Hint: the offset would be 0)

### Exercise 4: Trace by Hand
Draw a table with columns: Clock, PC, Instruction, Result. Fill it in for the first 5 clocks without running the simulator. Then check your answers!

### Exercise 5: Build with Gates
Pick one module (start with the ALU). Draw it using only:
- AND gates
- OR gates
- NOT gates
- Full adders

---

## 💡 Key Concepts to Remember

1. **Everything is binary** — The CPU only sees 0s and 1s
2. **x0 is always zero** — You can't change it (useful as a constant!)
3. **PC moves by 4** — Each instruction is 4 bytes (32 bits)
4. **Branches change the PC** — That's how loops and if-statements work
5. **Memory is separate from registers** — Registers are fast (on the CPU), memory is big (off the CPU)

---

## 🗂️ File List

| File | Description |
|------|-------------|
| `riscv_cpu.v` | The CPU design (all modules) |
| `tb_riscv_cpu.v` | Test program that verifies the CPU works |
| `README.md` | This document |

---

## 🌟 What's Next?

Once you understand this CPU, you can:
- Add more instructions (SLTI, XOR, SRA, etc.)
- Add a pipeline (fetch and execute different instructions at the same time)
- Connect it to LEDs or a display
- Run real RISC-V programs compiled with GCC

Congratulations — you now understand how a computer works at the deepest level! 🎉
