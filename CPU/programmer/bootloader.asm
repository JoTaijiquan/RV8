; RV8 Bootloader — lives at $FE00-$FFFF (top 512 bytes of ROM)
; Receives program over serial, writes to ROM at $C000+
; Protocol: 2-byte length (hi,lo), then raw bytes
; After upload, jumps to $C000
;
; AT28C256 byte-write: write to ROM address, wait ~5ms
; (ROM /WE directly active during CPU write cycle)

.org $FE00

boot:
    li sp, $FF          ; init stack
    li pg, $80          ; I/O page

    ; Send 'R' to signal ready
    li a0, $52          ; 'R'
    sb.pg $00           ; UART TX

    ; Read length (2 bytes: hi, lo)
    jal rx_byte
    mov t0, a0          ; t0 = length_hi
    push t0
    jal rx_byte         ; a0 = length_lo

    ; Setup pointer to $C000
    li ph, $C0
    li pl, $00

    ; Store length_lo in zp
    sb.zp $10           ; zp[$10] = length_lo
    pop t0
    sb.zp $11           ; zp[$11] = length_hi (counter hi)

write_loop:
    ; Check if done (both counters zero)
    lb.zp $11
    bne not_done
    lb.zp $10
    beq done

not_done:
    jal rx_byte         ; a0 = next byte
    sb (ptr+)           ; write to ROM via ptr, auto-inc

    ; Wait for EEPROM write (~5ms at 3.5MHz = ~17500 cycles)
    ; Simple delay loop: 256 * 23 cycles ~= 5888 (close enough x3)
    push a0
    li a0, $00
delay1:
    subi 1
    bne delay1
    li a0, $00
delay2:
    subi 1
    bne delay2
    li a0, $40
delay3:
    subi 1
    bne delay3
    pop a0

    ; Decrement 16-bit counter
    lb.zp $10
    subi 1
    sb.zp $10
    bcs write_loop      ; no borrow, continue
    lb.zp $11
    subi 1
    sb.zp $11
    bra write_loop

done:
    ; Send 'D' to signal done
    li a0, $44          ; 'D'
    sb.pg $00
    ; Jump to user program
    li ph, $C0
    li pl, $00
    jmp

; Subroutine: receive one byte from serial
rx_byte:
    lb.pg $01           ; read status
    andi $01            ; bit0 = rx_ready
    beq rx_byte         ; spin until ready
    lb.pg $00           ; read data (clears flag)
    ret

; Reset vector — points to bootloader
.org $FFFC
.db $00, $FE
