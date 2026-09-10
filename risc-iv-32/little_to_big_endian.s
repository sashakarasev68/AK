; little_to_big_endian -- reverse the 4 bytes of a 32-bit word (risc-iv-32)
; input:  one word via port 0x80
; output: the same word with its bytes reversed, via port 0x84
; no error cases -- every 32-bit input has a valid output

    .data

in_port:      .word  0x80        ; port in
out_port:     .word  0x84        ; port out
init_sp:      .word  0x1000      ; initial stack pointer

    .text

    .org     0x100               ; 0x80..0x87 are taken by io ports

_start:
    lui      t1, %hi(in_port)
    addi     t1, t1, %lo(in_port)
    lw       t1, 0(t1)
    lw       a0, 0(t1)             ; a0 = input value

    lui      t2, %hi(init_sp)
    addi     t2, t2, %lo(init_sp)
    lw       sp, 0(t2)             ; sp = init_sp

    jal      ra, process_data

    lui      t3, %hi(out_port)
    addi     t3, t3, %lo(out_port)
    lw       t3, 0(t3)
    sw       a0, 0(t3)             ; write result to port
    halt

; process_data: sets up flip_endianness's arguments and calls it.
; a1 = index, a2 = accumulated result, a3 = original value (a0 in)
process_data:
    addi     sp, sp, -4
    sw       ra, 0(sp)

    mv       a1, zero              ; a1 = index = 0
    mv       a2, zero              ; a2 = result = 0
    mv       a3, a0                ; a3 = original value

    jal      ra, flip_endianness

    lw       ra, 0(sp)
    addi     sp, sp, 4
    jr       ra

; flip_endianness: recursive byte reversal, one byte per call.
; base case: a1 == 4 (all 4 bytes consumed) -> a0 = accumulated result
flip_endianness:
    addi     sp, sp, -4
    sw       ra, 0(sp)

    addi     t1, zero, 4           ; t1 = BYTES_IN_WORD
    bne      a1, t1, do_flip_step

    mv       a0, a2                ; base case: return result
    lw       ra, 0(sp)
    addi     sp, sp, 4
    jr       ra

do_flip_step:
    jal      ra, get_byte          ; a0 = byte at index a1

    slli     a2, a2, 8             ; result <<= 8
    or       a2, a2, a0            ; result |= byte

    addi     a1, a1, 1             ; index++
    jal      ra, flip_endianness

    lw       ra, 0(sp)
    addi     sp, sp, 4
    jr       ra

; get_byte: extract byte at index a1 (0=lowest) from value a3
get_byte:
    slli     t1, a1, 3             ; t1 = index * 8
    srl      a0, a3, t1            ; a0 = value >> t1
    andi     a0, a0, 0xFF          ; mask to one byte
    jr       ra
