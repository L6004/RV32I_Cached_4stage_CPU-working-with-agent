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
    sw      s7,16(sp)
    lui     s7,%hi(.LANCHOR0)
    sw      s8,12(sp)
    addi    s7,s7,%lo(.LANCHOR0)
    lui     s8,%hi(.LANCHOR0+256)
    sw      s1,40(sp)
    sw      s9,8(sp)
    sw      s0,44(sp)
    sw      s2,36(sp)
    sw      s3,32(sp)
    sw      s4,28(sp)
    sw      s5,24(sp)
    sw      s6,20(sp)
    li      s1,0
    addi    s8,s8,%lo(.LANCHOR0+256)
    addi    s9,s7,384
    li      t3,8
.L4:
    mv      s5,s1
    addi    s1,s1,4
    slli    s6,s1,5
    mv      s2,s8
    add     s6,s9,s6
    li      t2,0
.L15:
    mv      s3,t2
    mv      t0,s7
    addi    t2,t2,4
    mv      s4,s6
    li      t4,0
.L13:
    mv      s0,t4
    mv      t6,s4
    addi    t4,t4,4
    mv      t5,s5
.L11:
    slli    t1,t5,5
    add     t1,t1,s2
    mv      a7,s3
.L9:
    slli    a3,a7,2
    add     a3,a3,t0
    mv      a1,t6
    mv      a4,s0
    li      a0,0
.L6:
    lw      a2,0(a1)
    lw      a5,0(a3)
    li      a6,0
    beqz    a5,2f
1:
    add     a6,a6,a2
    addi    a5,a5,-1
    bnez    a5,1b
2:
    addi    a4,a4,1
    add     a0,a0,a6
    beq     t4,a4,.L5
    addi    a1,a1,4
    addi    a3,a3,32
    bne     a4,t3,.L6
.L5:
    lw      a5,0(t1)
    addi    a7,a7,1
    add     a0,a5,a0
    sw      a0,0(t1)
    beq     t2,a7,.L7
    addi    t1,t1,4
    bne     a7,t3,.L9
.L7:
    addi    t5,t5,1
    beq     s1,t5,.L8
    addi    t6,t6,32
    bne     t5,t3,.L11
.L8:
    addi    s4,s4,16
    addi    t0,t0,128
    bne     t4,t3,.L13
    addi    s2,s2,16
    bne     t2,t4,.L15
    bne     s1,t2,.L4
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
    lui     a6,%hi(.LANCHOR0)
    addi    a7,a6,%lo(.LANCHOR0)
    addi    a6,a6,%lo(.LANCHOR0)
    addi    a7,a7,512
    addi    t1,a6,256
    li      t3,32
    li      t4,0
    li      t5,8
.L19:
    mv      a4,t4
    mv      a5,t4
.L20:
    add     a0,a7,a5
    add     a2,a6,a5
    andi    a1,a5,15
    add     a3,t1,a5
    sw      a4,0(a0)
    sw      a1,0(a2)
    sw      zero,0(a3)
    addi    a5,a5,4
    addi    a4,a4,1
    bne     a5,t3,.L20
    addi    t4,t4,1
    addi    a7,a7,31
    addi    a6,a6,31
    addi    t1,t1,31
    addi    t3,a5,1
    bne     t4,t5,.L19
    tail    mmc_blocked
    .global C
    .global B
    .global A
    .bss
    .align  2
    .set    .LANCHOR0,.+0
B:
    .zero   256
C:
    .zero   256
A:
    .zero   256
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
