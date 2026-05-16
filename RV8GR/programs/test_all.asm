; RV8-GR Assembly Test — exercises all instructions
; Run on Verilog sim to verify assembler output matches CPU behavior

.org $8000

; === TEST 1: LI ===
test1:
    li    $42         ; AC = $42

; === TEST 2: ADDI ===
test2:
    addi  $10         ; AC = $42 + $10 = $52

; === TEST 3: SUBI ===
test3:
    subi  $02         ; AC = $52 - $02 = $50

; === TEST 4: MV to register ===
test4:
    mv    t0, a0      ; RAM[$03] = $50

; === TEST 5: LI new value ===
    li    $0A         ; AC = $0A

; === TEST 6: ADD from register ===
test6:
    add   t0          ; AC = $0A + RAM[$03] = $0A + $50 = $5A

; === TEST 7: XOR ===
test7:
    xori  $FF         ; AC = $5A ^ $FF = $A5

; === TEST 8: MV from register ===
test8:
    mv    t0, a0      ; save $A5 to t0
    li    $00         ; AC = 0
    mv    a0, t0      ; AC = RAM[$03] = $A5

; === TEST 9: SLL (shift left = add self) ===
test9:
    li    $25         ; AC = $25
    sll               ; AC = $25 + $25 = $4A

; === TEST 10: BEQ (not taken, AC != 0) ===
test10:
    beq   skip1       ; AC=$4A != 0, should NOT branch
    li    $01         ; AC = 1 (this should execute)
    j     test11
skip1:
    li    $FF         ; should NOT reach here

; === TEST 11: BEQ (taken, AC == 0) ===
test11:
    li    $00         ; AC = 0
    beq   test12      ; Z=1, should branch

    li    $FF         ; should NOT reach here

; === TEST 12: Loop (count down from 3) ===
test12:
    li    $03         ; AC = 3
loop:
    subi  $01         ; AC--
    bne   loop        ; if AC != 0, loop back
    ; AC = 0 here

; === TEST 13: Store and Load memory ===
test13:
    li    $77         ; AC = $77
    sb    $20         ; RAM[$20] = $77
    li    $00         ; AC = 0
    lb    $20         ; AC = RAM[$20] = $77

; === DONE ===
done:
    hlt
