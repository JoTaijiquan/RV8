#!/usr/bin/env python3
"""Generate RV8 CPU board KiCad schematic with net labels.

Strategy: Place all symbols with net labels on their pins.
KiCad connects pins sharing the same net label name.
This avoids drawing explicit wires (which need exact coordinates).
"""
import uuid

def uid():
    return str(uuid.uuid4())

# KiCad schematic uses net labels to connect pins.
# We place labels near each symbol. Same label name = same net.

ROOT_UUID = uid()

# Chip positions (x, y) — spread out for readability
CHIPS = {
    # Program Counter
    "U1":  (40, 40),   "U2":  (80, 40),   "U3":  (120, 40),  "U4":  (160, 40),
    # Pointer
    "U11": (40, 85),   "U12": (80, 85),
    # Address Mux
    "U16": (140, 85),  "U17": (180, 85),  "U25": (220, 85),
    # IR
    "U5":  (40, 130),  "U6":  (80, 130),
    # Registers
    "U7":  (130, 130), "U8":  (170, 130), "U9":  (210, 130), "U10": (250, 130),
    # ALU
    "U13": (40, 175),  "U14": (80, 175),  "U15": (130, 175),
    # Control
    "U18": (40, 220),  "U19": (90, 220),  "U20": (140, 220),
    "U21": (180, 220), "U22": (220, 220), "U23": (260, 220),
    # Decode
    "U24": (300, 220),
    # Memory
    "U26": (40, 270),  "U27": (130, 270),
    # Connector
    "J1":  (230, 270),
}

# Symbol library references
SYM_LIB = {
    "U1": ("74xx", "74LS161"), "U2": ("74xx", "74LS161"),
    "U3": ("74xx", "74LS161"), "U4": ("74xx", "74LS161"),
    "U5": ("74xx", "74LS574"), "U6": ("74xx", "74LS574"),
    "U7": ("74xx", "74LS574"), "U8": ("74xx", "74LS574"),
    "U9": ("74xx", "74LS574"), "U10": ("74xx", "74LS574"),
    "U11": ("74xx", "74LS161"), "U12": ("74xx", "74LS161"),
    "U13": ("74xx", "74LS283"), "U14": ("74xx", "74LS283"),
    "U15": ("74xx", "74HC86"), "U16": ("74xx", "74LS157"),
    "U17": ("74xx", "74LS157"), "U18": ("74xx", "74HC138"),
    "U19": ("74xx", "74HC245"), "U20": ("74xx", "74HC74"),
    "U21": ("74xx", "74HC74"), "U22": ("74xx", "74LS08"),
    "U23": ("74xx", "74LS32"), "U24": ("74xx", "74HC138"),
    "U25": ("74xx", "74LS157"),
    "U26": ("Memory_EEPROM", "28C256"),
    "U27": ("Memory_RAM", "KM62256CLP"),
    "J1": ("Connector_Generic", "Conn_02x20_Odd_Even"),
}

# Net connections: map (ref, pin_name) -> net_name
# This defines the entire CPU wiring
NETS = {}

def connect(ref, pin, net):
    NETS[(ref, pin)] = net

# === PROGRAM COUNTER U1-U4 ===
for i, u in enumerate(["U1", "U2", "U3", "U4"]):
    connect(u, "CP", "CLK")
    connect(u, "~{MR}", "RST_N")
    connect(u, "~{PE}", "PC_LD_N")
    connect(u, "CEP", "PC_INC")
    # Data inputs from data bus (for loading branch target)
    for b in range(4):
        connect(u, f"D{b}", f"D{i*4+b}")
    # Outputs to address mux
    for b in range(4):
        connect(u, f"Q{b}", f"PC{i*4+b}")

# Carry chain
connect("U1", "CET", "PC_INC")
connect("U1", "TC", "U1_TC")
connect("U2", "CET", "U1_TC")
connect("U2", "TC", "U2_TC")
connect("U3", "CET", "U2_TC")
connect("U3", "TC", "U3_TC")
connect("U4", "CET", "U3_TC")

# === POINTER U11-U12 ===
for i, u in enumerate(["U11", "U12"]):
    connect(u, "CP", "CLK")
    connect(u, "~{MR}", "RST_N")
    connect(u, "CEP", "PTR_INC")
    for b in range(4):
        connect(u, f"D{b}", f"D{b}")  # load from data bus low nibble
        connect(u, f"Q{b}", f"PTR{i*4+b}")

