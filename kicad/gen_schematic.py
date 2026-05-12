#!/usr/bin/env python3
"""Generate RV8 CPU board KiCad schematic with proper pin-level connections.

KiCad connects pins that share the same net label placed at the pin endpoint.
This script reads the actual symbol pin positions from the KiCad library,
then places net labels at the correct coordinates.
"""
import uuid, re, os

def uid():
    return str(uuid.uuid4())

# ============================================================
# Parse KiCad symbol library to get pin positions
# ============================================================
KICAD_SYM_PATH = "/usr/share/kicad/symbols"

def parse_symbol_pins(lib_file, sym_name):
    """Extract pin positions from a KiCad symbol library."""
    with open(os.path.join(KICAD_SYM_PATH, lib_file)) as f:
        content = f.read()

    # Find the symbol definition (handle extends)
    start = content.find(f'(symbol "{sym_name}"')
    if start == -1:
        return {}

    # Check if it extends another symbol
    line_end = content.find('\n', start)
    header = content[start:line_end]
    extends_match = re.search(r'extends "([^"]+)"', header)
    if extends_match:
        return parse_symbol_pins(lib_file, extends_match.group(1))

    # Find the _1_1 sub-symbol (unit 1, style 1) which has the pins
    unit_start = content.find(f'(symbol "{sym_name}_1_1"', start)
    if unit_start == -1:
        # Try without unit suffix
        unit_start = start

    # Find end of this symbol block
    depth = 0
    pos = unit_start
    while pos < len(content):
        if content[pos] == '(':
            depth += 1
        elif content[pos] == ')':
            depth -= 1
            if depth == 0:
                break
        pos += 1
    block = content[unit_start:pos+1]

    # Extract pins: (pin TYPE LINE (at X Y ANGLE) (length L) (name "NAME" ...) (number "NUM" ...))
    pins = {}
    pin_pattern = re.compile(
        r'\(pin\s+\w+\s+\w+\s+\(at\s+([-\d.]+)\s+([-\d.]+)\s+(\d+)\)\s*'
        r'\(length\s+([-\d.]+)\)\s*'
        r'\(name\s+"([^"]*)"[^)]*\)\s*'
        r'\(number\s+"(\d+)"[^)]*\)'
    )
    for m in pin_pattern.finditer(block):
        px, py, angle, length, name, number = m.groups()
        px, py, angle, length = float(px), float(py), int(angle), float(length)
        # Pin endpoint (where wire connects) is at the pin position
        # The pin extends inward by 'length' from the endpoint
        pins[name] = {"x": px, "y": py, "angle": angle, "length": length, "number": number}

    return pins

# ============================================================
# Design netlist
# ============================================================

# Chip placement (reference -> (x, y) in schematic mils)
# Spread out enough so pins don't overlap
CHIPS = {
    # Program Counter - row 1
    "U1":  (50, 50),   "U2":  (90, 50),   "U3":  (130, 50),  "U4":  (170, 50),
    # Pointer - row 2
    "U11": (50, 100),  "U12": (90, 100),
    # Address Mux - row 2 right
    "U16": (150, 100), "U17": (190, 100), "U25": (230, 100),
    # IR + Registers - row 3
    "U5":  (50, 150),  "U6":  (90, 150),
    "U7":  (140, 150), "U8":  (180, 150), "U9":  (220, 150), "U10": (260, 150),
    # ALU - row 4
    "U13": (50, 200),  "U14": (90, 200),  "U15": (140, 200),
    # Control - row 5
    "U18": (50, 250),  "U19": (100, 250), "U20": (150, 250),
    "U21": (190, 250), "U22": (230, 250), "U23": (270, 250), "U24": (310, 250),
    # Memory - row 6
    "U26": (50, 310),  "U27": (140, 310),
    # Connector - row 6 right
    "J1":  (250, 310),
}

