    .text
    .align  2
    .global _start
_start:
    li      t0,-4096
    add     sp,sp,t0
    li      sp,0x80040000
    li      a5,-4096
    addi    a5,a5,8
    li      a4,4096
    add     a4,a4,a5
    li      a1,4096
    add     a5,a4,sp
    add     a1,a1,sp
    li      a4,1
    li      a3,0
.L2:
    mv      a2,a4
    add     a4,a4,a3
    sw      a4,0(a5)
    addi    a5,a5,4
    mv      a3,a2
    bne     a1,a5,.L2
    li      a4,4096
    addi    a4,a4,-4
    add     a4,a4,sp
    lw      a4,0(a4)
    li      a5,-2147459072
    li      t0,4096
    sw      a4,-16(a5)
    add     sp,sp,t0
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
