# RV8 Simulations — Try Before You Build!

These simulations let you **test each part of the CPU on your computer** before wiring real chips.

Think of it like a video game tutorial — practice each level in software, then do it for real on the breadboard.

## What You Need (Free!)

Install two programs:

```bash
sudo apt install iverilog gtkwave
```

- **iverilog** — runs the simulation (like pressing "play")
- **gtkwave** — shows signals as waves (like an oscilloscope on screen)

## How to Run

```bash
cd sim/

# Run one lab:
make lab1

# Run ALL labs:
make all

# See the waveform (the fun part!):
gtkwave lab1.vcd
```

## The Labs

| Lab | What It Simulates | What You'll See |
|:---:|-------------------|-----------------|
| 1 | Clock + Reset | A square wave that you can start/stop |
| 2 | Counter (PC) | Numbers counting up: 0, 1, 2, 3... |
| 3 | Reading from ROM | The CPU fetching bytes from memory |
| 4 | Instruction Register | The CPU remembering what to do |
| 5 | Calculator (ALU) | Adding and subtracting numbers |
| 6 | Storage (Registers) | Saving results and reusing them |
| 7 | Pointer + RAM | Writing to memory and reading it back |
| 8 | Full CPU! | A complete computer running a program |

## What Does "PASSED" Mean?

When you run a lab, it prints either:
```
Lab 5 PASSED    ← Great! The circuit works correctly.
Lab 5 FAILED    ← Something is wrong. Check the waveform.
```

## How to Read the Waveform (GTKWave)

1. Run: `gtkwave lab5.vcd`
2. On the left, click signals to add them (like `a`, `b`, `result`)
3. You'll see colored lines going up (1) and down (0) over time
4. Zoom in/out with the mouse wheel
5. This is exactly what a real oscilloscope would show on your breadboard!

```
        ___     ___     ___
CLK  __|   |___|   |___|   |___    ← clock ticks

       0001    0010    0011
PC   ──────X────────X────────X──    ← counter goes up

       AA      55      01
DATA ──────X────────X────────X──    ← bytes from ROM
```

## Tips

- Run the simulation FIRST. If it passes, your design is correct.
- If the real circuit doesn't work but the simulation does → it's a wiring mistake.
- If the simulation fails → fix the design before building anything.
- Use GTKWave to understand timing — when does each signal change?

## Quick Reference

| Command | What It Does |
|---------|-------------|
| `make lab3` | Simulate lab 3 |
| `make all` | Simulate all labs |
| `make clean` | Delete output files |
| `gtkwave lab3.vcd` | View lab 3 waveform |
