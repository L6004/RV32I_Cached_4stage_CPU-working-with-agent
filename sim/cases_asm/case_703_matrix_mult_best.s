    .text
    .align  2
    .global _start
_start:
    li      sp,0x80040000
    call    test_main
    j       _custom_exit
    .align  2
    .global mmc_blocked
mmc_blocked:
    addi    sp,sp,-48
    sw      s1,40(sp)
    sw      s4,28(sp)
    sw      s5,24(sp)
    li      s1,4096
    lui     t5,%hi(A+64)
    lui     s5,%hi(B)
    lui     s4,%hi(C)
    sw      s2,36(sp)
    sw      s6,20(sp)
    sw      s0,44(sp)
    sw      s3,32(sp)
    sw      s7,16(sp)
    sw      s8,12(sp)
    sw      s9,8(sp)
    addi    t5,t5,%lo(A+64)
    li      s2,0
    addi    s5,s5,%lo(B)
    addi    s4,s4,%lo(C)
    addi    s1,s1,-2048
    li      s6,32
.L4:
    slli    t6,s2,7
    add     t6,s4,t6
    li      t2,0
    addi    t6,t6,64
.L14:
    slli    s7,t2,2
    add     s8,t6,s7
    mv      s3,t5
    add     s7,s5,s7
    li      s0,0
.L12:
    slli    t0,s0,7
    add     t0,t0,s7
    mv      a6,s3
    mv      t3,s8
    add     s9,s3,s1
.L10:
    addi    a7,t3,-64
    mv      t1,t0
    addi    t4,a6,-64
.L8:
    mv      a4,t4
    mv      a3,t1
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
    lw      a5,0(a7)
    addi    a7,a7,4
    addi    t1,t1,4
    add     a5,a5,a1
    sw      a5,-4(a7)
    bne     a7,t3,.L8
    addi    a6,a4,128
    addi    t3,a7,128
    bne     a6,s9,.L10
    addi    s0,s0,16
    addi    s3,s3,64
    bne     s0,s6,.L12
    addi    t2,t2,16
    bne     t2,s0,.L14
    addi    s2,s2,16
    add     t5,t5,s1
    bne     s2,t2,.L4
    lw      s0,44(sp)
    lw      s1,40(sp)
    lw      s2,36(sp)
    lw      s3,32(sp)
    lw      s4,28(sp)
    lw      s5,24(sp)
    lw      s6,20(sp)
    lw      s7,16(sp)
    lw      s8,12(sp)
    lw      s9,8(sp)
    addi    sp,sp,48
    jr      ra
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
.L18:
    mv      a4,t5
    mv      a5,t5
.L19:
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
    bne     a5,t4,.L19
    addi    t5,t5,1
    addi    t3,t3,127
    addi    t1,t1,127
    addi    a7,a7,127
    addi    t4,a5,1
    bne     t5,t6,.L18
    tail    mmc_blocked
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
