; RV8 Test Program — Count from 0 to 5, store in memory
.org $C000

start:
    li a0, 0        ; counter = 0
    li pg, $20      ; page = 0x20 (RAM)

loop:
    sb.pg $00       ; store counter to 0x2000+offset
    addi 1          ; counter++
    cmpi 5          ; compare with 5
    bne loop        ; if not equal, loop
    hlt             ; done

; Reset vector
.org $FFFC
.db $00, $C0       ; reset → 0xC000
