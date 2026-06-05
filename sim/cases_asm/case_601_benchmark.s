    .text
    .align  2
    .global _start
_start:
    li      sp,0x80040000
    li      a3,100
    li      a2,0
    li      a4,1
    li      a5,0
.L2:
    mv      a1,a4
    addi    a3,a3,-1
    add     a2,a2,a5
    add     a4,a4,a5
    mv      a5,a1
    bne     a3,zero,.L2
    li      a5,-2147475456
    sw      a2,24(a5)
    j       _custom_exit
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
