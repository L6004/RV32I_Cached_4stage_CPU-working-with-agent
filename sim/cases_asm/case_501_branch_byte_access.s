# Branch and data mem byte access coverage case

    .text
    .align  2
    .global _start
_start:
    la a0, string_data  # base address of the string
    li a1, 0            # counter
    
loop_start:
    lb a2, 0(a0)         # byte access
    sb a2, 0(a0)
    beq a2, x0, loop_end # end until '\0'

    # A (0x41)
    li t1, 0x41
    beq a2, t1, is_vowel
    # E (0x45)
    li t1, 0x45
    beq a2, t1, is_vowel
    # I (0x49)
    li t1, 0x49
    beq a2, t1, is_vowel
    # O (0x4F)
    li t1, 0x4F
    beq a2, t1, is_vowel
    # U (0x55)
    li t1, 0x55
    beq a2, t1, is_vowel
    
    j next_char

is_vowel:
    addi a1, a1, 1

next_char:
    addi a0, a0, 1
    j loop_start

loop_end:
    li t0, 0x8000201C
    sw a1, 0(t0)         # save count
    
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
string_data:
    .asciz "IS YU XIN A BADGER OR A RACCOON" 
