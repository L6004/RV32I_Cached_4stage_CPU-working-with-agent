    .text
    .align  2
    .global _start
_start:
    li      sp,0x80040000
    call    test_main
    j       _custom_exit
    .align  2
    .global nCr
nCr:
    beq     a1,zero,.L63
    beq     a0,a1,.L63
    addi    sp,sp,-144
    sw      s2,128(sp)
    sw      s3,124(sp)
    sw      ra,140(sp)
    li      a4,1
    addi    s2,a0,-1
    li      s3,0
    li      a5,1
    bne     a1,a4,.L111
.L7:
    addi    s3,s3,1
    beq     s2,a5,.L11
    addi    s2,s2,-1
    j       .L7
.L63:
    li      a0,1
    ret
.L111:
    sw      s0,136(sp)
    sw      s5,116(sp)
    mv      s0,a1
    li      s5,1
.L8:
    addi    a5,s2,1
    beq     s0,a5,.L112
.L82:
    sw      s10,96(sp)
    addi    a5,s0,-3
    addi    s10,s0,-2
    sw      s1,132(sp)
    sw      s6,112(sp)
    sw      s7,108(sp)
    sw      s8,104(sp)
    sw      s9,100(sp)
    mv      s1,s10
    sw      s4,120(sp)
    mv      s9,s2
    li      s6,0
    mv      s7,s3
    mv      s10,s2
    mv      s8,a5
.L18:
    li      a5,2
    mv      s4,s9
    addi    s9,s9,-1
    beq     s0,a5,.L65
    mv      s3,s9
    li      s2,0
    li      a5,3
    beq     s9,s1,.L65
    sw      s11,92(sp)
.L24:
    addi    s3,s3,-1
    beq     s0,a5,.L19
    addi    a5,s0,-9
    sw      a5,16(sp)
    mv      s11,s7
    mv      s7,s8
    mv      a3,s10
    mv      a4,s9
    mv      a5,s6
    addi    s8,s0,-4
    mv      s6,s4
    mv      s9,s3
    li      s10,0
    li      a2,4
    beq     s3,s7,.L113
.L30:
    addi    s9,s9,-1
    beq     s0,a2,.L25
    mv      s4,s9
    mv      a6,a3
    mv      a1,a5
    mv      a3,s1
    mv      a5,s6
    mv      s1,s8
    mv      s6,s0
    mv      a0,a4
    mv      a2,s3
    mv      s9,s11
    mv      s8,s10
    addi    s11,s6,-5
    mv      s3,s4
    li      s0,0
    li      a4,5
    beq     s4,s1,.L114
.L37:
    addi    s3,s3,-1
    beq     s6,a4,.L32
    mv      t3,a6
    mv      t1,a0
    mv      a4,s4
    mv      a7,s7
    mv      s4,s1
    mv      s7,s2
    addi    s10,s6,-6
    mv      s2,s0
    mv      a0,s8
    mv      a6,s9
    mv      s1,s3
    li      s0,0
    li      t4,6
    beq     s3,s11,.L115
.L44:
    addi    s1,s1,-1
    beq     s6,t4,.L39
    mv      t6,t3
    addi    s9,s6,-7
    addi    s8,s6,-8
    mv      t3,s1
    li      t5,0
    beq     s1,s10,.L116
.L51:
    li      t4,7
    addi    t3,t3,-1
    beq     s6,t4,.L46
    mv      t2,t6
    mv      t0,t1
    mv      t6,s1
    mv      t1,t3
    li      t4,0
    beq     t3,s9,.L117
.L58:
    li      s1,8
    addi    t1,t1,-1
    beq     s6,s1,.L53
    sw      zero,12(sp)
    beq     t1,s8,.L118
.L104:
    sw      a5,68(sp)
    mv      a5,s8
    sw      t2,20(sp)
    mv      s8,s6
    sw      t0,24(sp)
    mv      s6,s4
    sw      a1,28(sp)
    mv      s4,s0
    sw      a2,32(sp)
    sw      a4,36(sp)
    sw      a0,40(sp)
    sw      t6,44(sp)
    sw      a6,48(sp)
    sw      t4,52(sp)
    sw      t1,56(sp)
    sw      t5,60(sp)
    sw      t3,64(sp)
    sw      a3,72(sp)
    mv      s0,t1
    sw      a7,76(sp)
    mv      s1,a5
.L60:
    lw      a1,16(sp)
    addi    s0,s0,-1
    mv      a0,s0
    call    nCr
    lw      a5,12(sp)
    add     a5,a5,a0
    sw      a5,12(sp)
    bne     s0,s1,.L60
    mv      s0,s4
    mv      s4,s6
    mv      s6,s8
    mv      s8,s1
    lw      s1,12(sp)
    lw      t4,52(sp)
    lw      t1,56(sp)
    addi    s1,s1,1
    lw      t2,20(sp)
    lw      t0,24(sp)
    lw      a1,28(sp)
    lw      a2,32(sp)
    lw      a4,36(sp)
    lw      a0,40(sp)
    lw      t6,44(sp)
    lw      a6,48(sp)
    lw      t5,60(sp)
    lw      t3,64(sp)
    lw      a5,68(sp)
    lw      a3,72(sp)
    lw      a7,76(sp)
    add     t4,t4,s1
    beq     t1,s9,.L56
.L91:
    addi    t1,t1,-1
    sw      zero,12(sp)
    bne     t1,s8,.L104
