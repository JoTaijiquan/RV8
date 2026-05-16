# Reference CPU Designs Summary

## Gigatron TTL Computer (2018, Marcel van Kervinck & Walter Belgers)

### Key specs:
- 34 TTL chips + 2× EEPROM + 32K SRAM = ~36 total
- 930 logic gates
- Harvard architecture (split bus for efficiency)
- 1 instruction per cycle (no microcode sequencing)
- 6.25 MHz clock
- VGA video output (bit-banged by CPU!)
- 4-channel sound, joystick input
- Runs games, BASIC-like language (GCL), virtual CPU (vCPU)

### Architecture:
- Harvard (not Von Neumann) — split bus avoids bottleneck
- 16-bit instruction word (ROM is wide: opcode+operand in one read)
- 8-bit data path
- No microcode — 1 cycle per native instruction
- Control unit: 6 chips decode 8 instruction bits → 19 control signals
  - 74HC138 (ALU decoder)
  - 74HC138 (addressing decoder)
  - 74HC153 (conditional jumps)
  - 74HC139 (bus decoder + far jumps)
  - 74HC240 (inverters)
  - 74HC32 (OR gates)

### Design rules:
1. No complex logic chips (no ALU chips, no UARTs)
2. Single board, 30-40 chip count
3. Still capable of video games with sound
4. Let software do the job of complex video/sound ICs

### Software stack:
- Native code: bit-bang VGA, sound, I/O (runs from ROM)
- vCPU: interpreted virtual CPU running from RAM (34 instructions, SWEET16 inspired)
- GCL: high-level notation compiled to vCPU

### Video: CPU bit-bangs VGA directly. 160×120 pixels, 64 colors.

### Key lesson: 6 chips (138+138+153+139+240+32) decode 8→19 control signals WITHOUT EEPROM microcode.

---

## 8-Bit Computer (SAP-1, Marc Widmer 2017)
- Based on SAP-1 ("Simple As Possible") architecture
- Educational breadboard computer (Ben Eater style)

---

## Nand2Tetris
- Build computer from NAND gates up
- Hack computer: 16-bit, Harvard, custom ISA
- Educational: gates → ALU → CPU → assembler → compiler → OS

---

## Key Lessons for RV8 Project:
1. Gigatron proves: 34 TTL chips CAN run games + video
2. Wide ROM trick: 16-bit instruction = control bits in program word
3. Harvard helps: separate buses reduce chip count
4. Software replaces hardware: bit-bang video/sound
5. vCPU pattern: simple native ISA + interpreted rich ISA
6. Control decode: 6 chips decode 8→19 signals WITHOUT EEPROM
