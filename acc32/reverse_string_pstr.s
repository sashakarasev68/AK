;; reverse_string_pstr for acc32

    .data
    ;; result buffer: [length][reversed line], tail stays '_'
    ;; must start at 0x00, so the data section goes first
pstr_buf:        .byte  '________________________________'
pstr_pad:        .byte  '___'              ; store writes a word (4 bytes), keep room
line_buf:        .byte  '________________________________' ; line as it was read
line_pad:        .byte  '___'
line_len:        .word  0                  ; line length, then loop counter
src_ptr:         .word  0                  ; pointer into line_buf
dst_ptr:         .word  0                  ; pointer into pstr_buf
char:            .word  0                  ; current character
const_1:         .word  1                  ; constant for inc/dec
char_newline:    .word  '\n'               ; end of line
buf_capacity:    .word  0x1F               ; 0x20 minus the length byte
byte_mask:       .word  0xFF               ; low byte of a word
byte_clear_mask: .word  0xFFFFFF00         ; word without its low byte
error_overflow:  .word  0xCCCCCCCC         ; code error of overflow
addr_in:         .word  0x80
addr_out:        .word  0x84
    .text
    .org         0x88                        ; 0x80..0x87 belong to the io ports
_start:
    load_imm     line_buf
    store        src_ptr                     ; write position <- line_buf
    load_imm     0
    store        line_len                    ; nothing read yet
read_loop:
    load         addr_in
    load_acc                                 ; acc = next character
    store        char                        ; save it for checks
    sub          char_newline
    beqz         read_done                   ; if char == '\n': line is over
    load         line_len
    sub          buf_capacity
    bgez         handle_ovf                  ; if line_len >= capacity: go to error
    ; line_buf[line_len] = char: read the word, replace its low byte, write back
    load         src_ptr
    load_acc
    and          byte_clear_mask
    or           char
    store_ind    src_ptr
    load         src_ptr                     ; src_ptr += 1
    add          const_1
    store        src_ptr
    load         line_len                    ; line_len += 1
    add          const_1
    store        line_len
    jmp          read_loop
read_done:
    load_addr    pstr_buf                    ; pstr_buf[0] = line_len
    and          byte_clear_mask
    or           line_len
    store_addr   pstr_buf
    load_imm     line_buf                    ; read from the last character
    add          line_len
    sub          const_1
    store        src_ptr
    load_imm     pstr_buf                    ; write from pstr_buf[1]
    add          const_1
    store        dst_ptr
copy_loop:
    load         line_len                    ; checking the counter
    beqz         exit                        ; if nothing left: stop
    load         src_ptr                     ; char = *src_ptr
    load_acc
    and          byte_mask
    store        char
    load         dst_ptr                     ; *dst_ptr = char
    load_acc
    and          byte_clear_mask
    or           char
    store_ind    dst_ptr
    load         char
    store_ind    addr_out                    ; print the character to 0x84
    load         src_ptr                     ; src_ptr -= 1
    sub          const_1
    store        src_ptr
    load         dst_ptr                     ; dst_ptr += 1
    add          const_1
    store        dst_ptr
    load         line_len                    ; line_len -= 1
    sub          const_1
    store        line_len
    jmp          copy_loop
handle_ovf:
    load         error_overflow
    store_ind    addr_out                    ; output error of overflow
    jmp          exit
exit:
    halt
