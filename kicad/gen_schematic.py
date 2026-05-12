#!/usr/bin/env python3
"""Generate RV8 CPU KiCad schematic with wires and proper layout.

Each chip is placed with space around it. Short wires connect pins to
net labels. Same net label name = same electrical connection.
"""
import re, uuid, os

def uid():
    return str(uuid.uuid4())

KICAD_SYM = "/usr/share/kicad/symbols"

def get_pins(lib_file, sym_name):
    with open(os.path.join(KICAD_SYM, lib_file)) as f:
        content = f.read()
    start = content.find(f'(symbol "{sym_name}"')
    if start == -1: return {}
    line_end = content.find('\n', start)
    ext = re.search(r'extends "([^"]+)"', content[start:line_end])
    if ext: return get_pins(lib_file, ext.group(1))
    next_sym = content.find('\n  (symbol "', start + 20)
    block = content[start:next_sym if next_sym != -1 else len(content)]
    pins = {}
    for m in re.finditer(r'\(pin\s+(\w+)\s+\w+\s+\(at\s+([-\d.]+)\s+([-\d.]+)\s+(\d+)\)\s*\(length\s+([-\d.]+)\)\s*\(name\s+"([^"]*)"', block):
        ptype, x, y, angle, length, name = m[1], float(m[2]), float(m[3]), int(m[4]), float(m[5]), m[6].strip()
        pins[name] = (x, y, angle, ptype)
    return pins

PIN_CACHE = {}
def pins_for(lib_file, sym_name):
    key = (lib_file, sym_name)
    if key not in PIN_CACHE:
        PIN_CACHE[key] = get_pins(lib_file, sym_name)
    return PIN_CACHE[key]

SYM_INFO = {
    "U1": ("74xx.kicad_sym", "74LS161"), "U2": ("74xx.kicad_sym", "74LS161"),
    "U3": ("74xx.kicad_sym", "74LS161"), "U4": ("74xx.kicad_sym", "74LS161"),
    "U5": ("74xx.kicad_sym", "74LS574"), "U6": ("74xx.kicad_sym", "74LS574"),
    "U7": ("74xx.kicad_sym", "74LS574"), "U8": ("74xx.kicad_sym", "74LS574"),
    "U9": ("74xx.kicad_sym", "74LS574"), "U10": ("74xx.kicad_sym", "74LS574"),
    "U11": ("74xx.kicad_sym", "74LS161"), "U12": ("74xx.kicad_sym", "74LS161"),
    "U13": ("74xx.kicad_sym", "74LS283"), "U14": ("74xx.kicad_sym", "74LS283"),
    "U15": ("74xx.kicad_sym", "74HC86"), "U16": ("74xx.kicad_sym", "74LS157"),
    "U17": ("74xx.kicad_sym", "74LS157"), "U18": ("74xx.kicad_sym", "74HC138"),
    "U19": ("74xx.kicad_sym", "74LS245"), "U20": ("74xx.kicad_sym", "74LS74"),
    "U21": ("74xx.kicad_sym", "74LS74"), "U22": ("74xx.kicad_sym", "74LS08"),
    "U23": ("74xx.kicad_sym", "74LS32"), "U24": ("74xx.kicad_sym", "74HC138"),
    "U25": ("74xx.kicad_sym", "74LS157"),
    "U26": ("Memory_EEPROM.kicad_sym", "28C256"),
    "U27": ("Memory_RAM.kicad_sym", "KM62256CLP"),
    "J1": ("Connector_Generic.kicad_sym", "Conn_02x20_Odd_Even"),
}

