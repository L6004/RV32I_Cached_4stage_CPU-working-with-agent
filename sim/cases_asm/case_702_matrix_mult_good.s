    .text
    .align  2
    .global _start
_start:
    li      sp,0x80040000
    call    test_main
    j       _custom_exit
    .align  2
    .global mmb_loop_reorder
mmb_loop_reorder:
    li      a4,4096
    lui     a5,%hi(C)
    addi    a5,a5,%lo(C)
    addi    a4,a4,128
    lui     t5,%hi(A)
    lui     t6,%hi(B)
    lui     t1,%hi(B+4096)
    addi    a0,a5,128
    addi    t5,t5,%lo(A)
    add     t4,a5,a4
    addi    t6,t6,%lo(B)
    addi    t1,t1,%lo(B+4096)
.L4:
    mv      a6,t6
    mv      a7,t5
    addi    t3,a0,-128
.L6:
    lw      a2,0(a7)
    mv      a4,t3
    mv      a3,a6
.L5:
    lw      a5,0(a3)
    li      a1,0
    beqz    a5,2f
1:
    add     a1,a1,a2
    addi    a5,a5,-1
    bnez    a5,1b
2:
    lw      a5,0(a4)
    addi    a4,a4,4
    addi    a3,a3,4
    add     a5,a5,a1
    sw      a5,-4(a4)
    bne     a4,a0,.L5
    addi    a6,a6,128
    addi    a7,a7,4
    bne     a6,t1,.L6
    addi    a0,a4,128
    addi    t5,t5,128
    bne     a0,t4,.L4
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
    tail    mmb_loop_reorder
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
