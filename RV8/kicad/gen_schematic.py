#!/usr/bin/env python3
"""RV8 CPU KiCad schematic — human-centric layout.

Layout follows the CPU data flow (left→right, top→bottom):
  Row 1: FETCH — Clock mux → PC → Address Mux → ROM/RAM
  Row 2: DECODE — IR (opcode + operand) → Unit Decode → Address Decode
  Row 3: EXECUTE — ALU (XOR + Adders) → Registers (a0, t0, sp, pg)
  Row 4: MEMORY — Pointer → Bus Buffer → Data Bus → Connector
  Row 5: CONTROL — Flags → AND/OR gates → State machine

Each chip has wire stubs with net labels. Same label = same connection.
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
        pins[m[6].strip()] = (float(m[2]), float(m[3]), int(m[4]), m[1])
    return pins

PIN_CACHE = {}
def pins_for(lib_file, sym_name):
    key = (lib_file, sym_name)
    if key not in PIN_CACHE: PIN_CACHE[key] = get_pins(lib_file, sym_name)
    return PIN_CACHE[key]

SYM_INFO = {
    "U1": ("74xx.kicad_sym","74LS161"), "U2": ("74xx.kicad_sym","74LS161"),
    "U3": ("74xx.kicad_sym","74LS161"), "U4": ("74xx.kicad_sym","74LS161"),
    "U5": ("74xx.kicad_sym","74LS574"), "U6": ("74xx.kicad_sym","74LS574"),
    "U7": ("74xx.kicad_sym","74LS574"), "U8": ("74xx.kicad_sym","74LS574"),
    "U9": ("74xx.kicad_sym","74LS574"), "U10": ("74xx.kicad_sym","74LS574"),
    "U11": ("74xx.kicad_sym","74LS161"), "U12": ("74xx.kicad_sym","74LS161"),
    "U13": ("74xx.kicad_sym","74LS283"), "U14": ("74xx.kicad_sym","74LS283"),
    "U15": ("74xx.kicad_sym","74HC86"), "U16": ("74xx.kicad_sym","74LS157"),
    "U17": ("74xx.kicad_sym","74LS157"), "U18": ("74xx.kicad_sym","74HC138"),
    "U19": ("74xx.kicad_sym","74LS245"), "U20": ("74xx.kicad_sym","74LS74"),
    "U21": ("74xx.kicad_sym","74LS74"), "U22": ("74xx.kicad_sym","74LS08"),
    "U23": ("74xx.kicad_sym","74LS32"), "U24": ("74xx.kicad_sym","74HC138"),
    "U25": ("74xx.kicad_sym","74LS157"),
    "U26": ("Memory_EEPROM.kicad_sym","28C256"),
    "U27": ("Memory_RAM.kicad_sym","KM62256CLP"),
    "J1": ("Connector_Generic.kicad_sym","Conn_02x20_Odd_Even"),
}

# Human-centric layout: data flows left→right, top→bottom
# Spacing: ~50mm between chips horizontally, ~65mm between rows
CHIPS = {
    # Row 1: FETCH path (clock → PC → address mux → memory)
    "U25": (55, 55),                                    # Clock mux
    "U1": (115, 55), "U2": (165, 55), "U3": (215, 55), "U4": (265, 55),  # PC
    "U16": (330, 55), "U17": (380, 55),                 # Address mux

    # Row 2: DECODE (IR → decode)
    "U5": (115, 125), "U6": (165, 125),                 # IR opcode, operand
    "U18": (250, 125),                                   # Unit decode
    "U24": (330, 125),                                   # Address decode
    "U26": (410, 55),                                    # ROM
    "U27": (410, 125),                                   # RAM

    # Row 3: EXECUTE (ALU → registers)
    "U15": (80, 195),                                    # XOR (B invert)
    "U13": (145, 195), "U14": (195, 195),               # Adders
    "U7": (275, 195), "U8": (325, 195), "U9": (375, 195), "U10": (425, 195),  # Regs

    # Row 4: MEMORY ACCESS (pointer → bus buffer → connector)
    "U11": (80, 265), "U12": (130, 265),                # Pointer
    "U19": (210, 265),                                   # Bus buffer
    "J1": (330, 265),                                    # 40-pin connector

    # Row 5: CONTROL (flags → gates → state)
    "U20": (80, 340), "U21": (145, 340),                # Flags
    "U22": (225, 340), "U23": (290, 340),               # AND, OR gates
}

# === NET CONNECTIONS ===
NETS = {}
def connect(ref, pin, net): NETS[(ref, pin)] = net

# CLOCK MUX (U25)
connect("U25","I0a","OSC_3M5"); connect("U25","I1a","STEP_BTN"); connect("U25","Za","CLK")
connect("U25","S","RUN_N"); connect("U25","E","GND")
for s in "bcd": connect("U25",f"I0{s}","GND"); connect("U25",f"I1{s}","GND")

# PC (U1-U4)
for i, u in enumerate(["U1","U2","U3","U4"]):
    connect(u,"CP","CLK"); connect(u,"~{MR}","RST_N")
    connect(u,"~{PE}","pc_load_n"); connect(u,"CEP","pc_inc")
    for b in range(4):
        connect(u,f"D{b}",f"D{i*4+b}")
        connect(u,f"Q{b}",f"PC{i*4+b}")
connect("U1","CET","pc_inc"); connect("U1","TC","U1_TC")
connect("U2","CET","U1_TC"); connect("U2","TC","U2_TC")
connect("U3","CET","U2_TC"); connect("U3","TC","U3_TC"); connect("U4","CET","U3_TC")

# ADDRESS MUX (U16-U17): PC vs Pointer → Address bus
for b,s in enumerate("abcd"):
    connect("U16",f"I0{s}",f"PC{b}"); connect("U16",f"I1{s}",f"ptr_out{b}"); connect("U16",f"Z{s}",f"A{b}")
    connect("U17",f"I0{s}",f"PC{b+4}"); connect("U17",f"I1{s}",f"ptr_out{b+4}"); connect("U17",f"Z{s}",f"A{b+4}")
connect("U16","S","addr_sel"); connect("U16","E","GND")
connect("U17","S","addr_sel"); connect("U17","E","GND")

# IR (U5=opcode, U6=operand)
for u,clk in [("U5","ir_load0"),("U6","ir_load1")]:
    connect(u,"Cp",clk); connect(u,"OE","GND")
    for b in range(8): connect(u,f"D{b}",f"D{b}")
for b in range(8):
    connect("U5",f"Q{b}",f"opcode{b}")
    connect("U6",f"Q{b}",f"operand{b}")

# UNIT DECODE (U18): opcode[7:5] → which functional unit
connect("U18","A0","opcode5"); connect("U18","A1","opcode6"); connect("U18","A2","opcode7")
connect("U18","E2","VCC"); connect("U18","~{E0}","GND"); connect("U18","~{E1}","exec_n")
for i,n in enumerate(["alu_en_n","imm_en_n","ldst_en_n","branch_en_n","shift_en_n","ptr_en_n","x","sys_en_n"]):
    connect("U18",f"~{{Y{i}}}",n)

# ADDRESS DECODE (U24): A[15:13] → chip select
connect("U24","A0","A13"); connect("U24","A1","A14"); connect("U24","A2","A15")
connect("U24","E2","VCC"); connect("U24","~{E0}","GND"); connect("U24","~{E1}","GND")
for i,n in enumerate(["ram_cs0_n","ram_cs1_n","slot0_n","slot1_n","io_cs_n","x","rom_cs6_n","rom_cs7_n"]):
    connect("U24",f"~{{Y{i}}}",n)

# ROM (U26)
for b in range(15): connect("U26",f"A{b}",f"A{b}")
for b in range(8): connect("U26",f"D{b}",f"D{b}")
connect("U26","~{CS}","rom_ce_n"); connect("U26","~{OE}","mem_rd_n"); connect("U26","~{WE}","VCC")

# RAM (U27)
for b in range(15): connect("U27",f"A{b}",f"A{b}")
for b in range(8): connect("U27",f"Q{b}",f"D{b}")
connect("U27","~{CS}","ram_ce_n"); connect("U27","~{OE}","mem_rd_n"); connect("U27","~{WE}","mem_wr_n")

# ALU: XOR (U15) + Adders (U13, U14)
# U15 XOR gates invert B input for SUB
# U13 low nibble, U14 high nibble
for b in range(1,5):
    connect("U13",f"A{b}",f"a0_out{b-1}"); connect("U13",f"B{b}",f"alu_b{b-1}"); connect("U13",f"S{b}",f"alu_result{b-1}")
    connect("U14",f"A{b}",f"a0_out{b+3}"); connect("U14",f"B{b}",f"alu_b{b+3}"); connect("U14",f"S{b}",f"alu_result{b+3}")
connect("U13","C0","carry_in"); connect("U13","C4","carry_mid")
connect("U14","C0","carry_mid"); connect("U14","C4","carry_out")

# REGISTERS (U7=a0, U8=t0, U9=sp, U10=pg)
for u,nm,clk in [("U7","a0","a0_clk"),("U8","t0","t0_clk"),("U9","sp","sp_clk"),("U10","pg","pg_clk")]:
    connect(u,"Cp",clk); connect(u,"OE","GND")
    for b in range(8): connect(u,f"Q{b}",f"{nm}_out{b}")
for b in range(8): connect("U7",f"D{b}",f"alu_result{b}")
for u in ["U8","U9","U10"]:
    for b in range(8): connect(u,f"D{b}",f"D{b}")

# POINTER (U11=pl, U12=ph)
for i,u in enumerate(["U11","U12"]):
    connect(u,"CP","CLK"); connect(u,"~{MR}","RST_N"); connect(u,"CEP","ptr_inc")
    for b in range(4):
        connect(u,f"D{b}",f"D{b}")
        connect(u,f"Q{b}",f"ptr_out{i*4+b}")
connect("U11","~{PE}","pl_load_n"); connect("U12","~{PE}","ph_load_n")
connect("U11","CET","ptr_inc"); connect("U11","TC","ptr_tc"); connect("U12","CET","ptr_tc")

# BUS BUFFER (U19)
connect("U19","A->B","buf_dir"); connect("U19","CE","buf_en_n")
for b in range(8):
    connect("U19",f"A{b}",f"data_int{b}")
    connect("U19",f"B{b}",f"D{b}")

# 40-PIN CONNECTOR (J1)
conn = ["A0","A1","A2","A3","A4","A5","A6","A7","A8","A9","A10","A11","A12","A13","A14","A15",
        "D0","D1","D2","D3","D4","D5","D6","D7",
        "mem_rd_n","mem_wr_n","CLK","RST_N","NMI_N","IRQ_N","HALT","SYNC",
        "x","x","x","x","x","x","VCC","GND"]
for i,n in enumerate(conn): connect("J1",f"Pin_{i+1}",n)

# FLAGS (U20: Z+C, U21: N+state)
# AND gates (U22), OR gates (U23) — control signal generation

# === GENERATE SCHEMATIC ===
lines = []
lines.append(f'(kicad_sch (version 20230121) (generator "rv8_gen")')
lines.append(f'  (uuid "{uid()}")')
lines.append('  (paper "A0")')
lines.append('  (title_block')
lines.append('    (title "RV8 CPU — Chip Wiring (Data Flow View)")')
lines.append('    (date "2026-05-12")')
lines.append('    (rev "3.0")')
lines.append('    (comment 1 "27 chips — signal names match rv8_cpu.v")')
lines.append('    (comment 2 "Flow: FETCH(top) → DECODE → EXECUTE → MEMORY(bottom)")')
lines.append('  )')
lines.append('  (lib_symbols)')
lines.append('')

# Section labels with flow description
sections = [
    (30, 35, "① FETCH: Clock → PC → Address Mux → ROM/RAM"),
    (30, 105, "② DECODE: Data Bus → IR → Unit Decode / Address Decode"),
    (30, 175, "③ EXECUTE: a0 + operand → ALU → result → Registers"),
    (30, 245, "④ MEMORY: Pointer → Bus Buffer → External (40-pin)"),
    (30, 320, "⑤ CONTROL: Flags → Logic Gates → State Machine"),
]
for x, y, text in sections:
    lines.append(f'  (text "{text}" (at {x} {y} 0)')
    lines.append(f'    (effects (font (size 2.5 2.5) bold)))')

# Place symbols
for ref, (sx, sy) in CHIPS.items():
    lib_file, sym_name = SYM_INFO[ref]
    lib_id = lib_file.replace(".kicad_sym","") + ":" + sym_name
    lines.append(f'  (symbol (lib_id "{lib_id}") (at {sx} {sy} 0) (unit 1)')
    lines.append(f'    (in_bom yes) (on_board yes) (dnp no) (uuid "{uid()}")')
    lines.append(f'    (property "Reference" "{ref}" (at {sx} {sy-5} 0) (effects (font (size 1.5 1.5))))')
    lines.append(f'    (property "Value" "{sym_name}" (at {sx} {sy+5} 0) (effects (font (size 1.0 1.0))))')
    lines.append(f'    (property "Footprint" "" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))')
    lines.append(f'    (property "Datasheet" "" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))')
    lines.append(f'  )')

# Wire stubs + labels at pin endpoints
WIRE_LEN = 5.08
for (ref, pin_name), net in NETS.items():
    if net == "x": continue
    lib_file, sym_name = SYM_INFO[ref]
    pins = pins_for(lib_file, sym_name)
    if pin_name not in pins: continue
    px, py, angle, ptype = pins[pin_name]
    sx, sy = CHIPS[ref]
    pin_x, pin_y = sx + px, sy + py

    if angle == 0: wx, wy, la = pin_x - WIRE_LEN, pin_y, 180
    elif angle == 180: wx, wy, la = pin_x + WIRE_LEN, pin_y, 0
    elif angle == 90: wx, wy, la = pin_x, pin_y + WIRE_LEN, 270
    else: wx, wy, la = pin_x, pin_y - WIRE_LEN, 90

    lines.append(f'  (wire (pts (xy {pin_x:.2f} {pin_y:.2f}) (xy {wx:.2f} {wy:.2f}))')
    lines.append(f'    (stroke (width 0) (type solid)) (uuid "{uid()}"))')

    if net in ("VCC","GND"):
        sym = "+5V" if net == "VCC" else "GND"
        dy = 2 if net == "GND" else -2
        lines.append(f'  (symbol (lib_id "power:{sym}") (at {wx:.2f} {wy:.2f} 0) (unit 1)')
        lines.append(f'    (in_bom yes) (on_board yes) (dnp no) (uuid "{uid()}")')
        lines.append(f'    (property "Reference" "#PWR?" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))')
        lines.append(f'    (property "Value" "{sym}" (at {wx:.2f} {wy+dy:.2f} 0) (effects (font (size 0.8 0.8))))')
        lines.append(f'    (property "Footprint" "" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))')
        lines.append(f'    (property "Datasheet" "" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))')
        lines.append(f'  )')
    else:
        lines.append(f'  (label "{net}" (at {wx:.2f} {wy:.2f} {la}) (fields_autoplaced)')
        lines.append(f'    (effects (font (size 1.0 1.0)) (justify left)) (uuid "{uid()}"))')

lines.append(')')

outpath = "/home/jo/kiro/RV8/kicad/rv8_cpu/rv8_cpu.kicad_sch"
with open(outpath, "w") as f:
    f.write("\n".join(lines))

# Export
print(f"Generated: {outpath}")
wires = sum(1 for (r,p),n in NETS.items() if n != 'x' and p in pins_for(*SYM_INFO[r]))
print(f"  Chips: {len(CHIPS)}, Wires: {wires}")
print(f"  Layout: data flows top→bottom (fetch→decode→execute→memory→control)")
print(f"  Signal names match rv8_cpu.v (e.g., pc_inc, alu_result, ptr_out)")
