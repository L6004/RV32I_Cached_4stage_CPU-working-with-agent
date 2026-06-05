# ALU auxiliary signal coverage

    .text
    .align  2
    .global _start
_start:
    # 1. Zero (0)
    li x1, 100
    sub x2, x1, x1   # x2 = 0, zero = 1

    # 2. Negative (-)
    sub x3, x0, x1   # x3 = -100, negative = 1

    # 3. Carry (unsigned overflow)
    li x4, 0xFFFFFFFF
    li x5, 1
    add x6, x4, x5   # x6 = 0, carry = 1

    # 4. Overflow (signed overflow: pos + pos = neg)
    li x7, 0x7FFFFFFF # 最大正数
    add x8, x7, x5    # x8 = 0x80000000 (最小负数), overflow = 1

    # 5. Overflow (signed overflow: neg + neg = pos)
    li x9, 0x80000000
    add x10, x9, x9   # x10 = 0, overflow = 1

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