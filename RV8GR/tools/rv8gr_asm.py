#!/usr/bin/env python3
"""RV8-GR Assembler — translates RISC-V-like assembly to binary."""

import sys, re

# Control byte bit positions
ALU_SUB    = 0x80
XOR_MODE   = 0x40
MUX_SEL    = 0x20
AC_WR      = 0x10
SOURCE_TYPE= 0x08
STORE      = 0x04
BRANCH     = 0x02
JUMP       = 0x01

# Register names → RAM addresses
REGS = {'zero':0,'r0':0, 'a0':1,'r1':1, 'a1':2,'r2':2,
         't0':3,'r3':3, 't1':4,'r4':4, 's0':5,'r5':5,
         's1':6,'r6':6, 'sp':7,'ra':7,'r7':7}

# Instruction definitions: mnemonic → (control_byte, operand_type)
# operand_type: 'imm'=immediate, 'reg'=register addr, 'addr'=target address, 'none'=0
INSTRUCTIONS = {
    'li':    (MUX_SEL | AC_WR, 'imm'),
    'addi':  (AC_WR, 'imm'),
    'subi':  (ALU_SUB | AC_WR, 'imm'),
    'xori':  (XOR_MODE | AC_WR, 'imm'),
    'add':   (AC_WR | SOURCE_TYPE, 'reg'),
    'sub':   (ALU_SUB | AC_WR | SOURCE_TYPE, 'reg'),
    'xor':   (XOR_MODE | AC_WR | SOURCE_TYPE, 'reg'),
    'mv_to': (STORE, 'reg'),          # MV rd, a0 (store AC to register)
    'mv_from':(MUX_SEL | AC_WR | SOURCE_TYPE, 'reg'),  # MV a0, rs
    'lb':    (MUX_SEL | AC_WR | SOURCE_TYPE, 'addr'),   # LB a0, [addr]
    'sb':    (STORE, 'addr'),          # SB a0, [addr]
    'beq':   (BRANCH, 'addr'),
    'bne':   (ALU_SUB | BRANCH, 'addr'),  # SUB bit as invert for BNE
    'j':     (JUMP, 'addr'),
    'jal':   (AC_WR | JUMP, 'addr'),  # saves PC to AC (simplified)
    'nop':   (0x00, 'none'),
    'hlt':   (JUMP, 'none'),           # jump to self
    'sll':   (AC_WR | SOURCE_TYPE, 'self'),  # ADD a0, a0 (shift left)
}

def parse_operand(op_str, op_type, labels, current_addr):
    """Parse operand string to byte value."""
    op_str = op_str.strip()
    if op_type == 'none':
        return current_addr & 0xFF  # HLT: jump to self (low byte)
    if op_type == 'self':
        return REGS.get('a0', 1)  # SLL = ADD a0, a0 → read a0 from RAM[$01]
    if op_type == 'imm':
        return parse_number(op_str)
    if op_type == 'reg':
        if op_str in REGS:
            return REGS[op_str]
        return parse_number(op_str)
    if op_type == 'addr':
        if op_str in labels:
            return labels[op_str] & 0xFF
        return parse_number(op_str)
    return 0

def parse_number(s, mask=0xFF):
    """Parse number: $FF, 0xFF, 0b1010, or decimal."""
    s = s.strip()
    if s.startswith('$'):
        return int(s[1:], 16) & mask
    if s.startswith('0x'):
        return int(s, 16) & mask
    if s.startswith('0b'):
        return int(s, 2) & mask
    return int(s) & mask

def assemble(source, org=0x8000):
    """Assemble source code to binary."""
    lines = source.strip().split('\n')
    labels = {}
    instructions = []
    addr = org

    # Pass 1: collect labels
    for line in lines:
        line = line.split(';')[0].strip()  # remove comments
        if not line:
            continue
        if line.endswith(':'):
            labels[line[:-1]] = addr
            continue
        # Count instruction (2 bytes each)
        parts = line.split(None, 1)
        mnemonic = parts[0].lower()
        if mnemonic in INSTRUCTIONS:
            addr += 2
        elif mnemonic == 'mv':
            addr += 2
        elif mnemonic == '.org':
            addr = parse_number(parts[1], 0xFFFF)

    # Pass 2: generate bytes
    addr = org
    output = []
    for line in lines:
        line = line.split(';')[0].strip()
        if not line or line.endswith(':'):
            continue
        parts = line.split(None, 1)
        mnemonic = parts[0].lower()
        operand_str = parts[1] if len(parts) > 1 else ''

        if mnemonic == '.org':
            addr = parse_number(operand_str, 0xFFFF)
            continue

        # Handle MV (two forms)
        if mnemonic == 'mv':
            args = [a.strip() for a in operand_str.split(',')]
            if args[0].lower() in ('a0', 'r1') or args[0].lower() == 'a0':
                # MV a0, rs → load from register
                mnemonic = 'mv_from'
                operand_str = args[1]
            else:
                # MV rd, a0 → store to register
                mnemonic = 'mv_to'
                operand_str = args[0]

        if mnemonic not in INSTRUCTIONS:
            print(f"ERROR: unknown instruction '{mnemonic}' at ${addr:04X}")
            continue

        ctrl, op_type = INSTRUCTIONS[mnemonic]
        operand = parse_operand(operand_str, op_type, labels, addr)

        output.append((addr, ctrl, operand))
        addr += 2

    return output, labels

def write_bin(output, filename, org=0x8000, size=0x8000):
    """Write binary file (fills with NOP=$00)."""
    data = bytearray(size)
    for addr, ctrl, operand in output:
        offset = addr - org
        if 0 <= offset < size - 1:
            data[offset] = ctrl
            data[offset + 1] = operand
    with open(filename, 'wb') as f:
        f.write(data)

def write_hex(output, filename):
    """Write hex listing."""
    with open(filename, 'w') as f:
        for addr, ctrl, operand in output:
            f.write(f"${addr:04X}: {ctrl:02X} {operand:02X}\n")

# === MAIN ===
if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <source.asm> [-o output.bin] [-hex output.hex]")
        print(f"\nExample:")
        print(f"  {sys.argv[0]} test.asm -o test.bin")
        sys.exit(1)

    src_file = sys.argv[1]
    bin_file = None
    hex_file = None

    i = 2
    while i < len(sys.argv):
        if sys.argv[i] == '-o' and i+1 < len(sys.argv):
            bin_file = sys.argv[i+1]; i += 2
        elif sys.argv[i] == '-hex' and i+1 < len(sys.argv):
            hex_file = sys.argv[i+1]; i += 2
        else:
            i += 1

    with open(src_file) as f:
        source = f.read()

    output, labels = assemble(source)

    if not bin_file and not hex_file:
        hex_file = src_file.rsplit('.', 1)[0] + '.hex'

    if bin_file:
        write_bin(output, bin_file)
        print(f"Binary: {bin_file} ({len(output)*2} bytes)")

    if hex_file:
        write_hex(output, hex_file)
        print(f"Hex listing: {hex_file}")

    print(f"Assembled {len(output)} instructions, {len(labels)} labels")
    if labels:
        for name, addr in labels.items():
            print(f"  {name}: ${addr:04X}")