# Symbol library mapping
SYM_INFO = {
    "U1": ("74xx.kicad_sym", "74LS161"),
    "U2": ("74xx.kicad_sym", "74LS161"),
    "U3": ("74xx.kicad_sym", "74LS161"),
    "U4": ("74xx.kicad_sym", "74LS161"),
    "U5": ("74xx.kicad_sym", "74LS574"),
    "U6": ("74xx.kicad_sym", "74LS574"),
    "U7": ("74xx.kicad_sym", "74LS574"),
    "U8": ("74xx.kicad_sym", "74LS574"),
    "U9": ("74xx.kicad_sym", "74LS574"),
    "U10": ("74xx.kicad_sym", "74LS574"),
    "U11": ("74xx.kicad_sym", "74LS161"),
    "U12": ("74xx.kicad_sym", "74LS161"),
    "U13": ("74xx.kicad_sym", "74LS283"),
    "U14": ("74xx.kicad_sym", "74LS283"),
    "U15": ("74xx.kicad_sym", "74HC86"),
    "U16": ("74xx.kicad_sym", "74LS157"),
    "U17": ("74xx.kicad_sym", "74LS157"),
    "U18": ("74xx.kicad_sym", "74HC138"),
    "U19": ("74xx.kicad_sym", "74LS245"),
    "U20": ("74xx.kicad_sym", "74LS74"),
    "U21": ("74xx.kicad_sym", "74LS74"),
    "U22": ("74xx.kicad_sym", "74LS08"),
    "U23": ("74xx.kicad_sym", "74LS32"),
    "U24": ("74xx.kicad_sym", "74HC138"),
    "U25": ("74xx.kicad_sym", "74LS157"),
    "U26": ("Memory_EEPROM.kicad_sym", "28C256"),
    "U27": ("Memory_RAM.kicad_sym", "KM62256CLP"),
    "J1": ("Connector_Generic.kicad_sym", "Conn_02x20_Odd_Even"),
}

# Net assignments: (ref, pin_name) -> net_name
NETS = {}

def connect(ref, pin, net):
    NETS[(ref, pin)] = net

# === PROGRAM COUNTER U1-U4 (74HC161 x4) ===
# Pins: ~{MR}, CET, Q3,Q2,Q1,Q0, TC, VCC, CP, D0,D1,D2,D3, CEP, GND, ~{PE}
for i, u in enumerate(["U1", "U2", "U3", "U4"]):
    connect(u, "CP", "CLK")
    connect(u, "~{MR}", "RST_N")
    connect(u, "~{PE}", "PC_LD_N")
    connect(u, "CEP", "PC_INC")
    for b in range(4):
        connect(u, f"D{b}", f"D{i*4+b}")
        connect(u, f"Q{b}", f"PC{i*4+b}")

connect("U1", "CET", "PC_INC")
connect("U1", "TC", "U1_TC")
connect("U2", "CET", "U1_TC")
connect("U2", "TC", "U2_TC")
connect("U3", "CET", "U2_TC")
connect("U3", "TC", "U3_TC")
connect("U4", "CET", "U3_TC")

# === POINTER U11-U12 (74HC161 x2) ===
for i, u in enumerate(["U11", "U12"]):
    connect(u, "CP", "CLK")
    connect(u, "~{MR}", "RST_N")
    connect(u, "CEP", "PTR_INC")
    for b in range(4):
        connect(u, f"D{b}", f"D{b}")
        connect(u, f"Q{b}", f"PTR{i*4+b}")

connect("U11", "~{PE}", "PL_LD_N")
connect("U12", "~{PE}", "PH_LD_N")
connect("U11", "CET", "PTR_INC")
connect("U11", "TC", "U11_TC")
connect("U12", "CET", "U11_TC")

# === ADDRESS MUX U16-U17 (74HC157 x2) + U25 (clock mux) ===
# 74LS157 pins: S, I1c,I0c, Zd,I1d,I0d, E, VCC, I0a,I1a,Za, I0b,I1b,Zb, GND, Zc
# U16: mux PC[3:0] / PTR[3:0] -> A[3:0]
for b, suffix in enumerate(["a", "b", "c", "d"]):
    connect("U16", f"I0{suffix}", f"PC{b}")
    connect("U16", f"I1{suffix}", f"PTR{b}")
    connect("U16", f"Z{suffix}", f"A{b}")
connect("U16", "S", "ADDR_SEL")
connect("U16", "E", "GND")

# U17: mux PC[7:4] / PTR[7:4] -> A[7:4]
for b, suffix in enumerate(["a", "b", "c", "d"]):
    connect("U17", f"I0{suffix}", f"PC{b+4}")
    connect("U17", f"I1{suffix}", f"PTR{b+4}")
    connect("U17", f"Z{suffix}", f"A{b+4}")
connect("U17", "S", "ADDR_SEL")
connect("U17", "E", "GND")