connect("U11", "~{PE}", "PL_LD_N")
connect("U12", "~{PE}", "PH_LD_N")
connect("U11", "CET", "PTR_INC")
connect("U11", "TC", "U11_TC")
connect("U12", "CET", "U11_TC")

# === ADDRESS MUX U16-U17-U25 (74HC157 x3) ===
# U16: low nibble (bits 0-3), U17: bits 4-7, U25: bits 8-11 + 12-15
# 74LS157: S=select, I0x=input A, I1x=input B, Zx=output
for i, u in enumerate(["U16", "U17", "U25"]):
    connect(u, "S", "ADDR_SEL")
    connect(u, "E", "GND")  # always enabled

# U16: mux PC[3:0] vs PTR[3:0] -> A[3:0]
for b, suffix in enumerate(["a", "b", "c", "d"]):
    connect("U16", f"I0{suffix}", f"PC{b}")
    connect("U16", f"I1{suffix}", f"PTR{b}")
    connect("U16", f"Z{suffix}", f"A{b}")

# U17: mux PC[7:4] vs PTR[7:4] -> A[7:4]
for b, suffix in enumerate(["a", "b", "c", "d"]):
    connect("U17", f"I0{suffix}", f"PC{b+4}")
    connect("U17", f"I1{suffix}", f"PTR{b+4}")
    connect("U17", f"Z{suffix}", f"A{b+4}")

# U25: mux PC[11:8]/PC[15:12] vs PH -> A[15:8]
for b, suffix in enumerate(["a", "b", "c", "d"]):
    connect("U25", f"I0{suffix}", f"PC{b+8}")
    connect("U25", f"I1{suffix}", f"PG{b}")  # page register
    connect("U25", f"Z{suffix}", f"A{b+8}")

# === INSTRUCTION REGISTER U5-U6 ===
for u, clk_net in [("U5", "IR0_CLK"), ("U6", "IR1_CLK")]:
    connect(u, "Cp", clk_net)
    connect(u, "OE", "GND")
    for b in range(8):
        connect(u, f"D{b}", f"D{b}")

# U5 outputs = opcode bits
for b in range(8):
    connect("U5", f"Q{b}", f"OP{b}")
# U6 outputs = operand bits
for b in range(8):
    connect("U6", f"Q{b}", f"IMM{b}")

# === REGISTERS U7-U10 ===
# U7=a0, U8=t0, U9=sp, U10=pg
for u, name, clk in [("U7","A0","A0_CLK"), ("U8","T0","T0_CLK"),
                      ("U9","SP","SP_CLK"), ("U10","PG","PG_CLK")]:
    connect(u, "Cp", clk)
    connect(u, "OE", "GND")
    for b in range(8):
        connect(u, f"Q{b}", f"{name}{b}")

# U7 (a0) input from ALU result
for b in range(8):
    connect("U7", f"D{b}", f"ALU_R{b}")
# U8-U10 input from data bus
for u in ["U8", "U9", "U10"]:
    for b in range(8):
        connect(u, f"D{b}", f"D{b}")

# === ALU U13-U14 (74HC283) + U15 (74HC86) ===
# U13: low nibble adder
for b in range(1, 5):
    connect("U13", f"A{b}", f"A0{b-1}")      # a0[3:0]
    connect("U13", f"B{b}", f"ALU_B{b-1}")    # B input (from XOR)
    connect("U13", f"S{b}", f"ALU_R{b-1}")    # result[3:0]
connect("U13", "C0", "ALU_CIN")
connect("U13", "C4", "ALU_C4")

# U14: high nibble adder
for b in range(1, 5):
    connect("U14", f"A{b}", f"A0{b+3}")      # a0[7:4]
    connect("U14", f"B{b}", f"ALU_B{b+3}")    # B input
    connect("U14", f"S{b}", f"ALU_R{b+3}")    # result[7:4]
connect("U14", "C0", "ALU_C4")
connect("U14", "C4", "ALU_COUT")

# U15: 74HC86 XOR gates (B input conditioning)
# 4 gates, each XORs operand bit with SUB signal
# (handled via unit-level connections in KiCad)

# === CONTROL LOGIC ===
# U18: 74HC138 unit decode
connect("U18", "A0", "OP5")
connect("U18", "A1", "OP6")
connect("U18", "A2", "OP7")
connect("U18", "E2", "VCC")
connect("U18", "~{E0}", "GND")
connect("U18", "~{E1}", "EXEC_N")

