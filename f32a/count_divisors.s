\ count_divisors for f32a

    .data
input_addr:  .word  0x80        \ port in
output_addr: .word  0x84        \ port out
div_cell:    .word  0x08        \ scratch cell for +/, value == own address (see _start)
n_var:       .word  0           \ input number
i_var:       .word  0           \ divisor candidate, 1..n
count_var:   .word  0           \ divisors found so far

    .text
    .org         0x88            \ 0x80..0x87 belong to the io ports
_start:
    @p div_cell b!              \ B <- address of div_cell (self-referential trick)

    @p input_addr a! @          \ n:[]
    dup
    !p n_var                    \ n_var <- n, one copy stays on stack

    inv 1 +                     \ -n:[]
    -if check_fail              \ if -n >= 0 (n <= 0) -> error

    1 !p i_var                  \ i_var <- 1
    0 !p count_var               \ count_var <- 0

count_loop:
    @p n_var                    \ n:[]
    @p i_var                    \ n:i:[]
    inv 1 +                     \ n:(-i):[]
    +                            \ (n-i):[]
    -if count_body                \ if (n-i)>=0 (i<=n) -> body
    count_exit ;                  \ else i>n, done

count_body:
    @p i_var                    \ i:[]
    !b                            \ mem[B] <- i (divisor for this step)

    @p n_var                    \ n:[]
    a!                            \ A <- n (dividend)
    0 0                           \ T=0 S=0 (quotient:remainder)
    31 >r
mod_loop:
    +/
    next mod_loop
    drop                          \ drop quotient T, keep remainder S

    if mod_hit                    \ remainder == 0 -> divisor found
    count_next ;                   \ else skip increment
mod_hit:
    @p count_var
    1 +
    !p count_var

count_next:
    @p i_var
    1 +
    !p i_var
    count_loop ;

count_exit:
    @p count_var
    @p output_addr a! !
    halt

check_fail:
    -1
    @p output_addr a! !
    halt
