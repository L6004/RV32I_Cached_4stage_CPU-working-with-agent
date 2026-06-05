# ALU operations case: test all alu operations

    .text
    .align  2
    .global _start
_start:
    # initialization
    li x1, 0x12345678
    li x2, 0x0000FFFF

    # R-Type
    add  x3, x1, x2
    sub  x4, x1, x2
    sll  x5, x1, x2
    slt  x6, x1, x2
    sltu x7, x1, x2
    xor  x8, x1, x2
    srl  x9, x1, x2
    sra  x10, x1, x2
    or   x11, x1, x2
    and  x12, x1, x2

    # I-Type
    addi  x13, x1, -2048
    slli  x14, x1, 15
    slti  x15, x1, 100
    sltiu x16, x1, 100
    xori  x17, x1, 0x5A5
    srli  x18, x1, 8
    srai  x19, x1, 8
    ori   x20, x1, 0x3FF
    andi  x21, x1, 0xFF

# --- exit process ---
    .text
    .align 2
_custom_exit:
    la t0, tohost                  
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
