# System ROM — Requirements

## BASIC Interpreter

### Language Features
| Feature | Notes |
|---------|-------|
| Line numbers | 1-9999 |
| Variables | A-Z (26 integers), A$-Z$ (26 strings) |
| Arrays | DIM A(n), single dimension |
| Integers | 16-bit signed (-32768 to 32767) |
| Float | Software FP (4-byte, ~7 digits) |
| Strings | Fixed 32 bytes or pointer-based |
| Operators | +, -, *, /, MOD, AND, OR, NOT, <, >, =, <> |

### Commands
| Category | Commands |
|----------|----------|
| Flow | IF/THEN, GOTO, GOSUB/RETURN, FOR/NEXT, END, STOP |
| I/O | PRINT, INPUT, TAB, SPC, CHR$, ASC |
| Memory | PEEK, POKE, USR (call machine code) |
| Hardware | OUT addr,val / INP(addr) |
| Sound | SOUND freq, duration / BEEP |
| Graphics | PLOT x,y / DRAW x,y / CLS / INK c / PAPER c |
| Storage | CSAVE "name" / CLOAD "name" / SAVE / LOAD |
| Utility | LIST, RUN, NEW, CLR, REM, DATA/READ |

### Performance Target
- ~30 lines/sec for simple programs
- Fibonacci to 1000: < 2 seconds
- Screen clear: < 100ms

## Monitor/Debugger

| Command | Function |
|---------|----------|
| D addr | Dump 16 bytes from address |
| E addr | Edit bytes at address |
| L addr | Disassemble from address |
| G addr | Go (execute from address) |
| R | Show all registers |
| B addr | Set breakpoint |
| S | Single step |
| F addr len val | Fill memory |
| M src dst len | Move (copy) memory |
| X | Exit to BASIC |

## Mini Assembler

| Feature | Notes |
|---------|-------|
| Input | One instruction per line |
| Output | Assembled directly to RAM |
| Syntax | Standard RV8 mnemonics |
| No labels | Use hex addresses |
| No macros | Keep it tiny (~1KB) |
| Example | `>A C000` → `LI a0, 5` → assembles $11 $05 at $C000 |
