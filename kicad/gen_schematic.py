#!/usr/bin/env python3
"""Generate RV8 CPU KiCad schematic with labels at pin endpoints."""
import re, uuid, os

def uid():
    return str(uuid.uuid4())

# ============================================================
# Parse pin positions from KiCad library
# ============================================================
KICAD_SYM = "/usr/share/kicad/symbols"

def get_pins(lib_file, sym_name):
    """Get pin name -> (x, y, angle) relative to symbol origin."""
    with open(os.path.join(KICAD_SYM, lib_file)) as f:
        content = f.read()
    # Handle extends
    start = content.find(f'(symbol "{sym_name}"')
    if start == -1:
        return {}
    line_end = content.find('\n', start)
    ext = re.search(r'extends "([^"]+)"', content[start:line_end])
    if ext:
        return get_pins(lib_file, ext.group(1))
    next_sym = content.find('\n  (symbol "', start + 20)
    block = content[start:next_sym if next_sym != -1 else len(content)]
    pins = {}
    for m in re.finditer(r'\(pin\s+\w+\s+\w+\s+\(at\s+([-\d.]+)\s+([-\d.]+)\s+(\d+)\)\s*\(length\s+([-\d.]+)\)\s*\(name\s+"([^"]*)"', block):
        x, y, angle, length, name = float(m[1]), float(m[2]), int(m[3]), float(m[4]), m[5].strip()
        pins[name] = (x, y, angle)
    return pins

# Cache pin data
PIN_CACHE = {}
def pins_for(lib_file, sym_name):
    key = (lib_file, sym_name)
    if key not in PIN_CACHE:
        PIN_CACHE[key] = get_pins(lib_file, sym_name)
    return PIN_CACHE[key]

# ============================================================
# Chip definitions
# ============================================================
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

# Placement: spread chips with enough room for labels
CHIPS = {
    "U1": (60, 50), "U2": (110, 50), "U3": (160, 50), "U4": (210, 50),
    "U11": (60, 110), "U12": (110, 110),
    "U16": (170, 110), "U17": (220, 110), "U25": (270, 110),
    "U5": (60, 170), "U6": (110, 170),
    "U7": (170, 170), "U8": (220, 170), "U9": (270, 170), "U10": (320, 170),
    "U13": (60, 230), "U14": (110, 230), "U15": (170, 230),
    "U18": (60, 300), "U19": (120, 300), "U20": (180, 300),
    "U21": (230, 300), "U22": (280, 300), "U23": (330, 300), "U24": (380, 300),
    "U26": (60, 380), "U27": (170, 380), "J1": (300, 380),
}

# ============================================================
# Net connections (same as before)
# ============================================================
NETS = {}
def connect(ref, pin, net):
    NETS[(ref, pin)] = net

# PC U1-U4
for i, u in enumerate(["U1", "U2", "U3", "U4"]):
    connect(u, "CP", "CLK"); connect(u, "~{MR}", "RST_N")
    connect(u, "~{PE}", "PC_LD_N"); connect(u, "CEP", "PC_INC")
    for b in range(4):
        connect(u, f"D{b}", f"D{i*4+b}")
        connect(u, f"Q{b}", f"PC{i*4+b}")
connect("U1","CET","PC_INC"); connect("U1","TC","U1_TC")
connect("U2","CET","U1_TC"); connect("U2","TC","U2_TC")
connect("U3","CET","U2_TC"); connect("U3","TC","U3_TC")
connect("U4","CET","U3_TC")

# Pointer U11-U12
for i, u in enumerate(["U11", "U12"]):
    connect(u, "CP", "CLK"); connect(u, "~{MR}", "RST_N")
    connect(u, "CEP", "PTR_INC")
    for b in range(4):
        connect(u, f"D{b}", f"D{b}")
        connect(u, f"Q{b}", f"PTR{i*4+b}")
connect("U11","~{PE}","PL_LD_N"); connect("U12","~{PE}","PH_LD_N")
connect("U11","CET","PTR_INC"); connect("U11","TC","U11_TC")
connect("U12","CET","U11_TC")

# Address Mux U16-U17
for b, s in enumerate(["a","b","c","d"]):
    connect("U16",f"I0{s}",f"PC{b}"); connect("U16",f"I1{s}",f"PTR{b}"); connect("U16",f"Z{s}",f"A{b}")
    connect("U17",f"I0{s}",f"PC{b+4}"); connect("U17",f"I1{s}",f"PTR{b+4}"); connect("U17",f"Z{s}",f"A{b+4}")
connect("U16","S","ADDR_SEL"); connect("U16","E","GND")
connect("U17","S","ADDR_SEL"); connect("U17","E","GND")

