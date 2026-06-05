    .text
    .align  2
    .global _start
_start:
    li      sp,0x80040000
    call    test_main
    j       _custom_exit
    .align  2
    .global test_main
test_main:
    lui     a4,%hi(arr)
    addi    a4,a4,%lo(arr)
    li      a5,0
    li      a3,16384
.L4:
    sw      a5,0(a4)
    addi    a5,a5,1
    addi    a4,a4,4
    bne     a5,a3,.L4
    li      t0,4
    la      t1,arr
    li      t2,16384
    li      t3,131
    li      t4,0
    li      a4,0
1:
    li      t5,0
2:
    slli    t6,t4,2
    add     t6,t1,t6
    lw      t6,0(t6)
    add     a4,a4,t6
    add     t4,t4,t3
    li      t6,0x3FFF
    and     t4,t4,t6
    addi    t5,t5,1
    blt     t5,t2,2b
    addi    t0,t0,-1
    bnez    t0,1b
    li      a5,-2147459072
    sw      a4,-16(a5)
    ret
    .global arr
    .bss
    .align  2
arr:
    .zero   65536
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
