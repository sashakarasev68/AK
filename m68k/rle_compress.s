
    .data

input_addr:   .word  0x80        ; port in
output_addr:  .word  0x84        ; port out
buffer_addr:  .word  0x400       ; scratch buffer for the raw input line
stack_top:    .word  0x1000      ; initial stack pointer

    .text

    .org        0x100            ; 0x80..0x87 are taken by io ports

_start:
    movea.l     stack_top, A7
    movea.l     (A7), A7
    movea.l     input_addr, A0
    movea.l     (A0), A0
    movea.l     output_addr, A1
    movea.l     (A1), A1
    jsr         rle_compress
    halt

; rle_compress: reads a line from A0 into buffer_addr, then compresses it
; and writes the result to port A1.
; local vars (frame, set up by link A6,-8):
;   -4(A6) = input_length  (chars read so far, including the \n)
;   -8(A6) = output_length (total compressed length, from the count pass)
; registers: D1 = last_char, D2 = curr_length, D4 = curr_char
rle_compress:
    link        A6, -8
    clr.l       -4(A6)           ; -4(A6) = input_length
    movea.l     buffer_addr, A2  ; A2 = write pointer into buffer
    movea.l     (A2), A2

; ---- pass 1: read the whole line from the port into the buffer ----
read_loop:
    move.l      -4(A6), D0       ; D0 = input_length
    cmp.b       64, D0           ; 64 = MAX_INPUT_LEN
    beq         fail_overflow
    move.b      (A0), D4         ; D4 = curr_char
    add.b       1, -4(A6)
    move.b      D4, (A2)+        ; store char into buffer (incl. the \n)

    cmp.b       10, D4           ; 10 = EOL
    beq         read_done
    cmp.b       0, D4            ; 0 = EOF
    beq         fail_eof
    jmp         read_loop

read_done:
    move.l      -4(A6), D0       ; D0 = input_length
    cmp.b       1, D0            ; only the \n was read -> empty line
    beq         exit

; ---- pass 2: dry run over the buffer, only totals output_length ----
    clr.l       -8(A6)           ; -8(A6) = output_length
    movea.l     buffer_addr, A3  ; A3 = read pointer into buffer
    movea.l     (A3), A3
    clr.l       D2               ; D2 = curr_length

count_loop:
    move.b      (A3)+, D4        ; D4 = curr_char
    cmp.b       10, D4           ; 10 = EOL
    beq         count_end
    cmp.b       0, D2            ; D2 = curr_length
    beq         count_next

    cmp.b       D1, D4           ; D1 = last_char
    bne         count_flush
    cmp.b       9, D2            ; 9 = MAX_COMPRESSION_SIZE
    beq         count_flush
    add.b       1, D2            ; (D2 = curr_length)++
    jmp         count_loop

count_flush:
    move.l      -8(A6), D0       ; D0 = output_length
    add.b       2, D0
    cmp.b       62, D0           ; 62+2 = MAX_OUTPUT_LEN
    bgt         fail_overflow
    move.l      D0, -8(A6)       ; D0 = output_length

count_next:
    move.b      D4, D1           ; D1 = last_char
    move.l      1, D2            ; D2 = curr_length
    jmp         count_loop

count_end:
    move.l      -8(A6), D0       ; D0 = output_length
    add.b       2, D0
    cmp.b       62, D0           ; 62+2 = MAX_OUTPUT_LEN
    bgt         fail_overflow
    move.l      D0, -8(A6)       ; D0 = output_length

; ---- pass 3: same compression again, this time emits pairs to the port ----
    movea.l     buffer_addr, A3  ; A3 = read pointer into buffer, reset
    movea.l     (A3), A3
    clr.l       D2               ; D2 = curr_length

emit_loop:
    move.b      (A3)+, D4        ; D4 = curr_char
    cmp.b       10, D4           ; 10 = EOL
    beq         emit_end
    cmp.b       0, D2            ; D2 = curr_length
    beq         emit_next

    cmp.b       D1, D4           ; D1 = last_char
    bne         emit_flush
    cmp.b       9, D2            ; 9 = MAX_COMPRESSION_SIZE
    beq         emit_flush
    add.b       1, D2            ; (D2 = curr_length)++
    jmp         emit_loop

emit_flush:
    jsr         flush_pair

emit_next:
    move.b      D4, D1           ; D1 = last_char
    move.l      1, D2            ; D2 = curr_length
    jmp         emit_loop

emit_end:
    jsr         flush_pair       ; flush the last pending run
    jmp         exit

; flush_pair: writes "count char" (D2 + D1) directly to output port A1.
flush_pair:
    move.l      D2, D3           ; D3 = counter
    add.l       48, D3           ; 48 - ASCII shift
    move.b      D3, (A1)         ; write counter to port
    move.b      D1, (A1)         ; write char to port
    rts

fail_overflow:
    move.l      0xcccccccc, (A1)
    jmp         exit

fail_eof:
    move.l      0xffffffff, (A1)

exit:
    unlk        A6
    rts