# Clock Mux U25
connect("U25","I0a","OSC_CLK"); connect("U25","I1a","STEP_CLK"); connect("U25","Za","CLK")
connect("U25","S","RUN_N"); connect("U25","E","GND")
for s in ["b","c","d"]:
    connect("U25",f"I0{s}","GND"); connect("U25",f"I1{s}","GND")

# IR U5-U6
for u, clk in [("U5","IR0_CLK"),("U6","IR1_CLK")]:
    connect(u,"Cp",clk); connect(u,"OE","GND")
    for b in range(8): connect(u,f"D{b}",f"D{b}")
for b in range(8):
    connect("U5",f"Q{b}",f"OP{b}"); connect("U6",f"Q{b}",f"IMM{b}")

# Registers U7-U10
for u,nm,clk in [("U7","A0","A0_CLK"),("U8","T0","T0_CLK"),("U9","SP","SP_CLK"),("U10","PG","PG_CLK")]:
    connect(u,"Cp",clk); connect(u,"OE","GND")
    for b in range(8): connect(u,f"Q{b}",f"{nm}{b}")
for b in range(8): connect("U7",f"D{b}",f"ALU_R{b}")
for u in ["U8","U9","U10"]:
    for b in range(8): connect(u,f"D{b}",f"D{b}")

# ALU U13-U14
for b in range(1,5):
    connect("U13",f"A{b}",f"A0{b-1}"); connect("U13",f"B{b}",f"ALU_B{b-1}"); connect("U13",f"S{b}",f"ALU_R{b-1}")
    connect("U14",f"A{b}",f"A0{b+3}"); connect("U14",f"B{b}",f"ALU_B{b+3}"); connect("U14",f"S{b}",f"ALU_R{b+3}")
connect("U13","C0","ALU_CIN"); connect("U13","C4","ALU_C4")
connect("U14","C0","ALU_C4"); connect("U14","C4","ALU_COUT")

# Control U18
connect("U18","A0","OP5"); connect("U18","A1","OP6"); connect("U18","A2","OP7")
connect("U18","E2","VCC"); connect("U18","~{E0}","GND"); connect("U18","~{E1}","EXEC_N")
for i,n in enumerate(["ALU_N","IMM_N","LDST_N","BR_N","SHIFT_N","PTR_N","NC6","SYS_N"]):
    connect("U18",f"~{{Y{i}}}",n)

# Bus buffer U19
connect("U19","A->B","BUF_DIR"); connect("U19","CE","BUS_EN_N")
for b in range(8):
    connect("U19",f"A{b}",f"DINT{b}"); connect("U19",f"B{b}",f"D{b}")

# Address decode U24
connect("U24","A0","A13"); connect("U24","A1","A14"); connect("U24","A2","A15")
connect("U24","E2","VCC"); connect("U24","~{E0}","GND"); connect("U24","~{E1}","GND")
for i,n in enumerate(["RAM0_N","RAM1_N","SLOT0_N","SLOT1_N","IO_N","NC5","ROM6_N","ROM7_N"]):
    connect("U24",f"~{{Y{i}}}",n)

# Memory U26 (ROM), U27 (RAM)
for b in range(15):
    connect("U26",f"A{b}",f"A{b}"); connect("U27",f"A{b}",f"A{b}")
for b in range(8):
    connect("U26",f"D{b}",f"D{b}"); connect("U27",f"Q{b}",f"D{b}")
connect("U26","~{CS}","ROM_CE_N"); connect("U26","~{OE}","RD_N"); connect("U26","~{WE}","VCC")
connect("U27","~{CS}","RAM_CE_N"); connect("U27","~{OE}","RD_N"); connect("U27","~{WE}","WR_N")

# Connector J1
conn_nets = ["A0","A1","A2","A3","A4","A5","A6","A7","A8","A9","A10","A11","A12","A13","A14","A15",
             "D0","D1","D2","D3","D4","D5","D6","D7",
             "RD_N","WR_N","CLK","RST_N","NMI_N","IRQ_N","HALT","SYNC",
             "NC33","NC34","NC35","NC36","NC37","NC38","VCC","GND"]
for i, net in enumerate(conn_nets):
    connect("J1", f"Pin_{i+1}", net)

# ============================================================
# Generate schematic with labels at pin endpoints
# ============================================================
lines = []
lines.append(f'(kicad_sch (version 20230121) (generator "rv8_gen")')
lines.append(f'  (uuid "{uid()}")')
lines.append('  (paper "A0")')
lines.append('  (title_block')
lines.append('    (title "RV8 CPU Board")')
lines.append('    (date "2026-05-12")')
lines.append('    (rev "1.2")')
lines.append('    (comment 1 "27 chips — Accumulator-based, RISC-inspired")')
lines.append('  )')
lines.append('  (lib_symbols)')
lines.append('')

