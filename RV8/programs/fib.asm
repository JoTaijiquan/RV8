; RV8 Demo: Fibonacci sequence
; Stores fib(0)..fib(10) at 0x2000-0x200A
; Expected output in memory: 00 01 01 02 03 05 08 0D 15 22 37
; Uses zero-page address $10 as loop counter
.org $C000

start:
    ; Init: fib[0]=0, fib[1]=1
    li ph, $20
    li pl, $00
    li a0, 0
    sb (ptr+)           ; mem[2000]=0, ptr→2001
    li a0, 1
    sb (ptr+)           ; mem[2001]=1, ptr→2002

    ; Loop counter in zero-page
    li a0, 9
    sb.zp $10           ; zp[$10] = 9 (iterations remaining)

loop:
    ; a0 = fib[i-1] (at ptr-1)
    dec16
    lb a0, (ptr)        ; a0 = fib[i-1]
    mov t0, a0          ; t0 = fib[i-1]

    ; a0 = fib[i-2] (at ptr-1 again = ptr-2 from original)
    dec16
    lb a0, (ptr)        ; a0 = fib[i-2]

    ; fib[i] = fib[i-2] + fib[i-1]
    add t0              ; a0 = fib[i-2] + fib[i-1]

    ; Restore ptr to write position (advance +2)
    inc16
    inc16
    sb (ptr+)           ; store result, ptr advances

    ; Decrement counter
    lb.zp $10           ; a0 = counter
    subi 1
    sb.zp $10           ; store back
    bne loop            ; if counter != 0, continue

    hlt                 ; done!

; Reset vector
.org $FFFC
.db $00, $C0
