# Corner case for ISA coverage
# ISA coverage is mainly collected by random case (case_999)

    .text
    .align  2
    .global _start
_start:
    # ==========================================
    # 1. 边界值与基础运算测试 (Boundary & Base ISA)
    # ==========================================
    li x1, 0x00000000   # 0
    li x2, 0x7FFFFFFF   # Max Positive
    li x3, 0x80000000   # Min Negative
    li x4, 0xFFFFFFFF   # -1

    # 边界运算测试
    add  x5, x2, x2     # 0xFFFFFFFE
    sub  x6, x3, x4     # 0x80000001
    slt  x7, x3, x2     # 1 (Min Neg < Max Pos)
    sltu x8, x3, x2     # 0 (Unsigned: 0x80000000 > 0x7FFFFFFF)
    sra  x9, x3, x4     # 算术右移 31 位，结果应全为 1

    # AUIPC 与 LUI 测试
    lui x10, 0x80000
    auipc x11, 0x0      # 获取当前 PC

    # ==========================================
    # 2. B-Type 分支指令全覆盖 (Branch Coverage)
    # 核心策略：每条指令先执行 Not Taken，再执行 Taken
    # ==========================================
    li x12, 10
    li x13, 20
    li x14, -10         # 有符号负数，无符号极大值 (0xFFFFFFF6)

test_beq:
    # BEQ (相等分支)
    beq x12, x13, test_fail   # [Not Taken] (10 != 20) -> 确保能流到 MEM/WB 收集覆盖率
    beq x12, x12, test_bne    # [Taken]     (10 == 10) -> 正常跳转，测试功能
    j test_fail               # 防御性死胡同

test_bne:
    # BNE (不等分支)
    bne x12, x12, test_fail   # [Not Taken] (10 == 10)
    bne x12, x13, test_blt    # [Taken]     (10 != 20)
    j test_fail

test_blt:
    # BLT (有符号小于)
    blt x13, x12, test_fail   # [Not Taken] (20 < 10: False)
    blt x14, x12, test_bge    # [Taken]     (-10 < 10: True)
    j test_fail

test_bge:
    # BGE (有符号大于等于)
    bge x12, x13, test_fail   # [Not Taken] (10 >= 20: False)
    bge x12, x14, test_bltu   # [Taken]     (10 >= -10: True)
    j test_fail

test_bltu:
    # BLTU (无符号小于)
    bltu x14, x12, test_fail  # [Not Taken] (0xFFFFFFF6 < 10: False)
    bltu x12, x13, test_bgeu  # [Taken]     (10 < 20: True)
    j test_fail

test_bgeu:
    # BGEU (无符号大于等于)
    bgeu x12, x14, test_fail       # [Not Taken] (10 >= 0xFFFFFFF6: False)
    bgeu x14, x12, test_not_taken  # [Taken]     (0xFFFFFFF6 >= 10: True)
    j test_fail

test_not_taken:
    beq x12, x13, test_fail   # [Not Taken]
    nop
    nop
    bne x12, x12, test_fail   # [Not Taken]
    nop
    nop
    blt x13, x12, test_fail   # [Not Taken]
    nop
    nop
    bge x12, x13, test_fail   # [Not Taken]
    nop
    nop
    bltu x14, x12, test_fail  # [Not Taken]
    nop
    nop
    bgeu x12, x14, test_fail  # [Not Taken]
    j test_pass

    # ==========================================
    # 3. 测试收尾与结果记录
    # ==========================================
test_fail:
    # 如果任何一个分支指令的逻辑出错，都会跳到这里
    li x15, 0xDEADBEEF
    li x16, 0x80002008
    sw x15, 0(x16)            # 将错误标志写入内存
    j test_end

test_pass:
    # 所有分支逻辑均通过，写入原本的边界测试结果
    li x16, 0x80002008
    sw x9, 0(x16)

# --- exit process ---
test_end:
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
