# Hazards coverage case

    .text
    .align  2
    .global _start
_start:
    li x1, 10
    li x2, 20

    # 1. RAW (Data Hazard)
    add x3, x1, x2      # write x3
    sub x4, x3, x1      # read x3 (WB/MEM forwarding)
    and x5, x4, x3      # continuous RAW

    # 2. Load-Use Hazard
    la t0, my_data
    lw x6, 0(t0)        # load
    add x7, x6, x1      # use (1 cycle stall needed)

    # 3. branch Flush 
    li x8, 5
forced_jump:
    addi x8, x8, -1
    bne x8, x0, forced_jump    # forced jump -> flush

    # save special value to data segment
    li t0, 0x8000200C
    sw x7, 0(t0)

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

    .data
my_data:
    .word 0xDEADBEEF
