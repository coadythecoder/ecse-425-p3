main:
    addi x1, x0, 10
    addi x2, x0, 3
    add  x3, x1, x2
    sub  x4, x1, x2
    mul  x5, x1, x2
    and  x6, x1, x2
    or   x7, x1, x2
    sll  x8, x1, x2
    srl  x9, x8, x2
    addi x10, x0, 7
    sw   x10, 4(x0)
    lw   x11, 4(x0)
    beq  x11, x10, skip
    addi x12, x0, 99
skip:
    bne  x0, x0, loop
    addi x13, x0, 1
loop:
    jal  x14, loop