# Layout: generous spacing (mm), organized by function
# 74HC161 is about 25mm wide, 40mm tall in KiCad
CHIPS = {
    # Row 1: Program Counter
    "U1": (80, 60), "U2": (130, 60), "U3": (180, 60), "U4": (230, 60),
    # Row 2: Pointer + Address Mux + Clock Mux
    "U11": (80, 120), "U12": (130, 120),
    "U16": (195, 120), "U17": (245, 120), "U25": (295, 120),
    # Row 3: IR + Registers
    "U5": (80, 185), "U6": (130, 185),
    "U7": (195, 185), "U8": (245, 185), "U9": (295, 185), "U10": (345, 185),
    # Row 4: ALU
    "U13": (80, 250), "U14": (130, 250), "U15": (195, 250),
    # Row 5: Control + Decode
    "U18": (80, 315), "U19": (140, 315), "U20": (200, 315),
    "U21": (250, 315), "U22": (300, 315), "U23": (350, 315), "U24": (400, 315),
    # Row 6: Memory + Connector
    "U26": (80, 395), "U27": (180, 395), "J1": (310, 395),
}

# Net connections
NETS = {}
def connect(ref, pin, net):
    NETS[(ref, pin)] = net

# === All connections (same as before) ===
for i, u in enumerate(["U1","U2","U3","U4"]):
    connect(u,"CP","CLK"); connect(u,"~{MR}","RST_N"); connect(u,"~{PE}","PC_LD_N"); connect(u,"CEP","PC_INC")
    for b in range(4): connect(u,f"D{b}",f"D{i*4+b}"); connect(u,f"Q{b}",f"PC{i*4+b}")
connect("U1","CET","PC_INC"); connect("U1","TC","U1_TC")
connect("U2","CET","U1_TC"); connect("U2","TC","U2_TC")
connect("U3","CET","U2_TC"); connect("U3","TC","U3_TC"); connect("U4","CET","U3_TC")

for i, u in enumerate(["U11","U12"]):
    connect(u,"CP","CLK"); connect(u,"~{MR}","RST_N"); connect(u,"CEP","PTR_INC")
    for b in range(4): connect(u,f"D{b}",f"D{b}"); connect(u,f"Q{b}",f"PTR{i*4+b}")
connect("U11","~{PE}","PL_LD_N"); connect("U12","~{PE}","PH_LD_N")
connect("U11","CET","PTR_INC"); connect("U11","TC","U11_TC"); connect("U12","CET","U11_TC")

for b,s in enumerate("abcd"):
    connect("U16",f"I0{s}",f"PC{b}"); connect("U16",f"I1{s}",f"PTR{b}"); connect("U16",f"Z{s}",f"A{b}")
    connect("U17",f"I0{s}",f"PC{b+4}"); connect("U17",f"I1{s}",f"PTR{b+4}"); connect("U17",f"Z{s}",f"A{b+4}")
connect("U16","S","ADDR_SEL"); connect("U16","E","GND"); connect("U17","S","ADDR_SEL"); connect("U17","E","GND")
connect("U25","I0a","OSC"); connect("U25","I1a","STEP"); connect("U25","Za","CLK")
connect("U25","S","RUN_N"); connect("U25","E","GND")
for s in "bcd": connect("U25",f"I0{s}","GND"); connect("U25",f"I1{s}","GND")

for u,clk in [("U5","IR0_CLK"),("U6","IR1_CLK")]:
    connect(u,"Cp",clk); connect(u,"OE","GND")
    for b in range(8): connect(u,f"D{b}",f"D{b}")
for b in range(8): connect("U5",f"Q{b}",f"OP{b}"); connect("U6",f"Q{b}",f"IMM{b}")

for u,nm,clk in [("U7","A0","A0_CLK"),("U8","T0","T0_CLK"),("U9","SP","SP_CLK"),("U10","PG","PG_CLK")]:
    connect(u,"Cp",clk); connect(u,"OE","GND")
    for b in range(8): connect(u,f"Q{b}",f"{nm}{b}")
for b in range(8): connect("U7",f"D{b}",f"ALU_R{b}")
for u in ["U8","U9","U10"]:
    for b in range(8): connect(u,f"D{b}",f"D{b}")