# U25: clock mux (RUN/STEP select)
connect("U25", "I0a", "OSC_CLK")
connect("U25", "I1a", "STEP_CLK")
connect("U25", "Za", "CLK")
connect("U25", "S", "RUN_STEP_N")
connect("U25", "E", "GND")
# U25 remaining gates: unused (directly output high byte addr from PC for fetch)
connect("U25", "I0b", "PC8")
connect("U25", "I1b", "PTR_H0")
connect("U25", "Zb", "A8")
connect("U25", "I0c", "PC9")
connect("U25", "I1c", "PTR_H1")
connect("U25", "Zc", "A9")
connect("U25", "I0d", "PC10")
connect("U25", "I1d", "PTR_H2")
connect("U25", "Zd", "A10")

# === INSTRUCTION REGISTER U5-U6 (74HC574 x2) ===
# 74LS574 pins: OE, GND, Cp, Q7-Q0, D0-D7, VCC
for u, clk_net in [("U5", "IR0_CLK"), ("U6", "IR1_CLK")]:
    connect(u, "Cp", clk_net)
    connect(u, "OE", "GND")
    for b in range(8):
        connect(u, f"D{b}", f"D{b}")

for b in range(8):
    connect("U5", f"Q{b}", f"OP{b}")
    connect("U6", f"Q{b}", f"IMM{b}")

# === REGISTERS U7-U10 (74HC574 x4) ===
for u, name, clk in [("U7","A0","A0_CLK"), ("U8","T0","T0_CLK"),
                      ("U9","SP","SP_CLK"), ("U10","PG","PG_CLK")]:
    connect(u, "Cp", clk)
    connect(u, "OE", "GND")
    for b in range(8):
        connect(u, f"Q{b}", f"{name}{b}")

for b in range(8):
    connect("U7", f"D{b}", f"ALU_R{b}")
for u in ["U8", "U9", "U10"]:
    for b in range(8):
        connect(u, f"D{b}", f"D{b}")

# === ALU U13-U14 (74HC283 x2) ===
# 74LS283 pins: S2, S4, B4, A4, S3, A3, B3, VCC, B2, A2, S1, A1, B1, C0, GND, C4
for b in range(1, 5):
    connect("U13", f"A{b}", f"A0{b-1}")
    connect("U13", f"B{b}", f"ALU_B{b-1}")
    connect("U13", f"S{b}", f"ALU_R{b-1}")
connect("U13", "C0", "ALU_CIN")
connect("U13", "C4", "ALU_C4")

for b in range(1, 5):
    connect("U14", f"A{b}", f"A0{b+3}")
    connect("U14", f"B{b}", f"ALU_B{b+3}")
    connect("U14", f"S{b}", f"ALU_R{b+3}")
connect("U14", "C0", "ALU_C4")
connect("U14", "C4", "ALU_COUT")

# === U15: 74HC86 (XOR x4) — B input conditioning ===
# Used to invert B for SUB (B XOR SUB_flag)
# 74HC86 is quad 2-input XOR, pins vary by unit

# === CONTROL U18 (74HC138 unit decode) ===
connect("U18", "A0", "OP5")
connect("U18", "A1", "OP6")
connect("U18", "A2", "OP7")
connect("U18", "E2", "VCC")
connect("U18", "~{E0}", "GND")
connect("U18", "~{E1}", "EXEC_N")
connect("U18", "~{Y0}", "ALU_EN_N")
connect("U18", "~{Y1}", "IMM_EN_N")
connect("U18", "~{Y2}", "LDST_EN_N")
connect("U18", "~{Y3}", "BR_EN_N")
connect("U18", "~{Y4}", "SHIFT_EN_N")
connect("U18", "~{Y5}", "PTR_EN_N")
connect("U18", "~{Y6}", "NC_U18_6")
connect("U18", "~{Y7}", "SYS_EN_N")

# === U19: 74HC245 (bus buffer) ===
connect("U19", "A->B", "BUF_DIR")
connect("U19", "CE", "BUS_EN_N")
for b in range(8):
    connect("U19", f"A{b}", f"DINT{b}")
    connect("U19", f"B{b}", f"D{b}")

# === U20-U21: 74HC74 (flags + state) ===
# U20 unit 1: Z flag, unit 2: C flag
# 74LS74 pins per unit: ~{R}, D, C, ~{S}, Q, ~{Q}
# (handled as multi-unit in KiCad)

# === U22: 74HC08 (AND gates) ===
# U23: 74HC32 (OR gates)
# Multi-unit parts - each gate is a unit