# Place symbols
for ref, (sx, sy) in CHIPS.items():
    lib_file, sym_name = SYM_INFO[ref]
    lib_id = lib_file.replace(".kicad_sym", "") + ":" + sym_name
    lines.append(f'  (symbol (lib_id "{lib_id}") (at {sx} {sy} 0) (unit 1)')
    lines.append(f'    (in_bom yes) (on_board yes) (dnp no)')
    lines.append(f'    (uuid "{uid()}")')
    lines.append(f'    (property "Reference" "{ref}" (at {sx} {sy-3} 0)')
    lines.append(f'      (effects (font (size 1.27 1.27))))')
    lines.append(f'    (property "Value" "{sym_name}" (at {sx} {sy+3} 0)')
    lines.append(f'      (effects (font (size 1.0 1.0))))')
    lines.append(f'    (property "Footprint" "" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))')
    lines.append(f'    (property "Datasheet" "" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))')
    lines.append(f'  )')

# Place net labels at pin endpoints
for (ref, pin_name), net in NETS.items():
    if net.startswith("NC") or net == "GND" or net == "VCC":
        continue
    lib_file, sym_name = SYM_INFO[ref]
    pins = pins_for(lib_file, sym_name)
    if pin_name not in pins:
        continue
    px, py, angle = pins[pin_name]
    sx, sy = CHIPS[ref]
    # Absolute position of pin endpoint
    ax = sx + px
    ay = sy + py
    # Label angle: point away from symbol
    # Pin angle 0 means pin points right (input on left side), label goes left (180)
    # Pin angle 180 means pin points left (output on right side), label goes right (0)
    label_angle = 0 if angle == 180 else 180 if angle == 0 else 270 if angle == 90 else 90
    lines.append(f'  (label "{net}" (at {ax:.2f} {ay:.2f} {label_angle}) (fields_autoplaced)')
    lines.append(f'    (effects (font (size 1.0 1.0)) (justify left))')
    lines.append(f'    (uuid "{uid()}"))')

# Power flags
lines.append(f'  (symbol (lib_id "power:+5V") (at 30 30 0) (unit 1)')
lines.append(f'    (in_bom yes) (on_board yes) (dnp no) (uuid "{uid()}")')
lines.append(f'    (property "Reference" "#PWR01" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))')
lines.append(f'    (property "Value" "+5V" (at 30 28 0) (effects (font (size 1.27 1.27))))')
lines.append(f'    (property "Footprint" "" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))')
lines.append(f'    (property "Datasheet" "" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))')
lines.append(f'  )')
lines.append(f'  (symbol (lib_id "power:GND") (at 30 35 0) (unit 1)')
lines.append(f'    (in_bom yes) (on_board yes) (dnp no) (uuid "{uid()}")')
lines.append(f'    (property "Reference" "#PWR02" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))')
lines.append(f'    (property "Value" "GND" (at 30 37 0) (effects (font (size 1.27 1.27))))')
lines.append(f'    (property "Footprint" "" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))')
lines.append(f'    (property "Datasheet" "" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))')
lines.append(f'  )')

lines.append(')')

outpath = "/home/jo/kiro/RV8/kicad/rv8_cpu/rv8_cpu.kicad_sch"
with open(outpath, "w") as f:
    f.write("\n".join(lines))

# Stats
connected = sum(1 for (r,p),n in NETS.items() if n not in ("GND","VCC") and not n.startswith("NC") and p in pins_for(*SYM_INFO[r]))
total = sum(1 for (r,p),n in NETS.items() if n not in ("GND","VCC") and not n.startswith("NC"))
print(f"Generated: {outpath}")
print(f"  Lines: {len(lines)}")
print(f"  Labels placed on pins: {connected}/{total}")

# Write netlist
with open("/home/jo/kiro/RV8/kicad/rv8_cpu/netlist.txt", "w") as f:
    f.write("# RV8 CPU Netlist — {ref}.{pin} = net\n\n")
    by_net = {}
    for (ref, pin), net in sorted(NETS.items()):
        if net.startswith("NC"): continue
        by_net.setdefault(net, []).append(f"{ref}.{pin}")
    for net in sorted(by_net.keys()):
        f.write(f"{net}: {', '.join(sorted(by_net[net]))}\n")
print("  Netlist: kicad/rv8_cpu/netlist.txt")
