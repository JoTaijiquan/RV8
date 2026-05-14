#!/usr/bin/env python3
"""RV8 Cross-Assembler — Assembles RV8 assembly to binary/hex."""

import sys, re

# Opcode table: mnemonic → (opcode, operand_type)
# Types: 'reg'=register, 'imm'=immediate, 'off'=branch offset, 'none'=unused
OPCODES = {
    'add':  (0x00,'reg'), 'sub':  (0x01,'reg'), 'and':  (0x02,'reg'),
    'or':   (0x03,'reg'), 'xor':  (0x04,'reg'), 'cmp':  (0x05,'reg'),
    'adc':  (0x06,'reg'), 'sbc':  (0x07,'reg'),
    'li.sp':(0x10,'imm'), 'li.a0':(0x11,'imm'), 'li.pl':(0x12,'imm'),
    'li.ph':(0x13,'imm'), 'li.t0':(0x14,'imm'), 'li.pg':(0x15,'imm'),
    'addi': (0x16,'imm'), 'subi': (0x17,'imm'), 'cmpi': (0x18,'imm'),
    'andi': (0x19,'imm'), 'ori':  (0x1A,'imm'), 'xori': (0x1B,'imm'),
    'tst':  (0x1C,'imm'),
    'lb':   (0x20,'reg'), 'sb':   (0x21,'reg'),
    'lb+':  (0x22,'reg'), 'sb+':  (0x23,'reg'),
    'mov.rd':(0x24,'reg'),'mov.a0':(0x25,'reg'),
    'lb.sp':(0x26,'imm'), 'sb.sp':(0x27,'imm'),
    'lb.zp':(0x28,'imm'), 'sb.zp':(0x29,'imm'),
    'lb.pg':(0x2A,'imm'), 'sb.pg':(0x2B,'imm'),
    'push': (0x2C,'reg'), 'pop':  (0x2D,'reg'),
    'beq':  (0x30,'off'), 'bne':  (0x31,'off'), 'bcs':  (0x32,'off'),
    'bcc':  (0x33,'off'), 'bmi':  (0x34,'off'), 'bpl':  (0x35,'off'),
    'bra':  (0x36,'off'),
    'skipz':(0x37,'none'),'skipnz':(0x38,'none'),
    'skipc':(0x39,'none'),'skipnc':(0x3A,'none'),
    'jmp':  (0x3C,'none'),'jal':  (0x3D,'none'),'ret':  (0x3E,'none'),
    'shl':  (0x40,'none'),'shr':  (0x41,'none'),
    'rol':  (0x42,'none'),'ror':  (0x43,'none'),
    'inc':  (0x44,'none'),'dec':  (0x45,'none'),
    'not':  (0x46,'none'),'swap': (0x47,'none'),
    'inc16':(0x48,'none'),'dec16':(0x49,'none'),'add16':(0x4A,'imm'),
    'clc':  (0xF0,'none'),'sec':  (0xF1,'none'),
    'ei':   (0xF2,'none'),'di':   (0xF3,'none'),
    'rti':  (0xF4,'none'),'trap': (0xF5,'imm'),
    'nop':  (0xFE,'none'),'hlt':  (0xFF,'none'),
}

REGS = {'c0':0,'sp':1,'a0':2,'pl':3,'ph':4,'t0':5,'pg':6}

def parse_value(s, labels, pc):
    """Parse immediate/offset value."""
    s = s.strip()
    if s in labels:
        return labels[s] - pc  # relative offset for branches
    if s.startswith('$') or s.startswith('0x'):
        return int(s.replace('$','0x'), 16)
    if s.startswith('%'):
        return int(s[1:], 2)
    if s.lstrip('-').isdigit():
        return int(s)
    if s in labels:
        return labels[s]
    raise ValueError(f"Unknown value: {s}")