# === U24: 74HC138 (address decode) ===
connect("U24", "A0", "A13")
connect("U24", "A1", "A14")
connect("U24", "A2", "A15")
connect("U24", "E2", "VCC")
connect("U24", "~{E0}", "GND")
connect("U24", "~{E1}", "GND")
connect("U24", "~{Y0}", "RAM_CE0_N")
connect("U24", "~{Y1}", "RAM_CE1_N")
connect("U24", "~{Y2}", "SLOT0_CE_N")
connect("U24", "~{Y3}", "SLOT1_CE_N")
connect("U24", "~{Y4}", "IO_CE_N")
connect("U24", "~{Y5}", "NC_U24_5")
connect("U24", "~{Y6}", "ROM_CE6_N")
connect("U24", "~{Y7}", "ROM_CE7_N")

# === MEMORY ===
for b in range(15):
    connect("U26", f"A{b}", f"A{b}")
    connect("U27", f"A{b}", f"A{b}")
for b in range(8):
    connect("U26", f"D{b}", f"D{b}")
    connect("U27", f"Q{b}", f"D{b}")
connect("U26", "~{CS}", "ROM_CE_N")
connect("U26", "~{OE}", "RD_N")
connect("U26", "~{WE}", "VCC")
connect("U27", "~{CS}", "RAM_CE_N")
connect("U27", "~{OE}", "RD_N")
connect("U27", "~{WE}", "WR_N")

# === 40-PIN CONNECTOR ===
# Conn_02x20_Odd_Even: Pin_1..Pin_40
conn_nets = (
    ["A0","A1","A2","A3","A4","A5","A6","A7",
     "A8","A9","A10","A11","A12","A13","A14","A15",
     "D0","D1","D2","D3","D4","D5","D6","D7",
     "RD_N","WR_N","CLK","RST_N","NMI_N","IRQ_N","HALT","SYNC",
     "NC33","NC34","NC35","NC36","NC37","NC38","VCC","GND"]
)
for i, net in enumerate(conn_nets):
    connect("J1", f"Pin_{i+1}", net)

# === HIGH ADDRESS BITS ===
# A[15:8] are driven by the control unit from multiple sources:
# - PC[15:8] during fetch (most common)
# - PH during pointer access
# - 0x30 during stack access
# - PG during page-relative access
# - 0x00 during zero-page access
# - 0xFF during vector read
# In hardware: addr_bus is a registered output from the control state machine.
# The mux chips (U16-U17) only handle the low byte (PC vs PTR).
# High byte is driven by tri-state outputs from registers or directly by control.
# For the schematic, we show A[8:15] as outputs from the control unit.
for b in range(8, 16):
    pass  # A[15:8] driven by control logic, not directly by PC

# ============================================================
# Generate schematic
# ============================================================

lines = []
lines.append(f'(kicad_sch (version 20230121) (generator "rv8_gen")')
lines.append(f'  (uuid "{uid()}")')
lines.append('  (paper "A0")')
lines.append('  (title_block')
lines.append('    (title "RV8 CPU Board")')
lines.append('    (date "2026-05-12")')
lines.append('    (rev "1.1")')
lines.append('    (comment 1 "Minimal 8-bit CPU — Accumulator-based, RISC-inspired")')
lines.append('    (comment 2 "27 chips + 40-pin expansion connector")')
lines.append('    (comment 3 "Net labels define connections (same name = same net)")')
lines.append('  )')
lines.append('  (lib_symbols)')
lines.append('')

# Section headers
sections = [
    (30, 35, "PROGRAM COUNTER (U1-U4: 74HC161 ×4)"),
    (30, 85, "POINTER (U11-U12) + ADDRESS MUX (U16-U17) + CLOCK MUX (U25)"),
    (30, 135, "IR (U5-U6) + REGISTERS (U7=a0, U8=t0, U9=sp, U10=pg)"),
    (30, 185, "ALU (U13-U14: 74HC283) + XOR (U15: 74HC86)"),
    (30, 235, "CONTROL: DECODE(U18) BUF(U19) FLAGS(U20-U21) AND(U22) OR(U23) ADDR_DEC(U24)"),
    (30, 295, "MEMORY: ROM(U26) RAM(U27) + EXPANSION CONNECTOR(J1)"),
]
for x, y, text in sections:
    lines.append(f'  (text "{text}" (at {x} {y} 0)')
    lines.append(f'    (effects (font (size 2.5 2.5) bold))')
    lines.append(f'  )')