# U24: 74HC138 address decode
connect("U24", "A0", "A13")
connect("U24", "A1", "A14")
connect("U24", "A2", "A15")
connect("U24", "E2", "VCC")
connect("U24", "~{E0}", "GND")
connect("U24", "~{E1}", "GND")
connect("U24", "~{Y0}", "RAM_CE0_N")
connect("U24", "~{Y4}", "IO_CE_N")
connect("U24", "~{Y6}", "ROM_CE6_N")
connect("U24", "~{Y7}", "ROM_CE7_N")

# U19: 74HC245 bus buffer
connect("U19", "A->B", "RD_N")
connect("U19", "CE", "BUS_EN_N")
for b in range(8):
    connect("U19", f"A{b}", f"DINT{b}")
    connect("U19", f"B{b}", f"D{b}")

# U20: 74HC74 flags (Z, C)
# Unit 1: Z flag
connect("U20", "D", "ALU_ZERO")   # unit 1
connect("U20", "C", "FLAGS_CLK")  # unit 1
connect("U20", "Q", "FLAG_Z")     # unit 1
connect("U20", "~{R}", "RST_N")   # unit 1

# U22: 74HC08 AND gates (clock gating)
# U23: 74HC32 OR gates (signal combining)

# === MEMORY ===
# U26: AT28C256 ROM
for b in range(15):
    connect("U26", f"A{b}", f"A{b}")
for b in range(8):
    connect("U26", f"D{b}", f"D{b}")
connect("U26", "~{CS}", "ROM_CE_N")
connect("U26", "~{OE}", "RD_N")
connect("U26", "~{WE}", "VCC")  # ROM write disabled

# U27: 62256 RAM
for b in range(15):
    connect("U27", f"A{b}", f"A{b}")
for b in range(8):
    connect("U27", f"Q{b}", f"D{b}")
connect("U27", "~{CS}", "RAM_CE_N")
connect("U27", "~{OE}", "RD_N")
connect("U27", "~{WE}", "WR_N")

# === 40-PIN CONNECTOR J1 ===
# Pins 1-16: A0-A15, 17-24: D0-D7, 25-40: control+power
conn_pins = (
    [f"A{i}" for i in range(16)] +
    [f"D{i}" for i in range(8)] +
    ["RD_N", "WR_N", "CLK", "RST_N", "NMI_N", "IRQ_N", "HALT", "SYNC",
     "NC", "NC", "NC", "NC", "NC", "NC", "VCC", "GND"]
)
for i, net in enumerate(conn_pins):
    pin_num = i + 1
    connect("J1", f"Pin_{pin_num}", net)

# ============================================================
# Generate the .kicad_sch file
# ============================================================

lines = []
lines.append(f'(kicad_sch (version 20230121) (generator "rv8_gen")')
lines.append(f'  (uuid "{ROOT_UUID}")')
lines.append('  (paper "A1")')
lines.append('  (title_block')
lines.append('    (title "RV8 CPU Board")')
lines.append('    (date "2026-05-12")')
lines.append('    (rev "1.0")')
lines.append('    (comment 1 "Minimal 8-bit CPU — Accumulator-based, RISC-inspired")')
lines.append('    (comment 2 "27 chips + 40-pin expansion connector")')
lines.append('  )')
lines.append('')
lines.append('  (lib_symbols)')
lines.append('')

# Add text annotations for sections
sections = [
    (30, 30, "PROGRAM COUNTER (U1-U4)"),
    (30, 75, "POINTER (U11-U12) + ADDRESS MUX (U16-U17-U25)"),
    (30, 120, "IR (U5-U6) + REGISTERS (U7-U10)"),
    (30, 165, "ALU (U13-U15)"),
    (30, 210, "CONTROL (U18-U23) + DECODE (U24)"),
    (30, 260, "MEMORY (U26-U27) + CONNECTOR (J1)"),
]
for x, y, text in sections:
    lines.append(f'  (text "{text}" (at {x} {y} 0)')
    lines.append(f'    (effects (font (size 3.0 3.0) bold))')
    lines.append(f'  )')

