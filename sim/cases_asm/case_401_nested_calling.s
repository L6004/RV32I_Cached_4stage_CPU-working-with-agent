# Simple nested calling case

    .text
    .align  2
    .global _start
_start:
    li sp, 0x80040000   # stack initialization
    li a0, 5
    jal ra, func_A      # call func_A

    li t0, 0x80002014
    sw a0, 0(t0)        # save result
    j _custom_exit

func_A:
    addi sp, sp, -16
    sw ra, 12(sp)       # push ra
    
    addi a0, a0, 10
    jal ra, func_B      # call func_B
    
    lw ra, 12(sp)       # pop ra
    addi sp, sp, 16
    jalr x0, 0(ra)      # return

func_B:
    addi a0, a0, 100
    jalr x0, 0(ra)      # return func_A

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