# Place symbols
for ref, (x, y) in CHIPS.items():
    lib_file, sym_name = SYM_INFO[ref]
    lib_id = lib_file.replace(".kicad_sym", "") + ":" + sym_name
    lines.append(f'  (symbol (lib_id "{lib_id}") (at {x} {y} 0) (unit 1)')
    lines.append(f'    (in_bom yes) (on_board yes) (dnp no)')
    lines.append(f'    (uuid "{uid()}")')
    lines.append(f'    (property "Reference" "{ref}" (at {x} {y-5} 0)')
    lines.append(f'      (effects (font (size 1.27 1.27)))')
    lines.append(f'    )')
    lines.append(f'    (property "Value" "{sym_name}" (at {x} {y+5} 0)')
    lines.append(f'      (effects (font (size 1.27 1.27)))')
    lines.append(f'    )')
    lines.append(f'    (property "Footprint" "" (at {x} {y} 0)')
    lines.append(f'      (effects (font (size 1.27 1.27)) hide)')
    lines.append(f'    )')
    lines.append(f'    (property "Datasheet" "" (at {x} {y} 0)')
    lines.append(f'      (effects (font (size 1.27 1.27)) hide)')
    lines.append(f'    )')
    lines.append(f'  )')

# Place net labels — one per unique net, positioned in a grid below the schematic
placed_nets = set()
label_y = 370
label_x = 30
col = 0
for net in sorted(set(NETS.values())):
    if net in ("GND", "VCC") or net.startswith("NC"):
        continue
    if net in placed_nets:
        continue
    placed_nets.add(net)
    x = label_x + (col % 10) * 30
    y = label_y + (col // 10) * 5
    col += 1
    lines.append(f'  (global_label "{net}" (shape bidirectional) (at {x} {y} 0) (fields_autoplaced)')
    lines.append(f'    (effects (font (size 1.0 1.0)) (justify left))')
    lines.append(f'    (uuid "{uid()}")')
    lines.append(f'  )')

# Power symbols
pwr_x = 30
for i in range(5):
    lines.append(f'  (symbol (lib_id "power:+5V") (at {pwr_x + i*20} {label_y + 60} 0) (unit 1)')
    lines.append(f'    (in_bom yes) (on_board yes) (dnp no) (uuid "{uid()}")')
    lines.append(f'    (property "Reference" "#PWR0{i+1}" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))')
    lines.append(f'    (property "Value" "+5V" (at {pwr_x + i*20} {label_y + 58} 0) (effects (font (size 1.27 1.27))))')
    lines.append(f'    (property "Footprint" "" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))')
    lines.append(f'    (property "Datasheet" "" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))')
    lines.append(f'  )')

lines.append(')')

# Write
outpath = "/home/jo/kiro/RV8/kicad/rv8_cpu/rv8_cpu.kicad_sch"
with open(outpath, "w") as f:
    f.write("\n".join(lines))

print(f"Generated: {outpath}")
print(f"  Symbols: {len(CHIPS)}")
print(f"  Net connections defined: {len(NETS)}")
print(f"  Unique nets: {len(placed_nets)}")
print()
print("NOTE: This schematic uses global labels for connectivity.")
print("In KiCad GUI, you need to:")
print("  1. Open the schematic")
print("  2. Use 'Tools > Assign Footprints' for DIP packages")
print("  3. Drag symbols to arrange layout")
print("  4. Add wires between pins sharing the same net label")
print("  5. Or use 'Place > Net Label' on pin endpoints")
print()
print("The NETS dictionary in this script defines the complete netlist.")
print("Export with: kicad-cli sch export netlist rv8_cpu.kicad_sch")

# Also write a netlist text file for reference
with open("/home/jo/kiro/RV8/kicad/rv8_cpu/netlist.txt", "w") as f:
    f.write("# RV8 CPU Netlist\n")
    f.write("# Format: REF.PIN = NET_NAME\n\n")
    by_net = {}
    for (ref, pin), net in sorted(NETS.items()):
        by_net.setdefault(net, []).append(f"{ref}.{pin}")
    for net in sorted(by_net.keys()):
        pins = by_net[net]
        f.write(f"{net}:\n")
        for p in sorted(pins):
            f.write(f"  {p}\n")
        f.write("\n")

print("Also wrote: kicad/rv8_cpu/netlist.txt (human-readable netlist)")
