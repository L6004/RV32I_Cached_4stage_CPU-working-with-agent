#!/usr/bin/python3
import random
import os
import subprocess

def generate_random_test(filename, num_instr=1000):
    regs = [f"x{i}" for i in range(1, 32)] # 排除 x0
    
    with open(filename, 'w') as f:
        # 1. 预处理：安全初始化所有寄存器 (赋予一个小的随机初值)
        f.write("    .text\n")
        f.write("    .align  2\n")
        f.write("    .global _start\n")
        f.write("_start:\n")
        f.write("\n# --- INIT REGISTERS ---\n")
        for reg in regs:
            imm = random.randint(0, 100)
            f.write(f"    addi {reg}, x0, {imm}\n")
            
        # 2. 随机生成有效的主体算术/逻辑指令
        f.write("\n# --- RANDOM INSTRUCTIONS ---\n")
        alu_ops =['add', 'sub', 'sll', 'slt', 'xor', 'srl', 'sra', 'or', 'and']
        imm_ops =['addi', 'slli', 'srli', 'srai', 'xori', 'ori', 'andi']
        
        for _ in range(num_instr):
            op_type = random.choice(['ALU', 'IMM', 'MEM'])
            rd = random.choice(regs)
            rs1 = random.choice(regs)
            rs2 = random.choice(regs)
            
            if op_type == 'ALU':
                f.write(f"    {random.choice(alu_ops)} {rd}, {rs1}, {rs2}\n")
            elif op_type == 'IMM':
                imm = random.randint(-2048, 2047)
                imm_op_choice = random.choice(imm_ops)
                if imm_op_choice in['slli', 'srli', 'srai']:
                    imm = imm & 0x1F # 移位范围 0-31
                f.write(f"    {imm_op_choice} {rd}, {rs1}, {imm}\n")
            elif op_type == 'MEM':
                # 安全访存：强制内存地址与 4 字节对齐
                # 给某个寄存器临时赋一个安全的基址，如 0x2000
                f.write(f"    lui {rs1}, 0x80002\n") # 基址在 0x80002 区间
                offset = random.randint(0, 100) * 4 # 保证字对齐
                f.write(f"    sw {rs2}, {offset}({rs1})\n")
                f.write(f"    lw {rd}, {offset}({rs1})\n")
        
        # 3. 完美退出点：制造一个特定的跳转以便 UVM 停止
        f.write("\n# --- EXIT ---\n    .text\n    .align 2\n_custom_exit:")
        f.write("    la t0, tohost\n")
        f.write("    li t1, 1\n")
        f.write("    sw t1, 0(t0)\n")
        f.write("end_loop:\n")
        f.write("    j end_loop\n")
        f.write("    .section .tohost,\"aw\",@progbits\n")
        f.write("    .align 6\n")
        f.write("    .global tohost\n")
        f.write("tohost:\n")
        f.write("    .dword 0\n")
        f.write("    .global fromhost\n")
        f.write("fromhost:\n")
        f.write("    .dword 0\n")

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    prj_path = os.path.abspath(os.path.join(script_dir, "../../"))
    spike_test = os.path.join(prj_path, "sim/cases_asm_spike/case_999_rand_inst_flow.s")
    uvm_test = os.path.join(prj_path, "sim/cases_asm/case_999_rand_inst_flow.s")
    generate_random_test(spike_test, 100, True)
    subprocess.run(f"head -n -13 {spike_test} > {uvm_test} ; \
                     echo \"    nop\" >> {uvm_test} ; \
                     echo \"    nop\" >> {uvm_test} ; \
                     echo \"    j .\" >> {uvm_test}", shell=True)

if __name__ == "__main__":
    main()