.L118:
    addi    t4,t4,1
    bne     t1,s9,.L91
.L56:
    addi    t4,t4,1
    add     t5,t5,t4
    beq     t3,s10,.L103
.L90:
    addi    t3,t3,-1
    mv      t1,t3
    li      t4,0
    bne     t3,s9,.L58
.L117:
    addi    t5,t5,1
    bne     t3,s10,.L90
.L103:
    mv      s1,t6
    mv      t1,t0
    mv      t6,t2
.L49:
    addi    t5,t5,1
    add     s0,s0,t5
    beq     s1,s11,.L101
.L89:
    addi    s1,s1,-1
    mv      t3,s1
    li      t5,0
    bne     s1,s10,.L51
.L116:
    addi    s0,s0,1
    bne     s1,s11,.L89
.L101:
    mv      t3,t6
.L42:
    addi    s0,s0,1
    add     s2,s2,s0
    beq     s3,s4,.L99
.L88:
    addi    s3,s3,-1
    mv      s1,s3
    li      s0,0
    li      t4,6
    bne     s3,s11,.L44
.L115:
    addi    s2,s2,1
    bne     s3,s4,.L88
.L99:
    mv      s8,a0
    mv      s0,s2
    mv      s9,a6
    mv      s2,s7
    mv      s1,s4
    mv      a0,t1
    mv      a6,t3
    mv      s4,a4
    mv      s7,a7
.L35:
    addi    s0,s0,1
    add     s8,s8,s0
    beq     s4,s7,.L97
.L87:
    addi    s4,s4,-1
    addi    s11,s6,-5
    mv      s3,s4
    li      s0,0
    li      a4,5
    bne     s4,s1,.L37
.L114:
    addi    s8,s8,1
    bne     s4,s7,.L87
.L97:
    mv      s10,s8
    mv      s1,a3
    addi    s10,s10,1
    mv      s3,a2
    mv      s0,s6
    mv      a4,a0
    mv      s6,a5
    mv      s11,s9
    mv      a3,a6
    mv      a5,a1
    add     s2,s2,s10
    beq     s3,s1,.L95
.L86:
    addi    s3,s3,-1
    addi    s8,s0,-4
    mv      s9,s3
    li      s10,0
    li      a2,4
    bne     s3,s7,.L30
.L113:
    addi    s2,s2,1
    bne     s3,s1,.L86
.L95:
    mv      s8,s7
    mv      s7,s11
    lw      s11,92(sp)
    mv      s4,s6
    mv      s10,a3
    mv      s9,a4
    mv      s6,a5
    addi    s2,s2,1
.L121:
    add     s6,s6,s2
    bne     s0,s4,.L18
    addi    a5,s6,1
    mv      s2,s10
    add     s3,s7,a5
    beq     s0,s10,.L119
.L85:
    addi    s2,s2,-1
    addi    a5,s2,1
    lw      s1,132(sp)
    lw      s4,120(sp)
    lw      s6,112(sp)
    lw      s7,108(sp)
    lw      s8,104(sp)
    lw      s9,100(sp)
    lw      s10,96(sp)
    bne     s0,a5,.L82
.L112:
    addi    s3,s3,1
    beq     s0,s2,.L120
    addi    s2,s2,-1
    j       .L8
.L53:
    addi    t4,t4,1
    bne     t1,s5,.L58
    addi    t4,t4,1
    add     t5,t5,t4
    bne     t3,s10,.L90
    j       .L103
.L32:
    addi    s0,s0,1
    bne     s3,s5,.L37
    j       .L35
.L39:
    addi    s0,s0,1
    bne     s1,s5,.L44
    j       .L42
.L25:
    addi    s10,s10,1
    bne     s9,s5,.L30
    addi    s10,s10,1
    add     s2,s2,s10
    bne     s3,s1,.L86
    j       .L95
.L46:
    addi    t5,t5,1
    bne     t3,s5,.L51
    j       .L49
.L19:
    addi    s2,s2,1
    bne     s3,s5,.L24
    lw      s11,92(sp)
    addi    s2,s2,1
    j       .L121
.L65:
    li      s2,1
    add     s6,s6,s2
    bne     s0,s4,.L18
    addi    a5,s6,1
    mv      s2,s10
    add     s3,s7,a5
    bne     s0,s10,.L85
.L119:
    lw      s0,136(sp)
    lw      s1,132(sp)
    lw      s4,120(sp)
    lw      s5,116(sp)
    lw      s6,112(sp)
    lw      s7,108(sp)
    lw      s8,104(sp)
    lw      s9,100(sp)
    lw      s10,96(sp)
.L11:
    lw      ra,140(sp)
    lw      s2,128(sp)
    addi    a0,s3,1
    lw      s3,124(sp)
    addi    sp,sp,144
    jr      ra
.L120:
    lw      s0,136(sp)
    lw      s5,116(sp)
    j       .L11
    .align  2
    .global test_main
test_main:
    addi    sp,sp,-16
    li      a1,2
    li      a0,4
    sw      ra,12(sp)
    sw      s0,8(sp)
    call    nCr
    mv      s0,a0
    li      a1,2
    li      a0,3
    call    nCr
    add     s0,s0,a0
    addi    s0,s0,1
    li      a5,-2147475456
    lw      ra,12(sp)
    sw      s0,24(a5)
    lw      s0,8(sp)
    addi    sp,sp,16
    jr      ra
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
