# Smoke case: basic function and hazard handling

    .text
    .align  2
    .global _start
_start:
    addi x1, x0, 1      # x1 = 1
    addi x1, x1, 1      # x1 = 2
    addi x1, x1, 2      # x1 = 4
    addi x1, x1, 3      # x1 = 7
    addi x2, x0, 4      # x2 = 4
    add x3, x1, x2      # x3 = x1 + x2 = 11 (0xB)
    sub x7, x2, x1      # x7 = x2 - x1 = -3
    addi x5, x0, 0      # x5 = 0
    lui x5, 0x80002     # x5 = 0x80002000
    addi x5, x5, 4      # x5 = 0x80002004
    addi x5, x5, 4      # x5 = 0x80002008
    sw x5, 0(x5)        # data_seg[8] = 8
    lw x5, 0(x5)        # x5 = data_seg[8] = 8

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
