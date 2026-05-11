# RV8 Trainer Board

Peripheral board that plugs into the CPU board's expansion connector.
Provides serial programming, LEDs, switches, and I/O for learning.

## CPU Board Expansion Connector (active low = /name)

| Pin | Dir | Signal |
|:---:|:---:|--------|
| 1-16 | OUT | A[15:0] |
| 17-24 | I/O | D[7:0] |
| 25 | OUT | /RD |
| 26 | OUT | /WR |
| 27 | OUT | CLK |
| 28 | IN | /RST |
| 29 | IN | /NMI |
| 30 | IN | /IRQ |
| 31 | OUT | HALT |
| 32 | OUT | SYNC |
| 33 | — | VCC (+5V) |
| 34 | — | GND |

**34-pin IDC ribbon cable** connects CPU board to trainer board.

## Trainer Board Chips

| # | Part | Function |
|---|------|----------|
| T1 | MC6850 | UART (serial I/O) |
| T2 | 74HC574 | Output port (8 LEDs) |
| T3 | 74HC245 | Input port (8 DIP switches) |
| T4 | 74HC138 | I/O address decode |

**4 chips total**

## I/O Memory Map

| Address | R/W | Device | Function |
|:-------:|:---:|--------|----------|
| $8000 | R/W | MC6850 | UART data register |
| $8001 | R/W | MC6850 | UART control/status |
| $8002 | W | 74HC574 | LED output port |
| $8003 | R | 74HC245 | Switch input port |

## UART Wiring (T1: MC6850)

```
         MC6850 (T1)
    ┌──────────────────┐
    │ D0-D7 ◄──► D[7:0] (data bus)
    │ RS    ◄─── A0
    │ /CS0  ◄─── T4./Y0 (I/O decode)
    │ CS1   ◄─── VCC
    │ R/W   ◄─── /WR
    │ E     ◄─── /RD (active-low read strobe)
    │ /IRQ  ───► /IRQ (optional, active low)
    │ TxD   ───► CH340 RX
    │ RxD   ◄─── CH340 TX
    │ TxCLK ◄─── baud clock (÷16 of baud rate)
    │ RxCLK ◄─── baud clock
    └──────────────────┘

Baud clock: 3.5MHz ÷ 2 = 1.8432MHz... not exact.
Better: use 1.8432MHz crystal oscillator for UART clock.
  1.8432MHz ÷ 16 = 115200 baud (exact)
```

## LED Output (T2: 74HC574)

```
    D[7:0] ──► 74HC574 ──► 8 LEDs (with 330Ω resistors)
    CLK = /WR AND T4./Y1 (active on write to $8002)
```

## Switch Input (T3: 74HC245)

```
    8 DIP switches ──► 74HC245 ──► D[7:0]
    /OE = /RD AND T4./Y1 (active on read from $8003)
```

## I/O Decode (T4: 74HC138)

```
    A = A0
    B = A1
    C = A2 (unused, tie low for 4 devices)
    /G2A = CPU board /Y4 (active when A[15:13]=100, i.e. $8000-$9FFF)
    G1 = VCC

    /Y0 → MC6850 /CS ($8000-$8001)
    /Y1 → LED latch CLK ($8002-$8003)
    /Y2-/Y7 → expansion (future devices)
```

## USB-Serial Connection

```
    ┌──────────┐         ┌────────┐
    │ CH340    │ TX ───► │ MC6850 │ RxD
    │ USB-ser  │ RX ◄─── │        │ TxD
    │ module   │ GND ──► │        │ GND
    └──────────┘         └────────┘
         │
    USB to PC
```

## Programming via Bootloader

With bootloader in ROM ($FE00-$FFFF):
1. Reset CPU → bootloader reads serial via MC6850 at $8000
2. PC sends program binary
3. Bootloader writes to ROM
4. CPU jumps to $C000

No special hardware mode needed — just plug in USB and upload.

## Parts List

| Part | Qty | Cost |
|------|:---:|:----:|
| MC6850 ACIA | 1 | ~$3 |
| 74HC574 | 1 | ~$0.50 |
| 74HC245 | 1 | ~$0.50 |
| 74HC138 | 1 | ~$0.50 |
| 1.8432MHz crystal osc | 1 | ~$1 |
| CH340 USB-serial module | 1 | ~$2 |
| LEDs (red) | 8 | ~$1 |
| 330Ω resistors | 8 | ~$0.50 |
| DIP switch (8-pos) | 1 | ~$1 |
| 34-pin IDC connector | 2 | ~$1 |
| Breadboard | 1 | ~$5 |
| **Total** | | **~$16** |
