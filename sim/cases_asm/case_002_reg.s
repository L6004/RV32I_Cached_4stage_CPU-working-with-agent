# Reg case: traversing all registers

    .text
    .align  2
    .global _start
_start:
    lui x1, 0x80002

    li x2, 0x2026
    sw x2, 0(x1)
    lw x2, 0(x1)
    addi x1, x1, 4

    li x3, 0x2027
    sw x3, 0(x1)
    lw x3, 0(x1)

    li x4, 0x2028
    sw x4, 4(x1)
    lw x4, 4(x1)
    addi x1, x1, 8

    li x5, 0x2029
    sw x5, 0(x1)
    lw x5, 0(x1)

    li x6, 0x2030
    sw x6, 4(x1)
    lw x6, 4(x1)

    li x7, 0x2031
    sw x7, 8(x1)
    lw x7, 8(x1)
    addi x1, x1, 12

    li x8, 0x2032
    sw x8, 0(x1)
    lw x8, 0(x1)

    li x9, 0x2033
    sw x9, 4(x1)
    lw x9, 4(x1)

    li x10, 0x2034
    sw x10, 8(x1)
    lw x10, 8(x1)

    li x11, 0x2035
    sw x11, 12(x1)
    lw x11, 12(x1)
    addi x1, x1, 16

    li x12, 0x2036
    sw x12, 0(x1)
    lw x12, 0(x1)

    li x13, 0x2037
    sw x13, 4(x1)
    lw x13, 4(x1)

    li x14, 0x2038
    sw x14, 8(x1)
    lw x14, 8(x1)

    li x15, 0x2039
    sw x15, 12(x1)
    lw x15, 12(x1)

    li x16, 0x2040
    sw x16, 16(x1)
    lw x16, 16(x1)
    addi x1, x1, 20

    li x17, 0x2041
    sw x17, 0(x1)
    lw x17, 0(x1)

    li x18, 0x2042
    sw x18, 4(x1)
    lw x18, 4(x1)

    li x19, 0x2043
    sw x19, 8(x1)
    lw x19, 8(x1)

    li x20, 0x2044
    sw x20, 12(x1)
    lw x20, 12(x1)

    li x21, 0x2045
    sw x21, 16(x1)
    lw x21, 16(x1)

    li x22, 0x2046
    sw x22, 20(x1)
    lw x22, 20(x1)
    addi x1, x1, 24

    li x23, 0x2047
    sw x23, 0(x1)
    lw x23, 0(x1)

    li x24, 0x2048
    sw x24, 4(x1)
    lw x24, 4(x1)

    li x25, 0x2049
    sw x25, 8(x1)
    lw x25, 8(x1)

    li x26, 0x2050
    sw x26, 12(x1)
    lw x26, 12(x1)

    li x27, 0x2051
    sw x27, 16(x1)
    lw x27, 16(x1)

    li x28, 0x2052
    sw x28, 20(x1)
    lw x28, 20(x1)

    li x29, 0x2053
    sw x29, 24(x1)
    lw x29, 24(x1)
    addi x1, x1, 28

    li x30, 0x2054
    sw x30, 0(x1)
    lw x30, 0(x1)
    addi x1, x1, 4

    li x31, 0x2055
    sw x31, 0(x1)
    lw x31, 0(x1)

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
