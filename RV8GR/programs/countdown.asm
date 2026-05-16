; RV8-GR Test Program — Count down from 5 to 0
; Expected: AC ends at 0, loops 5 times

.org $8000

start:
    li    5           ; AC = 5
    mv    t0, a0      ; save to r3 (RAM[$03])

loop:
    subi  1           ; AC = AC - 1
    mv    t0, a0      ; save counter
    bne   loop        ; if AC != 0, loop back

done:
    hlt               ; stop