for b in range(1,5):
    connect("U13",f"A{b}",f"A0{b-1}"); connect("U13",f"B{b}",f"ALU_B{b-1}"); connect("U13",f"S{b}",f"ALU_R{b-1}")
    connect("U14",f"A{b}",f"A0{b+3}"); connect("U14",f"B{b}",f"ALU_B{b+3}"); connect("U14",f"S{b}",f"ALU_R{b+3}")
connect("U13","C0","SUB"); connect("U13","C4","ALU_C4"); connect("U14","C0","ALU_C4"); connect("U14","C4","COUT")

connect("U18","A0","OP5"); connect("U18","A1","OP6"); connect("U18","A2","OP7")
connect("U18","E2","VCC"); connect("U18","~{E0}","GND"); connect("U18","~{E1}","EXEC_N")
for i,n in enumerate(["ALU_N","IMM_N","LDST_N","BR_N","SH_N","PTR_N","x","SYS_N"]):
    connect("U18",f"~{{Y{i}}}",n)

connect("U19","A->B","DIR"); connect("U19","CE","BUF_N")
for b in range(8): connect("U19",f"A{b}",f"DINT{b}"); connect("U19",f"B{b}",f"D{b}")

connect("U24","A0","A13"); connect("U24","A1","A14"); connect("U24","A2","A15")
connect("U24","E2","VCC"); connect("U24","~{E0}","GND"); connect("U24","~{E1}","GND")
for i,n in enumerate(["RAM0_N","RAM1_N","SL0_N","SL1_N","IO_N","x","ROM6_N","ROM7_N"]):
    connect("U24",f"~{{Y{i}}}",n)

for b in range(15): connect("U26",f"A{b}",f"A{b}"); connect("U27",f"A{b}",f"A{b}")
for b in range(8): connect("U26",f"D{b}",f"D{b}"); connect("U27",f"Q{b}",f"D{b}")
connect("U26","~{CS}","ROM_N"); connect("U26","~{OE}","RD_N"); connect("U26","~{WE}","VCC")
connect("U27","~{CS}","RAM_N"); connect("U27","~{OE}","RD_N"); connect("U27","~{WE}","WR_N")

conn = ["A0","A1","A2","A3","A4","A5","A6","A7","A8","A9","A10","A11","A12","A13","A14","A15",
        "D0","D1","D2","D3","D4","D5","D6","D7","RD_N","WR_N","CLK","RST_N","NMI_N","IRQ_N","HALT","SYNC",
        "x","x","x","x","x","x","VCC","GND"]
for i,n in enumerate(conn): connect("J1",f"Pin_{i+1}",n)

# === Generate schematic ===
lines = []
lines.append(f'(kicad_sch (version 20230121) (generator "rv8_gen")')
lines.append(f'  (uuid "{uid()}")')
lines.append('  (paper "A0")')
lines.append('  (title_block')
lines.append('    (title "RV8 CPU Board — Chip Wiring Diagram")')
lines.append('    (date "2026-05-12")')
lines.append('    (rev "2.0")')
lines.append('    (comment 1 "27 chips, 40-pin connector")')
lines.append('    (comment 2 "Same net label = same wire")')
lines.append('  )')
lines.append('  (lib_symbols)')
lines.append('')

# Section labels
sections = [
    (30, 40, "PROGRAM COUNTER"),
    (30, 100, "POINTER + ADDRESS MUX + CLOCK"),
    (30, 165, "INSTRUCTION REGISTER + REGISTERS"),
    (30, 230, "ALU"),
    (30, 295, "CONTROL + ADDRESS DECODE"),
    (30, 375, "ROM + RAM + CONNECTOR"),
]
for x, y, text in sections:
    lines.append(f'  (text "{text}" (at {x} {y} 0)')
    lines.append(f'    (effects (font (size 3.0 3.0) bold)))')

