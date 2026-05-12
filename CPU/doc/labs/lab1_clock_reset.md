# Lab 1: Clock and Reset Circuit

## Objective
Build a controllable clock source and clean reset signal for the RV8 CPU.

## Components
| Part | Qty | Description |
|------|:---:|-------------|
| 3.5 MHz crystal oscillator | 1 | Full-can oscillator module |
| 74HC157 | 1 | Quad 2:1 mux (clock select) |
| Tactile pushbutton | 2 | STEP and RESET |
| 10KΩ resistor | 2 | Pull-up / debounce |
| 100nF capacitor | 2 | Debounce / decoupling |
| LED + 330Ω | 2 | CLK indicator, /RST indicator |

## Schematic

```
         3.5MHz OSC
            │
            ├──── 74HC157 pin 2 (1A0) ──── "RUN" input
            │
  STEP ─┐   │
  button─┤   │
  (debounce) ├── 74HC157 pin 3 (1B0) ──── "STEP" input
         │   │
         └───┘
              │
  RUN/STEP ───── 74HC157 pin 1 (S) ──── mode select
  switch
              │
              └── 74HC157 pin 4 (1Y0) ──► CLK output
                                           │
                                         LED + 330Ω → GND


  /RST circuit:
  VCC ─── 10K ─┬─── /RST output
               │        │
  RESET btn ───┘   100nF ─── GND
  (to GND)
```

## Simulate First

Before wiring real chips, verify the design in simulation:

```bash
cd sim/
iverilog -o lab1 lab1_clock_tb.v && vvp lab1
gtkwave lab1.vcd   # view waveform
```

**What to check in GTKWave:**
- `osc`: continuous 3.5 MHz square wave
- `clk`: follows osc in RUN mode, single pulses in STEP mode
- `rst_n`: goes LOW on reset, returns HIGH cleanly

---

## Procedure

1. Insert 74HC157 on breadboard. Connect VCC (pin 16) and GND (pin 8).
2. Wire crystal oscillator output to 74HC157 input 1A0 (pin 2).
3. Wire STEP button with debounce (10K pull-up + 100nF to GND) to input 1B0 (pin 3).
4. Wire RUN/STEP toggle switch to select pin S (pin 1).
5. Tie /E (pin 15) to GND (always enabled).
6. Output 1Y0 (pin 4) is your CLK signal. Connect LED + 330Ω for visual.
7. Build /RST circuit: 10K pull-up to VCC, button to GND, 100nF cap for debounce.
8. Connect /RST LED (lights when reset is active).

## Test Procedure

| Test | Action | Expected Result |
|:----:|--------|-----------------|
| 1 | Switch to RUN mode | CLK LED appears solid (too fast to see blink) |
| 2 | Switch to STEP mode | CLK LED is OFF |
| 3 | Press STEP button | CLK LED blinks once per press |
| 4 | Probe CLK with scope (RUN) | Clean 3.5 MHz square wave, 50% duty |
| 5 | Probe CLK with scope (STEP) | Single clean pulse per button press |
| 6 | Press RESET | /RST LED lights, /RST line goes LOW |
| 7 | Release RESET | /RST returns HIGH cleanly (no bounce) |

## Checkoff

- [ ] CLK output: 3.5 MHz in RUN mode
- [ ] CLK output: single pulse per press in STEP mode
- [ ] /RST: clean LOW when pressed, HIGH when released
- [ ] No ringing or bounce on either signal (verify with scope)

## Notes
- The CLK LED won't visibly blink at 3.5 MHz — it will appear always-on. This is normal.
- In STEP mode, you'll use this to manually clock the CPU one cycle at a time for debugging.
- Keep wires to the oscillator short to avoid noise.
