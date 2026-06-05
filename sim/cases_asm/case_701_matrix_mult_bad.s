    .text
    .align  2
    .global _start
_start:
    li      sp,0x80040000
    call    test_main
    j       _custom_exit
    .align  2
    .global mma_standard
mma_standard:
    li      a4,4096
    lui     a5,%hi(A)
    addi    a5,a5,%lo(A)
    addi    a4,a4,128
    lui     t6,%hi(C)
    lui     t0,%hi(B)
    lui     t3,%hi(B+128)
    addi    a6,a5,128
    addi    t6,t6,%lo(C)
    add     t5,a5,a4
    addi    t0,t0,%lo(B)
    addi    t3,t3,%lo(B+128)
.L4:
    mv      a7,t0
    mv      t1,t6
    addi    t4,a6,-128
.L8:
    mv      a4,t4
    mv      a3,a7
    li      a1,0
.L5:
    lw      a2,0(a4)
    lw      a5,0(a3)
    li      a0,0
    beqz    a5,2f
1:
    add     a0,a0,a2
    addi    a5,a5,-1
    bnez    a5,1b
2:
    addi    a4,a4,4
    add     a1,a1,a0
    addi    a3,a3,128
    bne     a4,a6,.L5
    sw      a1,0(t1)
    addi    a7,a7,4
    addi    t1,t1,4
    bne     a7,t3,.L8
    addi    a6,a4,128
    addi    t6,t6,128
    bne     a6,t5,.L4
    ret
    .align  2
    .global test_main
test_main:
    lui     t3,%hi(A)
    lui     t1,%hi(B)
    lui     a7,%hi(C)
    addi    t3,t3,%lo(A)
    addi    t1,t1,%lo(B)
    addi    a7,a7,%lo(C)
    li      t4,128
    li      t5,0
    li      t6,32
.L11:
    mv      a4,t5
    mv      a5,t5
.L12:
    add     a0,t3,a5
    andi    a6,a4,15
    add     a2,t1,a5
    andi    a1,a5,15
    add     a3,a7,a5
    sw      a6,0(a0)
    sw      a1,0(a2)
    sw      zero,0(a3)
    addi    a5,a5,4
    addi    a4,a4,1
    bne     a5,t4,.L12
    addi    t5,t5,1
    addi    t3,t3,127
    addi    t1,t1,127
    addi    a7,a7,127
    addi    t4,a5,1
    bne     t5,t6,.L11
    tail    mma_standard
    .global C
    .global B
    .global A
    .bss
    .align  2
C:
    .zero   4096
B:
    .zero   4096
A:
    .zero   4096
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
