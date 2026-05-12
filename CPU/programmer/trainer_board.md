# RV8 Trainer Board

Peripheral + programmer board. Plugs into CPU board universal bus slot (40-pin).
Uses ESP32 NodeMCU for ROM programming and serial communication.
74HCT245 handles 3.3V ↔ 5V level shifting.

## System Overview

```
┌──────────────┐  40-pin   ┌───────────────────────────────────────┐
│  CPU Board   │◄─ribbon──►│            Trainer Board              │
│  27 chips    │  cable    │                                       │
│  (5V)       │           │  ESP32 NodeMCU ──► USB to PC          │
│              │           │       │ (3.3V)                        │
│              │           │       ▼                               │
│              │           │  74HCT245 (level shift 3.3V→5V)      │
│              │           │       │                               │
│  AT28C256 ◄──────────────│  74HC595 ×2 (address, PROG mode)     │
│  (ROM)       │           │  MC6850 (UART, RUN mode)             │
│              │           │  74HC574 (8 LEDs)                    │
│              │           │  74HC245 (8 switches)                │
│              │           │  74HC138 (I/O decode)                │
└──────────────┘           └───────────────────────────────────────┘
```

## Modes

| Mode | Switch | What happens |
|------|:------:|-------------|
| PROG | ON | ESP32 drives ROM directly, CPU held in /RST |
| RUN | OFF | CPU runs, ESP32 bridges USB ↔ MC6850 |

## Universal Bus Slot (40-pin, on CPU board)

| Pin | Signal | Pin | Signal |
|:---:|--------|:---:|--------|
| 1 | A0 | 2 | A1 |
| 3 | A2 | 4 | A3 |
| 5 | A4 | 6 | A5 |
| 7 | A6 | 8 | A7 |
| 9 | A8 | 10 | A9 |
| 11 | A10 | 12 | A11 |
| 13 | A12 | 14 | A13 |
| 15 | A14 | 16 | A15 |
| 17 | D0 | 18 | D1 |
| 19 | D2 | 20 | D3 |
| 21 | D4 | 22 | D5 |
| 23 | D6 | 24 | D7 |
| 25 | /RD | 26 | /WR |
| 27 | CLK | 28 | /RST |
| 29 | /NMI | 30 | /IRQ |
| 31 | HALT | 32 | SYNC |
| 33 | N/A | 34 | N/A |
| 35 | N/A | 36 | N/A |
| 37 | N/A | 38 | N/A |
| 39 | VCC | 40 | GND |

## Chip List

| # | Part | Function |
|---|------|----------|
| T1 | ESP32 NodeMCU | USB-serial + ROM programmer |
| T2 | 74HCT245 | Level shift (3.3V ESP32 ↔ 5V bus) |
| T3a | 74HC595 | Address low shift register (A0-A7) |
| T3b | 74HC595 | Address high shift register (A8-A14) |
| T4 | MC6850 | UART (CPU serial in RUN mode) |
| T5 | 74HC574 | Output port (8 LEDs) |
| T6 | 74HC245 | Input port (8 DIP switches) |
| T7 | 74HC138 | I/O address decode |

**7 chips + ESP32 NodeMCU**

## Level Shifting (T2: 74HCT245)

```
ESP32 (3.3V) ──► 74HCT245 (powered at 5V) ──► 5V bus
                  VCC = 5V
                  DIR = controlled by ESP32
                  
HCT accepts 3.3V as valid HIGH (VIH = 2.0V)
Outputs are full 5V swing
```

Signals through level shifter:
- SER, SRCLK, RCLK (to 595s)
- /WE, /CE, /OE (to ROM)
- /RST (to CPU)

Data bus (D0-D7) needs bidirectional shifting:
- PROG write: ESP32 → 74HCT245 → ROM (DIR=A→B)
- PROG read/verify: ROM → voltage divider → ESP32 (DIR=B→A)

Simple solution: use **two 74HCT245** — one for control/address, one for data (bidirectional).

Revised:
| T2a | 74HCT245 | Level shift: control signals (one-way, ESP32→bus) |
| T2b | 74HCT245 | Level shift: data bus (bidirectional) |

**8 chips + ESP32 total**

## ESP32 Pin Mapping

```
ESP32 GPIO    Signal          Through T2 to:
──────────    ──────          ──────────────
GPIO 23       SER             595 serial data
GPIO 18       SRCLK           595 shift clock
GPIO 19       RCLK            595 latch
GPIO 4        /WE             ROM write enable
GPIO 16       /CE             ROM chip enable
GPIO 17       /OE             ROM output enable
GPIO 5        /RST            CPU reset (hold low = PROG)
GPIO 34       PROG_SW         Mode switch (input-only, no shifter)
GPIO 13       D0              ROM data bus
GPIO 12       D1              (through T2b)
GPIO 14       D2
GPIO 27       D3
GPIO 26       D4
GPIO 25       D5
GPIO 33       D6
GPIO 32       D7
GPIO 21       UART_TX         MC6850 RxD (RUN mode)
GPIO 22       UART_RX         MC6850 TxD (RUN mode)
```

## I/O Memory Map (RUN mode)

| Address | R/W | Device | Function |
|:-------:|:---:|--------|----------|
| $8000 | R/W | MC6850 | UART control/status |
| $8001 | R/W | MC6850 | UART data |
| $8002 | W | 74HC574 | LED output |
| $8003 | R | 74HC245 | Switch input |

## I/O Decode (T7: 74HC138)

```
A = A0, B = A1, C = GND
/G2A = CPU board I/O select (A[15:13]=100)
G1 = VCC

/Y0 → MC6850 /CS  ($8000-$8001)
/Y1 → LED latch   ($8002-$8003)
/Y2 → switches    ($8004-$8005)
/Y3-/Y7 → expansion
```

## MC6850 UART (T4)

```
D0-D7  ↔ data bus (directly on 5V bus)
RS     ← A0
/CS    ← T7./Y0
CS1    ← VCC
R/W    ← /WR
E      ← CLK
TxD    → ESP32 GPIO 22 (via divider: 5V→3.3V)
RxD    ← ESP32 GPIO 21 (3.3V OK, MC6850 VIH=2.0V)
TxCLK  ← 1.8432MHz osc (÷16 = 115200 baud)
RxCLK  ← 1.8432MHz osc
```

## Parts List

| Part | Qty | Cost |
|------|:---:|:----:|
| ESP32 NodeMCU | 1 | ~$5 |
| 74HCT245 | 2 | ~$1 |
| 74HC595 | 2 | ~$1 |
| MC6850 | 1 | ~$3 |
| 74HC574 | 1 | ~$0.50 |
| 74HC245 | 1 | ~$0.50 |
| 74HC138 | 1 | ~$0.50 |
| 1.8432MHz crystal osc | 1 | ~$1 |
| LEDs + 330Ω | 8+8 | ~$1.50 |
| DIP switch (8-pos) | 1 | ~$1 |
| SPDT toggle (PROG/RUN) | 1 | ~$0.50 |
| 40-pin IDC + ribbon | 1 | ~$2 |
| Breadboard | 1 | ~$5 |
| **Total** | | **~$23** |

## Complete System

| Board | Chips | Cost |
|-------|:-----:|:----:|
| CPU board | 27 | ~$21 |
| Trainer board | 8 + ESP32 | ~$23 |
| **Total** | **35 + ESP32** | **~$44** |

## Workflow

```
1. Build CPU board (27 chips)
2. Build trainer board (8 chips + ESP32)
3. Connect via ribbon cable
4. Flip PROG → upload bootloader (one time)
5. Flip RUN → reset → serial upload programs forever
```
