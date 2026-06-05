    .text
    .align  2
    .global _start
_start:

# --- INIT REGISTERS ---
    addi x1, x0, 85
    addi x2, x0, 84
    addi x3, x0, 54
    addi x4, x0, 6
    addi x5, x0, 27
    addi x6, x0, 91
    addi x7, x0, 23
    addi x8, x0, 78
    addi x9, x0, 66
    addi x10, x0, 73
    addi x11, x0, 34
    addi x12, x0, 61
    addi x13, x0, 78
    addi x14, x0, 88
    addi x15, x0, 8
    addi x16, x0, 47
    addi x17, x0, 33
    addi x18, x0, 27
    addi x19, x0, 27
    addi x20, x0, 5
    addi x21, x0, 25
    addi x22, x0, 78
    addi x23, x0, 17
    addi x24, x0, 50
    addi x25, x0, 0
    addi x26, x0, 9
    addi x27, x0, 61
    addi x28, x0, 40
    addi x29, x0, 11
    addi x30, x0, 86
    addi x31, x0, 64

# --- RANDOM INSTRUCTIONS ---
    sll x10, x20, x26
    lui x4, 0x80002
    sw x27, 384(x4)
    lw x3, 384(x4)
    addi x30, x17, 1590
    lui x25, 0x80002
    sw x11, 32(x25)
    lw x17, 32(x25)
    lui x26, 0x80002
    sw x14, 380(x26)
    lw x2, 380(x26)
    ori x22, x31, 1582
    srli x13, x31, 11
    lui x13, 0x80002
    sw x6, 116(x13)
    lw x26, 116(x13)
    lui x24, 0x80002
    sw x1, 336(x24)
    lw x21, 336(x24)
    lui x1, 0x80002
    sw x21, 336(x1)
    lw x29, 336(x1)
    lui x29, 0x80002
    sw x8, 172(x29)
    lw x16, 172(x29)
    add x30, x10, x8
    lui x13, 0x80002
    sw x29, 120(x13)
    lw x28, 120(x13)
    srl x27, x4, x13
    lui x16, 0x80002
    sw x31, 392(x16)
    lw x6, 392(x16)
    lui x20, 0x80002
    sw x1, 244(x20)
    lw x4, 244(x20)
    xori x16, x29, -331
    lui x24, 0x80002
    sw x31, 380(x24)
    lw x11, 380(x24)
    lui x17, 0x80002
    sw x24, 296(x17)
    lw x19, 296(x17)
    andi x25, x12, -1354
    lui x8, 0x80002
    sw x6, 292(x8)
    lw x7, 292(x8)
    lui x23, 0x80002
    sw x4, 132(x23)
    lw x5, 132(x23)
    srai x29, x4, 9
    lui x17, 0x80002
    sw x30, 72(x17)
    lw x21, 72(x17)
    srli x12, x11, 27
    lui x13, 0x80002
    sw x20, 280(x13)
    lw x28, 280(x13)
    andi x29, x22, 188
    lui x29, 0x80002
    sw x15, 188(x29)
    lw x6, 188(x29)
    lui x26, 0x80002
    sw x14, 180(x26)
    lw x28, 180(x26)
    lui x9, 0x80002
    sw x8, 96(x9)
    lw x16, 96(x9)
    addi x19, x25, 1010
    and x9, x28, x13
    sub x14, x13, x30
    lui x25, 0x80002
    sw x6, 276(x25)
    lw x15, 276(x25)
    slli x30, x21, 9
    lui x20, 0x80002
    sw x28, 292(x20)
    lw x9, 292(x20)
    sll x14, x27, x16
    slli x19, x18, 11
    slli x21, x26, 18
    or x20, x19, x5
    lui x17, 0x80002
    sw x24, 348(x17)
    lw x18, 348(x17)
    xori x30, x17, -1765
    addi x26, x5, -170
    lui x31, 0x80002
    sw x16, 44(x31)
    lw x27, 44(x31)
    srli x3, x12, 21
    slli x1, x26, 15
    xori x22, x5, -1720
    xori x3, x24, -1349
    lui x7, 0x80002
    sw x31, 284(x7)
    lw x26, 284(x7)
    lui x23, 0x80002
    sw x15, 8(x23)
    lw x12, 8(x23)
    lui x23, 0x80002
    sw x4, 292(x23)
    lw x2, 292(x23)
    lui x1, 0x80002
    sw x15, 200(x1)
    lw x23, 200(x1)
    lui x13, 0x80002
    sw x6, 20(x13)
    lw x26, 20(x13)
    lui x1, 0x80002
    sw x29, 348(x1)
    lw x16, 348(x1)
    lui x1, 0x80002
    sw x3, 272(x1)
    lw x14, 272(x1)
    lui x14, 0x80002
    sw x30, 180(x14)
    lw x20, 180(x14)
    and x2, x21, x25
    lui x26, 0x80002
    sw x28, 268(x26)
    lw x25, 268(x26)
    ori x3, x23, -2036
    lui x12, 0x80002
    sw x31, 372(x12)
    lw x17, 372(x12)
    lui x30, 0x80002
    sw x4, 388(x30)
    lw x11, 388(x30)
    lui x16, 0x80002
    sw x22, 400(x16)
    lw x8, 400(x16)
    lui x23, 0x80002
    sw x16, 36(x23)
    lw x14, 36(x23)
    lui x29, 0x80002
    sw x30, 372(x29)
    lw x23, 372(x29)
    srli x14, x1, 20
    lui x14, 0x80002
    sw x28, 132(x14)
    lw x19, 132(x14)
    add x29, x10, x25
    lui x18, 0x80002
    sw x28, 44(x18)
    lw x11, 44(x18)
    and x15, x4, x14
    lui x12, 0x80002
    sw x1, 368(x12)
    lw x11, 368(x12)
    ori x12, x22, 444
    lui x27, 0x80002
    sw x6, 20(x27)
    lw x26, 20(x27)
    slli x3, x30, 17
    lui x15, 0x80002
    sw x2, 216(x15)
    lw x17, 216(x15)
    lui x25, 0x80002
    sw x14, 140(x25)
    lw x17, 140(x25)
    sub x4, x10, x26
    xor x5, x22, x16
    lui x22, 0x80002
    sw x9, 20(x22)
    lw x23, 20(x22)
    add x16, x9, x7
    srli x9, x31, 18
    slli x9, x27, 8
    lui x7, 0x80002
    sw x28, 48(x7)
    lw x20, 48(x7)
    and x15, x8, x9
    or x15, x27, x28
    addi x21, x18, 424
    ori x5, x11, 1549
    lui x19, 0x80002
    sw x9, 120(x19)
    lw x26, 120(x19)
    sra x28, x22, x23
    slt x3, x19, x21
    sra x8, x26, x25
    lui x22, 0x80002
    sw x11, 152(x22)
    lw x6, 152(x22)
    addi x30, x24, 602
    srli x11, x21, 7
    addi x6, x19, 1681
    srl x23, x10, x8
    slli x12, x2, 7
    lui x30, 0x80002
    sw x21, 388(x30)
    lw x6, 388(x30)
    or x29, x15, x27
    srl x27, x28, x11
    lui x18, 0x80002
    sw x24, 52(x18)
    lw x17, 52(x18)

# --- EXIT ---
    .text
    .align 2
_custom_exit:    la t0, tohost
    li t1, 1
    sw t1, 0(t0)
end_loop:
    j end_loop
    .section .tohost,"aw",@progbits
    .align 6
    .global tohost
tohost:
    .dword 0
    .global fromhost
fromhost:
    .dword 0
