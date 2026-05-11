# RV8 In-Circuit ROM Programmer (Pico-based)

Program the AT28C256 EEPROM without removing it from the board.

## How It Works

```
PC (USB) ──► Pico (USB-serial) ──► AT28C256 on CPU board
                                      │
                              CPU held in /RST
                              Bus buffer disabled
```

1. Flip PROG switch → CPU held in reset, bus buffer (U19) disabled
2. Pico takes over address/data/control lines to ROM
3. PC sends binary over USB → Pico writes to EEPROM
4. Flip switch back → CPU boots from new ROM

## Circuit

### PROG Mode Switch

```
PROG switch (active = programming mode):
  ┌─────┐
  │ SW  │──┬──► CPU /RST (active low = held in reset)
  │PROG │  │
  └─────┘  ├──► U19 (74HC245) /OE pin (high = bus buffer disabled)
           │
           └──► Pico GP22 (reads PROG state, optional)
           
When PROG=GND:  CPU runs normally, Pico pins are hi-Z
When PROG=VCC:  CPU in reset, bus buffer off, Pico drives ROM
```

### Pico Pin Mapping

```
AT28C256 Pinout:        Pico GPIO Assignment:
─────────────────       ──────────────────────
A0  (pin 10)     ◄──   GP0
A1  (pin 9)      ◄──   GP1
A2  (pin 8)      ◄──   GP2
A3  (pin 7)      ◄──   GP3
A4  (pin 6)      ◄──   GP4
A5  (pin 5)      ◄──   GP5
A6  (pin 4)      ◄──   GP6
A7  (pin 3)      ◄──   GP7
A8  (pin 25)     ◄──   GP8
A9  (pin 24)     ◄──   GP9
A10 (pin 21)     ◄──   GP10
A11 (pin 23)     ◄──   GP11
A12 (pin 2)      ◄──   GP12
A13 (pin 26)     ◄──   GP13
A14 (pin 1)      ◄──   GP14

D0  (pin 11)     ◄──►  GP15
D1  (pin 12)     ◄──►  GP16
D2  (pin 13)     ◄──►  GP17
D3  (pin 15)     ◄──►  GP18
D4  (pin 16)     ◄──►  GP19
D5  (pin 17)     ◄──►  GP20
D6  (pin 18)     ◄──►  GP21
D7  (pin 19)     ◄──►  GP26

/CE  (pin 20)    ◄──   GP27  (active low)
/OE  (pin 22)    ◄──   GP28  (active low)
/WE  (pin 27)    ◄──   GND via PROG switch (directly active)
                        GP22  (directly active when programming)

Total: 26 GPIO used (Pico has 26 available — perfect fit)
```

Wait — let me reconsider. /WE needs precise timing control from the Pico:

```
Revised control pins:
/CE  (pin 20)    ◄──   GP27
/OE  (pin 22)    ◄──   GP28
/WE  (pin 27)    ◄──   GP22
```

### Wiring Diagram

```
                Raspberry Pi Pico
        ┌─────────────────────────────────┐
        │ GP0─GP14  ──────────────────────┼──► ROM A0-A14
        │ GP15─GP21,GP26 ─────────────────┼──► ROM D0-D7
        │ GP27 ───────────────────────────┼──► ROM /CE
        │ GP28 ───────────────────────────┼──► ROM /OE
        │ GP22 ───────────────────────────┼──► ROM /WE
        │ USB ────────────────────────────┼──► PC (serial)
        │ GND ────────────────────────────┼──► Board GND
        └─────────────────────────────────┘

        PROG Switch:
        ┌─────┐
        │ OFF │ = Normal (CPU runs)
        │ ON  │ = Program mode:
        │     │   - CPU /RST held low
        │     │   - U19 /OE held high (bus buffer off)
        └─────┘
```

### AT28C256 Write Timing

```
Byte write sequence (per byte):
  1. Set address on A0-A14
  2. Set data on D0-D7
  3. /CE = LOW, /OE = HIGH
  4. /WE = LOW (min 100ns)
  5. /WE = HIGH → data latches, write begins
  6. Wait for write completion (~5ms max, or poll D7)

Page write (up to 64 bytes):
  1. Same as above but repeat steps 1-5 for up to 64 bytes
     within same 64-byte page (A6-A14 must stay same)
  2. After last byte, wait ~10ms for page to commit

Data polling (faster than fixed delay):
  After write, read D7 — it returns complement until done,
  then returns true data. Typical: <1ms per byte.
```

## Parts Needed

| Part | Qty | Cost |
|------|:---:|:----:|
| Raspberry Pi Pico | 1 | ~$4 |
| SPDT toggle switch (PROG) | 1 | ~$0.50 |
| Hookup wire | 26 | — |
| **Total** | | **~$5** |

No extra ICs needed — the Pico drives the ROM directly while the CPU is held in reset.