# Place symbols
for ref, (sx, sy) in CHIPS.items():
    lib_file, sym_name = SYM_INFO[ref]
    lib_id = lib_file.replace(".kicad_sym", "") + ":" + sym_name
    lines.append(f'  (symbol (lib_id "{lib_id}") (at {sx} {sy} 0) (unit 1)')
    lines.append(f'    (in_bom yes) (on_board yes) (dnp no)')
    lines.append(f'    (uuid "{uid()}")')
    lines.append(f'    (property "Reference" "{ref}" (at {sx} {sy-5} 0)')
    lines.append(f'      (effects (font (size 1.5 1.5))))')
    lines.append(f'    (property "Value" "{sym_name}" (at {sx} {sy+5} 0)')
    lines.append(f'      (effects (font (size 1.27 1.27))))')
    lines.append(f'    (property "Footprint" "" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))')
    lines.append(f'    (property "Datasheet" "" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))')
    lines.append(f'  )')

# For each pin with a net: draw a short wire stub + place label at end
WIRE_LEN = 5.08  # length of wire stub from pin (2 grid units)

for (ref, pin_name), net in NETS.items():
    if net == "x": continue
    lib_file, sym_name = SYM_INFO[ref]
    pins = pins_for(lib_file, sym_name)
    if pin_name not in pins: continue

    px, py, angle, ptype = pins[pin_name]
    sx, sy = CHIPS[ref]
    # Pin endpoint absolute position
    pin_x = sx + px
    pin_y = sy + py

    # Wire goes outward from pin by WIRE_LEN
    # angle 0 = pin on left side, wire goes left
    # angle 180 = pin on right side, wire goes right
    # angle 90 = pin on bottom, wire goes down
    # angle 270 = pin on top, wire goes up
    if angle == 0:
        wx, wy = pin_x - WIRE_LEN, pin_y
        label_angle = 180
    elif angle == 180:
        wx, wy = pin_x + WIRE_LEN, pin_y
        label_angle = 0
    elif angle == 90:
        wx, wy = pin_x, pin_y + WIRE_LEN
        label_angle = 270
    else:  # 270
        wx, wy = pin_x, pin_y - WIRE_LEN
        label_angle = 90

    # Draw wire from pin to label position
    lines.append(f'  (wire (pts (xy {pin_x:.2f} {pin_y:.2f}) (xy {wx:.2f} {wy:.2f}))')
    lines.append(f'    (stroke (width 0) (type solid))')
    lines.append(f'    (uuid "{uid()}"))')

    # Place net label at wire end
    if net in ("VCC", "GND"):
        # Use power symbols
        sym = "+5V" if net == "VCC" else "GND"
        lines.append(f'  (symbol (lib_id "power:{sym}") (at {wx:.2f} {wy:.2f} 0) (unit 1)')
        lines.append(f'    (in_bom yes) (on_board yes) (dnp no) (uuid "{uid()}")')
        lines.append(f'    (property "Reference" "#PWR?" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))')
        lines.append(f'    (property "Value" "{sym}" (at {wx:.2f} {wy + (2 if net=="GND" else -2):.2f} 0) (effects (font (size 1.0 1.0))))')
        lines.append(f'    (property "Footprint" "" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))')
        lines.append(f'    (property "Datasheet" "" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))')
        lines.append(f'  )')
    else:
        lines.append(f'  (label "{net}" (at {wx:.2f} {wy:.2f} {label_angle}) (fields_autoplaced)')
        lines.append(f'    (effects (font (size 1.27 1.27)) (justify left))')
        lines.append(f'    (uuid "{uid()}"))')

lines.append(')')

outpath = "/home/jo/kiro/RV8/kicad/rv8_cpu/rv8_cpu.kicad_sch"
with open(outpath, "w") as f:
    f.write("\n".join(lines))

print(f"Generated: {outpath}")
print(f"  Chips: {len(CHIPS)}")
print(f"  Wires: {sum(1 for (r,p),n in NETS.items() if n != 'x' and p in pins_for(*SYM_INFO[r]))}")
print(f"  Labels: {sum(1 for (r,p),n in NETS.items() if n not in ('x','VCC','GND') and p in pins_for(*SYM_INFO[r]))}")
