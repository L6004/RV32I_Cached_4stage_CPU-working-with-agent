import os
import sys
import argparse
import subprocess
import random
import re
import struct
import shutil

os.environ["WEBTALK_DISABLE"] = "1"
os.environ["XILINX_VIVADO_NO_WEBTALK"] = "1"
os.environ["XILINX_LOCAL_USER_DATA"] = "no"

# clear Conda environment variables that may interfere with GCC compilation
conda_vars = ["LIBRARY_PATH", "CPATH", "C_INCLUDE_PATH", "CPLUS_INCLUDE_PATH"]
for var in conda_vars:
    if var in os.environ:
        clean_paths = [p for p in os.environ[var].split(os.pathsep) if "conda" not in p.lower()]
        if clean_paths:
            os.environ[var] = os.pathsep.join(clean_paths)
        else:
            del os.environ[var]

def generate_golden_log(spike_log_path, golden_log_path):
    # analyze Spike logs to extract register write-backs for instructions with PC >= 0x80000000
    pattern_reg = re.compile(r'0x([0-9a-fA-F]+)\s+\(0x([0-9a-fA-F]+)\)\s+x(\d+)\s+0x([0-9a-fA-F]+)')
    pattern_instr = re.compile(r'\(0x([0-9a-fA-F]+)\)')
    with open(spike_log_path, 'r') as fin, open(golden_log_path, 'w') as fout:
        for line in fin:
            match_instr = pattern_instr.search(line)
            if match_instr and match_instr.group(1) == "0000006f": break
            match_reg = pattern_reg.search(line)
            if match_reg:
                pc_hex = match_reg.group(1)
                rd = int(match_reg.group(3))
                data_hex = match_reg.group(4)
                if int(pc_hex, 16) >= 0x80000000 and rd != 0:
                    fout.write(f"{pc_hex} {rd:02x} {data_hex}\n")


def compile_c_to_asm(c_path, duv_asm_path, opt_level):
    import os, subprocess
    base = os.path.splitext(c_path)[0]
    temp_s = f"{base}.tmp.s"
    
    cmd = f"riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -fno-builtin -O{opt_level} -S {c_path} -o {temp_s}"
    subprocess.run(cmd, shell=True, check=True)
    
    clean_asm = []
    discard_directives = ['.file', '.option', '.attribute', '.type', '.size', '.ident']
    
    current_func = ""
    
    # filter
    with open(temp_s, 'r') as f:
        for line in f:
            orig_line = line.strip()
            if not orig_line: continue
                
            line_no_comment = orig_line.split('#')[0].rstrip()
            if not line_no_comment: continue
                
            is_discard = False
            for d in discard_directives:
                if line_no_comment.startswith(d):
                    is_discard = True
                    break
            if is_discard: continue
                
            if line_no_comment.startswith('.globl'):
                line_no_comment = line_no_comment.replace('.globl', '.global')
                
            if line_no_comment.endswith(':'):
                if not line_no_comment.startswith('.'):
                    current_func = line_no_comment[:-1]
                clean_asm.append(line_no_comment)
            else:
                normalized_line = " ".join(line_no_comment.split())
                if normalized_line in ['ret', 'jr ra']:
                    if current_func == '_start':
                        clean_asm.append("    j       _custom_exit")
                        continue
                    
                parts = line_no_comment.split(None, 1)
                if len(parts) == 2:
                    instr = parts[0]
                    operands = parts[1].replace(' ', '')
                    clean_asm.append(f"    {instr:<7} {operands}")
                else:
                    clean_asm.append(f"    {line_no_comment}")

    core_asm_str = "\n".join(clean_asm)

    # necessary boilerplate for DUV assembly
    with open(duv_asm_path, 'w') as f:
        f.write(core_asm_str)
        f.write("\n# --- exit process ---\n    .text\n    .align 2\n_custom_exit:")
        f.write("\n    la t0, tohost \
                 \n    li t1, 1 \
                 \n    sw t1, 0(t0) \
                 \nend_loop: \
                 \n    j end_loop \
                 \n    .section .tohost,\"aw\",@progbits \
                 \n    .align 6 \
                 \n    .global tohost \
                 \ntohost: \
                 \n    .dword 0 \
                 \n    .global fromhost \
                 \nfromhost: \
                 \n    .dword 0\n")
    
    if os.path.exists(temp_s):
        os.remove(temp_s)

