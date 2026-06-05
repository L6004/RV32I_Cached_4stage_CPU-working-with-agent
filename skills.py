# skills.py
import subprocess
import os
import re
import glob
import sys
import streamlit as st

PRJ_ROOT = os.path.abspath(os.path.dirname(__file__))
SIM_DIR = os.path.join(PRJ_ROOT, "sim")
SCR_DIR = os.path.join(SIM_DIR, "scripts")
RUN_SIM = os.path.join(SCR_DIR, "run_sim.py")
RUN_EXP = os.path.join(SCR_DIR, "run_exp.py")
CASES_C_DIR = os.path.join(SIM_DIR, "cases_c")

def get_core_rtl_code() -> dict:
    """Auxiliary function: find all Cache RTL source codes, return dictionary {module: code}"""
    import glob
    import os
    
    rtl_dir = os.path.join(PRJ_ROOT, "src", "rtl")
    cache_files = glob.glob(os.path.join(rtl_dir, "**", "*cache*.v"), recursive=True) + \
                  glob.glob(os.path.join(rtl_dir, "**", "*cache*.sv"), recursive=True)
    
    rtl_dict = {}
    for file_path in cache_files:
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                module_name = os.path.splitext(os.path.basename(file_path))[0]
                rtl_dict[module_name] = f.read()
        except Exception:
            pass
            
    if not rtl_dict:
        rtl_dict["not_found"] = "// RTL source code not found in src/rtl/"
        
    return rtl_dict

def run_cache_sim_single(l1_i_size: int, l1_d_size: int, l1_b_size: int, l1_assoc: int, case_name: str, skip_base: bool = False) -> dict:
    """Skill 1: parameterized cache system RTL simulation"""
    cmd = f"{sys.executable} {RUN_SIM} {case_name} --l1_i_size {l1_i_size} --l1_d_size {l1_d_size} --l1_b_size {l1_b_size} --l1_assoc {l1_assoc} --disable_vcd"
    
    if skip_base:
        cmd += " --skip_base"
        
    result = subprocess.run(cmd, shell=True, cwd=SIM_DIR, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if result.returncode != 0:
        raise RuntimeError(f"底层仿真脚本运行崩溃！请检查日志：\n{result.stderr}\n{result.stdout}")

    gen_dirs = sorted(glob.glob(os.path.join(SIM_DIR, f"cases_asm/gen_{case_name.replace('.c','')}*")), key=os.path.getmtime)
    latest_dir = gen_dirs[-1] if gen_dirs else SIM_DIR
    
    return {
        "csv": os.path.join(latest_dir, "performance_report.csv"),
        "img1": os.path.join(latest_dir, "performance_comparison.png"),
        "img2": os.path.join(latest_dir, "cache_miss_heatmap.png"),
        "rtl_code": get_core_rtl_code()
    }

def generate_and_sim_matrix(case_id: str, n_size: int, b_size: int, skip_base: bool = False) -> dict:
    """Skill 2: automatically generate test programs and simulate (supports macro definition replacement)"""
    case_map = {"701": "case_701_matrix_mult_bad.c", 
                "702": "case_702_matrix_mult_better.c", 
                "703": "case_703_matrix_mult_best.c"}
    src_file = case_map.get(str(case_id), "case_703_matrix_mult_best.c")
    src_path = os.path.join(CASES_C_DIR, src_file)
    
    with open(src_path, "r") as f: content = f.read()
    content = re.sub(r"#define N\s+\d+", f"#define N {n_size}", content)
    content = re.sub(r"int B_SIZE\s*=\s*\d+;", f"int B_SIZE = {b_size};", content)
    
    custom_c_name = f"custom_gen_{src_file}"
    custom_c_path = os.path.join(CASES_C_DIR, custom_c_name)
    with open(custom_c_path, "w") as f: f.write(content)
    
    cmd = f"{sys.executable} {RUN_SIM} {custom_c_name} --disable_vcd"
    
    if skip_base:
        cmd += " --skip_base"
        
    result = subprocess.run(cmd, shell=True, cwd=SIM_DIR, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if result.returncode != 0:
        raise RuntimeError(f"底层仿真脚本运行崩溃！请检查日志：\n{result.stderr}\n{result.stdout}")

    gen_dirs = sorted(glob.glob(os.path.join(SIM_DIR, f"cases_asm/gen_{custom_c_name.replace('.c','')}*")), key=os.path.getmtime)
    latest_dir = gen_dirs[-1]
    
    return {
        "c_code": custom_c_path,
        "s_code": os.path.join(SIM_DIR, "cases_asm", f"{custom_c_name.replace('.c', '.s')}"),
        "csv": os.path.join(latest_dir, "performance_report.csv"),
        "img1": os.path.join(latest_dir, "performance_comparison.png"),
        "img2": os.path.join(latest_dir, "cache_miss_heatmap.png")
    }

def run_arch_exploration() -> dict:
    """Skill 3: automatically run full architecture parameter exploration (supports real-time UI rendering of logs)"""
    
    cmd = f"python3 -u {RUN_EXP}"
    
    status_box = st.status("正在执行全架构参数探索 (预计需要几分钟)...", expanded=True)
    log_placeholder = status_box.empty()
    
    # use Popen to capture stream output
    process = subprocess.Popen(
        cmd, shell=True, cwd=SIM_DIR, 
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, 
        text=True, bufsize=1
    )
    
    log_lines = []
    for line in process.stdout:
        log_lines.append(line.strip())
        display_text = "\n".join(log_lines[-15:])
        log_placeholder.code(display_text, language="bash")
        
    process.wait()
    
    if process.returncode != 0:
        status_box.update(label="架构探索脚本崩溃", state="error")
        raise RuntimeError(f"底层脚本运行失败，请查看前端日志。")

    status_box.update(label="全架构参数探索执行完毕！", state="complete", expanded=False)

    exp_dir = os.path.join(SIM_DIR, "arch_exp")
    return {
        "single_csv1": os.path.join(exp_dir, "single/estimated_result_701.csv"),
        "single_img1": os.path.join(exp_dir, "single/estimated_amat_701.png"),
        "single_csv2": os.path.join(exp_dir, "single/estimated_result_801.csv"),
        "single_img2": os.path.join(exp_dir, "single/estimated_amat_801.png"),
        "assoc_img1": os.path.join(exp_dir, "assoc/assoc_miss_rate.png"),
        "assoc_img2": os.path.join(exp_dir, "assoc/assoc_amat_cpi.png"),
        "locality_img": os.path.join(exp_dir, "locality/locality_result.png")
    }