def assemble(source, org=0xC000):
    """Two-pass assembler."""
    lines = source.split('\n')
    labels = {}
    output = []

    # Pass 1: collect labels
    pc = org
    for line in lines:
        line = line.split(';')[0].strip()  # remove comments
        if not line: continue
        if line.endswith(':'):
            labels[line[:-1]] = pc
            continue
        if line.startswith('.org'):
            pc = int(line.split()[1].replace('$','0x'), 16)
            continue
        if line.startswith('.db'):
            vals = line[3:].split(',')
            pc += len(vals)
            continue
        pc += 2  # all instructions are 2 bytes

    # Pass 2: generate code
    pc = org
    for line in lines:
        line = line.split(';')[0].strip()
        if not line: continue
        if line.endswith(':'): continue
        if line.startswith('.org'):
            pc = int(line.split()[1].replace('$','0x'), 16)
            continue
        if line.startswith('.db'):
            for v in line[3:].split(','):
                output.append((pc, parse_value(v.strip(), labels, pc) & 0xFF))
                pc += 1
            continue

        # Parse instruction
        parts = line.lower().split(None, 1)
        mnem = parts[0]
        operand_str = parts[1] if len(parts) > 1 else ''

        # Handle LI variants: "li a0, 42" → "li.a0"
        if mnem == 'li':
            reg, val = operand_str.split(',')
            mnem = f'li.{reg.strip()}'
            operand_str = val.strip()
        # Handle MOV: "mov t0, a0" → "mov.rd" with reg operand
        elif mnem == 'mov':
            dst, src = operand_str.split(',')
            dst, src = dst.strip(), src.strip()
            if dst == 'a0':
                mnem = 'mov.a0'
                operand_str = src
            else:
                mnem = 'mov.rd'
                operand_str = dst

        if mnem not in OPCODES:
            raise ValueError(f"Unknown mnemonic: {mnem} at PC={pc:04X}")

        opcode, op_type = OPCODES[mnem]
        if op_type == 'reg':
            operand = REGS.get(operand_str.strip(), 0)
        elif op_type == 'imm':
            operand = parse_value(operand_str, labels, pc) & 0xFF
        elif op_type == 'off':
            target = parse_value(operand_str, labels, pc + 2)
            operand = target & 0xFF
        else:
            operand = 0

        output.append((pc, opcode))
        output.append((pc + 1, operand))
        pc += 2

    return output, labels

def to_hex(output, org=0xC000):
    """Generate Intel HEX format (sparse, only non-FF bytes)."""
    lines = []
    data = {}
    for addr, byte in output:
        data[addr] = byte
    if not data: return ''
    # Group into 16-byte rows, skip all-FF rows
    start = min(data.keys())
    end = max(data.keys())
    for base in range(start, end + 1, 16):
        row = [data.get(a, 0xFF) for a in range(base, min(base + 16, end + 1))]
        if all(b == 0xFF for b in row): continue  # skip empty rows
        length = len(row)
        checksum = (length + (base >> 8) + (base & 0xFF) + sum(row)) & 0xFF
        checksum = (~checksum + 1) & 0xFF
        hex_data = ''.join(f'{b:02X}' for b in row)
        lines.append(f':{length:02X}{base:04X}00{hex_data}{checksum:02X}')
    lines.append(':00000001FF')
    return '\n'.join(lines)

def to_bin(output):
    """Generate raw binary."""
    if not output: return bytes()
    data = {}
    for addr, byte in output:
        data[addr] = byte
    start = min(data.keys())
    end = max(data.keys())
    return bytes(data.get(a, 0xFF) for a in range(start, end + 1))

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: rv8asm.py <input.asm> [-o output] [-f hex|bin]")
        sys.exit(1)

    infile = sys.argv[1]
    outfile = None
    fmt = 'hex'
    i = 2
    while i < len(sys.argv):
        if sys.argv[i] == '-o': outfile = sys.argv[i+1]; i += 2
        elif sys.argv[i] == '-f': fmt = sys.argv[i+1]; i += 2
        else: i += 1

    with open(infile) as f:
        source = f.read()

    output, labels = assemble(source)

    if not outfile:
        outfile = infile.rsplit('.', 1)[0] + ('.hex' if fmt == 'hex' else '.bin')

    if fmt == 'hex':
        with open(outfile, 'w') as f:
            f.write(to_hex(output))
    else:
        with open(outfile, 'wb') as f:
            f.write(to_bin(output))

    print(f"Assembled {len(output)//2} instructions, {len(output)} bytes")
    print(f"Labels: {labels}")
    print(f"Output: {outfile}")