def generate_duv_mem(asm_path, mem_out, link_ld):
    # generate 32-bit Hex memory file from assembly using riscv64-unknown-elf-gcc and objcopy
    base = os.path.splitext(mem_out)[0]
    elf, bin_f = f"{base}.elf", f"{base}.bin"
    subprocess.run(f"riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -T {link_ld} -o {elf} {asm_path}", shell=True, check=True)
    subprocess.run(f"riscv64-unknown-elf-objcopy -O binary {elf} {bin_f}", shell=True, check=True)
    with open(bin_f, "rb") as f_in, open(mem_out, "w") as f_out:
        while True:
            chunk = f_in.read(4)
            if not chunk: break
            f_out.write(f"{struct.unpack('<I', chunk + b'\\x00'*(4-len(chunk)))[0]:08x}\n")
    for f in [elf, bin_f]: 
        if os.path.exists(f): os.remove(f)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("case", help="Case filename (e.g. case_001_smoke.s or case_302_hazard_c.c)")
    parser.add_argument("-seed", type=int, help="Seed")
    parser.add_argument("--l1_i_size", type=int, default=8192, help="L1 I-Cache Size in bytes")
    parser.add_argument("--l1_d_size", type=int, default=8192, help="L1 D-Cache Size in bytes")
    parser.add_argument("--l1_b_size", type=int, default=32, help="L1 Cache Block Size in bytes")
    parser.add_argument("--l2_size", type=int, default=65536, help="L2 Cache Size in bytes")
    parser.add_argument("--l2_b_size", type=int, default=64, help="L2 Cache Block Size in bytes")
    parser.add_argument("--l1_assoc", type=int, default=2, help="L1 Cache Associativity")
    parser.add_argument("--l2_assoc", type=int, default=4, help="L2 Cache Associativity")
    parser.add_argument("--l1_l2_bus_bytes", type=int, default=64, help="L1-L2 Cache Bus Data Width in Bytes")
    parser.add_argument("--dram_delay_cycles", type=int, default=2, help="DRAM Behavioral Delay")
    parser.add_argument("--cache_dram_bus_bytes", type=int, default=64, help="L2_Cache-DRAM Bus Data Width in Bytes")
    parser.add_argument("--ram_size", type=int, default=1048576, help="DRAM size")
    parser.add_argument("--fifo_depth", type=int, default=4, help="FIFO depth")
    parser.add_argument("--skip_base", action='store_true', help="Skip Baseline test(no Cache)")
    parser.add_argument("--disable_vcd", action='store_true', help="Disable vcd dump in cache system for very large scale simulation")
    parser.add_argument("--opt_level", type=int, default=2, help="Optimization level for gcc")
    parser.add_argument("--work_dir", type=str, default="", help="Custom working directory for output")
    parser.add_argument("--reuse_sw", action='store_true', help="Skip SW compile and Spike simulation")
    parser.add_argument("--gen_saif", action='store_true', help="Generate saif file for power synthesis")
    parser.add_argument("--gls", action='store_true', help="Run Gate-Level Simulation (Post-Impl) for power analysis")
    parser.add_argument("--strategy", choices=["SPEED", "AREA", "POWER"], default="SPEED")
    args = parser.parse_args()

    # route management
    script_dir = os.path.dirname(os.path.abspath(__file__))
    sim_dir = os.path.abspath(os.path.join(script_dir, "../"))
    prj_path = os.path.abspath(os.path.join(sim_dir, "../"))
    
    sys.path.append(script_dir)
    from gen_random_asm import generate_random_test
    
    seed = args.seed if args.seed is not None else random.randint(1, 99999999)
    case_ext = os.path.splitext(args.case)[1]
    case_name = os.path.splitext(args.case)[0]

    if args.work_dir:
        run_dir = os.path.join(args.work_dir, f"gen_{case_name}_{seed}")
    else:
        run_dir = os.path.join(sim_dir, f"cases_asm/gen_{case_name}_{seed}")
    os.makedirs(run_dir, exist_ok=True)
    os.chdir(run_dir)
    
    if args.work_dir:
        asm_file = os.path.join(run_dir, f"{case_name}.s")
        mem_file = os.path.join(run_dir, f"{case_name}.mem")
    else:
        asm_file = os.path.join(sim_dir, f"cases_asm/{case_name}.s")
        mem_file = os.path.join(sim_dir, f"cases_bin/{case_name}.mem")
    link_ld = os.path.join(script_dir, "link.ld")

    if not args.reuse_sw:
        # process source code to generate DUV assembly and memory file
        if case_ext == ".c":
            c_src = os.path.join(sim_dir, f"cases_c/{args.case}")
            print(f"[*] Compiling C source: {args.case}")
            compile_c_to_asm(c_src, asm_file, args.opt_level)
        elif "rand_inst_flow" in case_name:
            generate_random_test(asm_file, num_instr=100)

        generate_duv_mem(asm_file, mem_file, link_ld)

        # Spike simulation to get golden trace log
        elf_f = f"{case_name}.elf"
        subprocess.run(f"riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -T {link_ld} -o {elf_f} {asm_file}", shell=True)
        subprocess.run(f"spike --isa=rv32i -m0x80000000:0x100000 --log-commits -l {elf_f} 2> spike.log", shell=True)
        generate_golden_log("spike.log", "golden_trace.log")
        if os.path.exists("spike.log"):
            with open("spike.log", "r") as f:
                lines = f.readlines()
            with open("spike.log", "w") as f:
                exit_flag = False
                for line in lines:
                    f.write(line)
                    if exit_flag:
                        break
                    if "0000006f" in line: # exit at 2nd occurrence of JAL with target 0 (infinite loop)
                        exit_flag = True
    else:
        print(f"[*] Skipping SW compilation & Spike simulation (--reuse_sw enabled), reusing existing files.")

    # 4. Vivado workchain
    print("[*] Cleaning cache & Compiling RTL...")
    for d in ["xsim.dir", ".Xil"]: 
        if os.path.exists(d): shutil.rmtree(d)
    
    os.environ["RTL_PATH"] = os.path.join(prj_path, "src/rtl/")
    os.environ["TB_PATH"]  = os.path.join(sim_dir, "bench/")

    tcl_file = "run_and_quit.tcl"
    saif_dir = os.path.join(prj_path, "sim/saif")
    os.makedirs(saif_dir, exist_ok=True)
    with open(tcl_file, "w") as f:
        if args.gen_saif:
            saif_name = f"gls_power_{args.strategy}.saif" if args.gls else f"power.saif"
            saif_path = os.path.join(saif_dir, saif_name)
            f.write(f'open_saif "{saif_path}"\n')
            f.write(f'log_saif [get_objects -r /tb_cpu/u_cpu/*]\n')
            f.write(f'run all\n')
            f.write(f'close_saif\n')
            f.write(f'quit\n')
            
        if not args.disable_vcd:
            f.write(f"catch {{source {script_dir}/wave.tcl}}\n")
            
        f.write("run all\n")
        
        if args.gen_saif:
            f.write("close_saif\n")
            
        f.write("quit\n")

    if args.gls:
        print("[*] Pass: Running Gate-Level Simulation (GLS) with SDF back-annotation...")
        
        # 1. get nelist, SDF and glbl paths based on strategy
        report_dir = os.path.join(prj_path, f"src/report/{args.strategy}")
        gls_v   = os.path.join(report_dir, "cpu_post_impl.v")
        gls_sdf = os.path.join(report_dir, "cpu_post_impl.sdf")
        glbl_v  = os.path.join("/tools/Xilinx/2025.2/", "data/verilog/src/glbl.v")
        
        if not os.path.exists(gls_v):
            print("FATAL: Netlist not found! Please run run_syn_imp.py --mode export_gls first.")
            sys.exit(1)

        # 2. compile netlist, glbl and TB
        print("    -> Compiling Gate-Level Netlist...")
        subprocess.run(f"xvlog -sv -L uvm -d POST_IMPL -d SIM -i {os.environ['TB_PATH']} {gls_v} {glbl_v} -f {prj_path}/src/rtl/rtl_list_sim -f {os.environ['TB_PATH']}/bench_list 2>&1 | tee xvlog_gls.log", shell=True, check=True)
        
        # associate the SDF file with tb_cpu and enable maxdelay for worst-case timing simulation
        print("    -> Elaborating with SDF Annotation...")
        # add simprims_ver library and specify both tb_cpu and glbl as top-level modules for proper SDF back-annotation
        xelab_cmd = (f"xelab -L uvm -L simprims_ver -timescale 1ns/1ps -mt 16 "
                     f"-d POST_IMPL -d SIM -maxdelay -sdfmax /tb_cpu/u_cpu={gls_sdf} "
                     f"-debug all -top tb_cpu -top glbl -snapshot uvm_sim_gls")
        subprocess.run(xelab_cmd + " 2>&1 | tee xelab_gls.log", shell=True, check=True)
        
        # run simulation and export SAIF
        print("    -> Running GLS Simulation...")
        cmd_xsim_gls = f"xsim uvm_sim_gls -tclbatch run_and_quit.tcl -testplusarg MEM_FILE={mem_file} -testplusarg GOLDEN_LOG=golden_trace.log -testplusarg UVM_TESTNAME=cpu_base_test -log xsim_gls.log"
        subprocess.run(cmd_xsim_gls, shell=True, check=True)
        print(f"[*] GLS Done! Gate-Level SAIF saved to {saif_dir}/gls_power_{args.strategy}.saif")
    
    else:
        # ---------------------------------------------------------
        # Baseline compilation and simulation (No Cache)
        # ---------------------------------------------------------
        if not args.skip_base:
            print("[*] Pass 1: Running Baseline (No Cache)...")
            subprocess.run(f"xvlog -sv -L uvm -d SIM -i {os.environ['TB_PATH']} -f {prj_path}/src/rtl/rtl_list_sim -f {os.environ['TB_PATH']}/bench_list 2>&1 | tee xvlog_base.log", shell=True, check=True)
            subprocess.run(f"xelab -L uvm -timescale 1ns/1ps -mt 16 -d SIM -debug all -top tb_cpu -snapshot uvm_sim_base 2>&1 | tee xelab_base.log", shell=True, check=True)
            
            cmd_xsim_base = f"xsim uvm_sim_base -tclbatch run_and_quit.tcl -testplusarg UVM_TESTNAME=cpu_base_test " \
                            f"-testplusarg MEM_FILE={mem_file} -testplusarg GOLDEN_LOG=golden_trace.log -sv_seed {seed} -log xsim_base.log"
            subprocess.run(cmd_xsim_base, shell=True, check=True)

        # ---------------------------------------------------------
        # Cache system version compilation and simulation
        # ---------------------------------------------------------
        print("[*] Pass 2: Running with Cache System...")
        if args.disable_vcd:
            subprocess.run(f"xvlog -sv -L uvm -d SIM -d ENABLE_CACHE -d ENABLE_L2 -i {os.environ['TB_PATH']} -f {prj_path}/src/rtl/rtl_list_sim -f {os.environ['TB_PATH']}/bench_list 2>&1 | tee xvlog_cache.log", shell=True, check=True)
        else:
            subprocess.run(f"xvlog -sv -L uvm -d ENABLE_DUMP -d SIM -d ENABLE_CACHE -d ENABLE_L2 -i {os.environ['TB_PATH']} -f {prj_path}/src/rtl/rtl_list_sim -f {os.environ['TB_PATH']}/bench_list 2>&1 | tee xvlog_cache.log", shell=True, check=True)
        
        generic_args = f'-generic_top "L1_I_SIZE={args.l1_i_size}" \
                        -generic_top "L1_D_SIZE={args.l1_d_size}" \
                        -generic_top "L1_B_SIZE={args.l1_b_size}" \
                        -generic_top "L2_SIZE={args.l2_size}" \
                        -generic_top "L2_B_SIZE={args.l2_b_size}" \
                        -generic_top "L1_ASSOC={args.l1_assoc}" \
                        -generic_top "L2_ASSOC={args.l2_assoc}" \
                        -generic_top "L1_L2_BUS_BYTES={args.l1_l2_bus_bytes}" \
                        -generic_top "DRAM_DELAY_CYCLES={args.dram_delay_cycles}" \
                        -generic_top "CACHE_DRAM_BUS_BYTES={args.cache_dram_bus_bytes}" \
                        -generic_top "RAM_SIZE={args.ram_size}" \
                        -generic_top "FIFO_DEPTH={args.fifo_depth}"'
        if args.disable_vcd:
            subprocess.run(f"xelab -L uvm -L xpm -L unisims_ver -timescale 1ns/1ps -mt 16 -d SIM -d ENABLE_CACHE -d ENABLE_L2 {generic_args} -debug all -top tb_cpu -snapshot uvm_sim_cache 2>&1 | tee xelab_cache.log", shell=True, check=True)
        else:
            subprocess.run(f"xelab -L uvm -L xpm -L unisims_ver -timescale 1ns/1ps -mt 16 -d ENABLE_DUMP -d SIM -d ENABLE_CACHE -d ENABLE_L2 {generic_args} -debug all -top tb_cpu -snapshot uvm_sim_cache 2>&1 | tee xelab_cache.log", shell=True, check=True)
        
        # GUI could be enabled for debugging, but for automated runs we use batch mode
        cmd_xsim_cache = f"xsim uvm_sim_cache -tclbatch run_and_quit.tcl -testplusarg UVM_TESTNAME=cpu_base_test " \
                        f"-testplusarg MEM_FILE={mem_file} -testplusarg GOLDEN_LOG=golden_trace.log -sv_seed {seed} -log xsim_cache.log"
        subprocess.run(cmd_xsim_cache, shell=True, check=True)

        # performance data analysis and report generation
        def parse_sim_log(log_path):
            data = {'cycles': 0, 'cpi': 0.0, 'l1i_hits': 0, 'l1i_misses': 0, 
                    'l1d_hits': 0, 'l1d_misses': 0, 'l2_hits': 0, 'l2_misses': 0}
            if not os.path.exists(log_path): return data
            with open(log_path, 'r') as f:
                for line in f:
                    if "Total Cycles" in line: data['cycles'] = int(line.split(':')[1].strip())
                    elif "CPI" in line: data['cpi'] = float(line.split(':')[1].strip())
                    elif "L1 I-Cache hits" in line and "misses" not in line: data['l1i_hits'] = int(line.split(':')[1].strip())
                    elif "L1 I-Cache misses" in line: data['l1i_misses'] = int(line.split(':')[1].strip())
                    elif "L1 D-Cache hits" in line and "misses" not in line: data['l1d_hits'] = int(line.split(':')[1].strip())
                    elif "L1 D-Cache misses" in line: data['l1d_misses'] = int(line.split(':')[1].strip())
                    elif "L2 Cache hits" in line and "misses" not in line: data['l2_hits'] = int(line.split(':')[1].strip())
                    elif "L2 Cache misses" in line: data['l2_misses'] = int(line.split(':')[1].strip())
            return data

        print("\n[*] Analyzing Performance Logs...")
        base_data  = parse_sim_log("xsim_base.log")
        cache_data = parse_sim_log("xsim_cache.log")

        def calc_rate(hits, misses):
            return (hits / (hits + misses) * 100) if (hits + misses) > 0 else 0.0

        l1i_rate = calc_rate(cache_data['l1i_hits'], cache_data['l1i_misses'])
        l1d_rate = calc_rate(cache_data['l1d_hits'], cache_data['l1d_misses'])
        l2_rate  = calc_rate(cache_data['l2_hits'],  cache_data['l2_misses'])

        # overall hit rate calculation
        # overall memory access = L1 accesses (I + D) = L1 hits + L1 misses
        total_access = (cache_data['l1i_hits'] + cache_data['l1i_misses'] + 
                        cache_data['l1d_hits'] + cache_data['l1d_misses'])
        # overall misses = L2 misses = L1 misses - L2 hits
        total_miss = cache_data['l2_misses']
        overall_rate = ((total_access - total_miss) / total_access * 100) if total_access > 0 else 0.0

        # AMAT and speedup estimation
        l1_miss_rate = 1.0 - ((l1i_rate + l1d_rate) / 200.0)
        l2_miss_rate = 1.0 - (l2_rate / 100.0)
        amat = 1 + l1_miss_rate * (10 + l2_miss_rate * 100)

        cache_est_cycles = cache_data['cycles'] + 98 * cache_data['l2_misses'] + 8 * cache_data['l2_hits']
        cache_inst_count = cache_data['cycles'] / cache_data['cpi'] if cache_data['cpi'] > 0 else 1
        cache_est_cpi = cache_est_cycles / cache_inst_count

        if base_data['cpi'] > 0:
            base_inst_count = base_data['cycles'] / base_data['cpi']
        else:   # skip base
            base_inst_count = cache_inst_count * 20
            base_data['cycles'] = int(base_inst_count)
            base_data['cpi'] = 150.0
        base_est_cycles = base_data['cycles'] + 98 * total_access
        base_est_cpi = base_est_cycles / base_inst_count
        speedup = base_est_cycles / cache_est_cycles if cache_est_cycles > 0 else 0

        # performance report generation
        l1i_str = f"{l1i_rate:.2f}% ({cache_data['l1i_hits']}/{cache_data['l1i_hits']+cache_data['l1i_misses']})"
        l1d_str = f"{l1d_rate:.2f}% ({cache_data['l1d_hits']}/{cache_data['l1d_hits']+cache_data['l1d_misses']})"
        l2_str  = f"{l2_rate:.2f}% ({cache_data['l2_hits']}/{cache_data['l2_hits']+cache_data['l2_misses']})"
        ovr_str = f"{overall_rate:.2f}% ({total_access-total_miss}/{total_access})"

        cw1, cw2, cw3 = 20, 20, 28
        sep_line = "=" * (cw1 + cw2 + cw3 + 10)

        print(sep_line)
        print(f"{' PERFORMANCE COMPARISON ':-^{cw1+cw2+cw3+10}}")
        print(sep_line)
        print(f"| {'Metric':<{cw1}} | {'Baseline (No Cache)':<{cw2}} | {'Cache System':<{cw3}} |")
        print("-" * (cw1 + cw2 + cw3 + 10))
        print(f"| {'Total Cycles':<{cw1}} | {base_data['cycles']:<{cw2}} | {cache_data['cycles']:<{cw3}} |")
        print(f"| {'Estimated Cycles':<{cw1}} | {base_est_cycles:<{cw2}} | {cache_est_cycles:<{cw3}} |")
        print(f"| {'CPI':<{cw1}} | {base_data['cpi']:<{cw2}.3f} | {cache_data['cpi']:<{cw3}.3f} |")
        print(f"| {'Estimated CPI':<{cw1}} | {base_est_cpi:<{cw2}.3f} | {cache_est_cpi:<{cw3}.3f} |")
        print("-" * (cw1 + cw2 + cw3 + 10))
        print(f"| {'L1 I-Cache Hit Rate':<{cw1}} | {'N/A':<{cw2}} | {l1i_str:<{cw3}} |")
        print(f"| {'L1 D-Cache Hit Rate':<{cw1}} | {'N/A':<{cw2}} | {l1d_str:<{cw3}} |")
        print(f"| {'L2 Cache Hit Rate':<{cw1}} | {'N/A':<{cw2}} | {l2_str:<{cw3}} |")
        print(f"| {'Overall Hit Rate':<{cw1}} | {'N/A':<{cw2}} | {ovr_str:<{cw3}} |")
        print("-" * (cw1 + cw2 + cw3 + 10))
        print(f"| {'Estimated AMAT':<{cw1}} | {'100.00 cycles':<{cw2}} | {f'{amat:.2f} cycles':<{cw3}} |")
        print(f"| {'Speedup':<{cw1}} | {'1.00x':<{cw2}} | {f'{speedup:.2f}x':<{cw3}} |")
        print(sep_line)

        # save report to text file
        report_text = "\n".join([
            sep_line,
            f"{' PERFORMANCE COMPARISON ':-^{cw1+cw2+cw3+10}}",
            sep_line,
            f"| {'Metric':<{cw1}} | {'Baseline (No Cache)':<{cw2}} | {'Cache System':<{cw3}} |",
            "-" * (cw1 + cw2 + cw3 + 10),
            f"| {'Total Cycles':<{cw1}} | {base_data['cycles']:<{cw2}} | {cache_data['cycles']:<{cw3}} |",
            f"| {'Estimated Cycles':<{cw1}} | {base_est_cycles:<{cw2}} | {cache_est_cycles:<{cw3}} |",
            f"| {'CPI':<{cw1}} | {base_data['cpi']:<{cw2}.3f} | {cache_data['cpi']:<{cw3}.3f} |",
            f"| {'Estimated CPI':<{cw1}} | {base_est_cpi:<{cw2}.3f} | {cache_est_cpi:<{cw3}.3f} |",
            "-" * (cw1 + cw2 + cw3 + 10),
            f"| {'L1 I-Cache Hit Rate':<{cw1}} | {'N/A':<{cw2}} | {l1i_str:<{cw3}} |",
            f"| {'L1 D-Cache Hit Rate':<{cw1}} | {'N/A':<{cw2}} | {l1d_str:<{cw3}} |",
            f"| {'L2 Cache Hit Rate':<{cw1}} | {'N/A':<{cw2}} | {l2_str:<{cw3}} |",
            f"| {'Overall Hit Rate':<{cw1}} | {'N/A':<{cw2}} | {ovr_str:<{cw3}} |",
            "-" * (cw1 + cw2 + cw3 + 10),
            f"| {'Estimated AMAT':<{cw1}} | {'100.00 cycles':<{cw2}} | {f'{amat:.2f} cycles':<{cw3}} |",
            f"| {'Speedup':<{cw1}} | {'1.00x':<{cw2}} | {f'{speedup:.2f}x':<{cw3}} |",
            sep_line,
            sep_line,
            f"{' CACHE SYSTEM & DRAM ARCHITECTURE ':-^{cw1+cw2+cw3+10}}",
            sep_line,
            f"| {'Cache Architecture':<{cw1}} | {'L1 I/D':<{cw2}} | {'L2':<{cw3}} |",
            "-" * (cw1 + cw2 + cw3 + 10),
            f"| {'Cache Size(Bytes)':<{cw1}} | {f'{args.l1_i_size}/{args.l1_d_size}':<{cw2}} | {f'{args.l2_size}':<{cw3}} |",
            f"| {'Block Size(Bytes)':<{cw1}} | {f'{args.l1_b_size}':<{cw2}} | {f'{args.l2_b_size}':<{cw3}} |",
            f"| {'Associativity':<{cw1}} | {f'{args.l1_assoc}':<{cw2}} | {f'{args.l2_assoc}':<{cw3}} |",
            sep_line,
            f"| {'DRAM Parameters':<{cw1}} | {' ':<{cw2}} | {' ':<{cw3}} |",
            "-" * (cw1 + cw2 + cw3 + 10),
            f"| {'DRAM Size(Bytes)':<{cw1}} | {f'{args.ram_size}':<{cw2}} | {' ':<{cw3}} |",
            f"| {'DRAM Delay(Cycles)':<{cw1}} | {f'{args.dram_delay_cycles}':<{cw2}} | {' ':<{cw3}} |",
            sep_line
        ])
        with open("performance_report.txt", "w") as f:
            f.write(report_text)
        
        # generate bar chart and heatmap using matplotlib
        try:
            import matplotlib.pyplot as plt
            import numpy as np
            
            labels = ['Total Cycles']
            base_vals = [int(base_est_cycles)]
            cache_vals = [int(cache_est_cycles)]
            
            x = np.arange(len(labels))
            width = 0.35
            fig, ax = plt.subplots()
            rects1 = ax.bar(x - width/2, base_vals, width, label='Baseline (No Cache)')
            rects2 = ax.bar(x + width/2, cache_vals, width, label='Cache System')
            
            ax.set_ylabel('Cycles')
            ax.set_title(f'Performance Comparison ({args.case}) with Est-Data')
            ax.set_xticks(x)
            ax.set_xticklabels(labels)
            ax.legend()
            
            plt.savefig("performance_comparison.png")
            print(f"\n[Success] Text report saved to performance_report.txt")
            print(f"[Success] Matplotlib figure saved as performance_comparison.png")

            l1i_miss_rate = 100.0 - l1i_rate
            l1d_miss_rate = 100.0 - l1d_rate
            l2_miss_rate = 100.0 - l2_rate

            miss_rates = np.array([[l1i_miss_rate, l1d_miss_rate, l2_miss_rate]])
            labels = ['L1 I-Cache', 'L1 D-Cache', 'L2 Cache']

            fig, ax = plt.subplots(figsize=(8, 3))
            cax = ax.matshow(miss_rates, cmap='YlOrRd', vmin=0, vmax=100)
            fig.colorbar(cax, label='Miss Rate (%)')

            ax.set_xticks(np.arange(len(labels)))
            ax.set_yticks([0])
            ax.set_xticklabels(labels)
            ax.set_yticklabels(['Miss Rate'])

            for (i, j), val in np.ndenumerate(miss_rates):
                ax.text(j, i, f'{val:.2f}%', ha='center', va='center', 
                        color='white' if val > 50 else 'black', fontweight='bold')

            plt.title(f'Cache Miss Rate Heatmap ({args.case})', pad=20)
            plt.tight_layout()
            plt.savefig("cache_miss_heatmap.png")
            print(f"[Success] Heatmap saved to cache_miss_heatmap.png")
            plt.close()
        except ImportError:
            print(f"\n[Info] matplotlib is not installed. Skipped plotting PNG. Report saved to txt.")

        # save report data to CSV
        import csv
        csv_file = "performance_report.csv"
        csv_data = [
            ["Metric", "Baseline (No Cache)", "Cache System"],
            ["Total Cycles", base_data['cycles'], cache_data['cycles']],
            ["Estimated Cycles", base_est_cycles, cache_est_cycles],
            ["CPI", round(base_data['cpi'], 3), round(cache_data['cpi'], 3)],
            ["Estimated CPI", round(base_est_cpi, 3), round(cache_est_cpi, 3)],
            ["L1 I-Cache Hit Rate (%)", "N/A", round(l1i_rate, 2)],
            ["L1 D-Cache Hit Rate (%)", "N/A", round(l1d_rate, 2)],
            ["L2 Cache Hit Rate (%)", "N/A", round(l2_rate, 2)],
            ["Overall Hit Rate (%)", "N/A", round(overall_rate, 2)],
            ["Estimated AMAT (Cycles)", 100.00, round(amat, 2)],
            ["Speedup", 1.00, round(speedup, 2)]
        ]
        with open(csv_file, mode='w', newline='') as file:
            writer = csv.writer(file)
            writer.writerows(csv_data)
        print(f"[Success] CSV report saved to {csv_file}")

if __name__ == "__main__":
    main()