# Add symbols
for ref, (x, y) in CHIPS.items():
    lib, name = SYM_LIB[ref]
    lines.append(f'  (symbol (lib_id "{lib}:{name}") (at {x} {y} 0) (unit 1)')
    lines.append(f'    (in_bom yes) (on_board yes) (dnp no)')
    lines.append(f'    (uuid "{uid()}")')
    lines.append(f'    (property "Reference" "{ref}" (at {x} {y-4} 0)')
    lines.append(f'      (effects (font (size 1.27 1.27)))')
    lines.append(f'    )')
    lines.append(f'    (property "Value" "{name}" (at {x} {y+4} 0)')
    lines.append(f'      (effects (font (size 1.27 1.27)))')
    lines.append(f'    )')
    lines.append(f'    (property "Footprint" "" (at {x} {y} 0)')
    lines.append(f'      (effects (font (size 1.27 1.27)) hide)')
    lines.append(f'    )')
    lines.append(f'    (property "Datasheet" "" (at {x} {y} 0)')
    lines.append(f'      (effects (font (size 1.27 1.27)) hide)')
    lines.append(f'    )')
    lines.append(f'  )')

# Add net labels (placed near symbols, grouped by net)
# Collect unique nets and place one global label per net
placed_nets = set()
label_y = 300  # place labels below the schematic
label_x = 30
col = 0
for (ref, pin), net in sorted(NETS.items()):
    if net in ("GND", "VCC") or net in placed_nets:
        continue
    placed_nets.add(net)
    x = label_x + (col % 8) * 35
    y = label_y + (col // 8) * 5
    col += 1
    shape = "bidirectional"
    if net.startswith("A") and net[1:].isdigit():
        shape = "output"
    elif net.startswith("D") and net[1:].isdigit():
        shape = "bidirectional"
    elif "CLK" in net:
        shape = "input"
    lines.append(f'  (global_label "{net}" (shape {shape}) (at {x} {y} 0) (fields_autoplaced)')
    lines.append(f'    (effects (font (size 1.0 1.0)) (justify left))')
    lines.append(f'    (uuid "{uid()}")')
    lines.append(f'  )')

# Add power symbols
for ref in CHIPS:
    x, y = CHIPS[ref]
    # VCC
    lines.append(f'  (symbol (lib_id "power:+5V") (at {x+5} {y-8} 0) (unit 1)')
    lines.append(f'    (in_bom yes) (on_board yes) (dnp no)')
    lines.append(f'    (uuid "{uid()}")')
    lines.append(f'    (property "Reference" "#PWR?" (at {x+5} {y-8} 0)')
    lines.append(f'      (effects (font (size 1.27 1.27)) hide)')
    lines.append(f'    )')
    lines.append(f'    (property "Value" "+5V" (at {x+5} {y-10} 0)')
    lines.append(f'      (effects (font (size 1.27 1.27)))')
    lines.append(f'    )')
    lines.append(f'    (property "Footprint" "" (at {x+5} {y-8} 0)')
    lines.append(f'      (effects (font (size 1.27 1.27)) hide)')
    lines.append(f'    )')
    lines.append(f'    (property "Datasheet" "" (at {x+5} {y-8} 0)')
    lines.append(f'      (effects (font (size 1.27 1.27)) hide)')
    lines.append(f'    )')
    lines.append(f'  )')
    # GND
    lines.append(f'  (symbol (lib_id "power:GND") (at {x+5} {y+8} 0) (unit 1)')
    lines.append(f'    (in_bom yes) (on_board yes) (dnp no)')
    lines.append(f'    (uuid "{uid()}")')
    lines.append(f'    (property "Reference" "#PWR?" (at {x+5} {y+8} 0)')
    lines.append(f'      (effects (font (size 1.27 1.27)) hide)')
    lines.append(f'    )')
    lines.append(f'    (property "Value" "GND" (at {x+5} {y+10} 0)')
    lines.append(f'      (effects (font (size 1.27 1.27)))')
    lines.append(f'    )')
    lines.append(f'    (property "Footprint" "" (at {x+5} {y+8} 0)')
    lines.append(f'      (effects (font (size 1.27 1.27)) hide)')
    lines.append(f'    )')
    lines.append(f'    (property "Datasheet" "" (at {x+5} {y+8} 0)')
    lines.append(f'      (effects (font (size 1.27 1.27)) hide)')
    lines.append(f'    )')
    lines.append(f'  )')

lines.append(')')

output = "\n".join(lines)
with open("/home/jo/kiro/RV8/kicad/rv8_cpu/rv8_cpu.kicad_sch", "w") as f:
    f.write(output)

print(f"Generated schematic: {len(lines)} lines")
print(f"Chips: {len(CHIPS)}")
print(f"Net connections: {len(NETS)}")
print(f"Unique nets: {len(placed_nets)}")
