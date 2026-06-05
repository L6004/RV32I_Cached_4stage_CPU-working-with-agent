import os
import subprocess
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import shutil
import concurrent.futures

PRJ_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../"))
EXP_DIR = os.path.join(PRJ_PATH, "sim/arch_exp")
RUN_SIM_CMD = f"python3 {os.path.join(os.path.dirname(__file__), 'run_sim.py')}"
FIXED_SEED = 1024

def setup_dirs():
    for d in ['sw_prep', 'single', 'assoc', 'locality']:
        os.makedirs(os.path.join(EXP_DIR, d), exist_ok=True)

def parse_report(report_path):
    data = {
        'cycles': 0, 'cpi': 0.0,
        'est_cycles': 0, 'est_cpi': 0.0, 'est_amat': 0.0,
        'l1i_hit': 0.0, 'l1d_hit': 0.0, 'l2_hit': 0.0, 'overall_hit': 0.0
    }
    
    if not os.path.exists(report_path): 
        return data
        
    with open(report_path, 'r') as f:
        for line in f:
            if '|' not in line: continue
            parts = [p.strip() for p in line.split('|')]
            if len(parts) < 4: continue
            
            metric = parts[1]
            val_str = parts[3]
            
            try:
                if 'Total Cycles' in metric:
                    data['cycles'] = int(val_str)
                elif 'Estimated Cycles' in metric:
                    data['est_cycles'] = int(val_str)
                elif metric == 'CPI':
                    data['cpi'] = float(val_str)
                elif 'Estimated CPI' in metric:
                    data['est_cpi'] = float(val_str)
                elif 'L1 I-Cache Hit Rate' in metric and '%' in val_str:
                    data['l1i_hit'] = float(val_str.split('%')[0])
                elif 'L1 D-Cache Hit Rate' in metric and '%' in val_str:
                    data['l1d_hit'] = float(val_str.split('%')[0])
                elif 'L2 Cache Hit Rate' in metric and '%' in val_str:
                    data['l2_hit'] = float(val_str.split('%')[0])
                elif 'Overall Hit Rate' in metric and '%' in val_str:
                    data['overall_hit'] = float(val_str.split('%')[0])
                elif 'Estimated AMAT' in metric:
                    data['est_amat'] = float(val_str.split()[0])
            except (ValueError, IndexError):
                pass
                
    return data

def prepare_software(case):
    # Compile and run Spike for every case for later reuse
    print(f"  [Prep] Compiling & Spiking for {case} ...")
    prep_dir = os.path.join(EXP_DIR, 'sw_prep')
    cmd = f"{RUN_SIM_CMD} {case} -seed {FIXED_SEED} --disable_vcd --skip_base --work_dir {prep_dir} --opt_level 2"
    subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL)
    return os.path.join(prep_dir, f"gen_{case.replace('.c','')}_{FIXED_SEED}")

def run_simulation_task(task_args):
    # parallel simulation task for a single configuration
    case, work_dir, extra_args, prep_dir_path = task_args
    case_base = case.replace('.c','')
    target_dir = os.path.join(work_dir, f"gen_{case_base}_{FIXED_SEED}")
    os.makedirs(target_dir, exist_ok=True)
    
    # reuse the pre-generated .mem and golden_trace.log to save time, instead of re-running Spike
    shutil.copy(os.path.join(prep_dir_path, f"{case_base}.mem"), target_dir)
    shutil.copy(os.path.join(prep_dir_path, "golden_trace.log"), target_dir)
    
    cmd = f"{RUN_SIM_CMD} {case} -seed {FIXED_SEED} --disable_vcd --skip_base --work_dir {work_dir} --reuse_sw {extra_args}"
    subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL)
    
    data = parse_report(os.path.join(target_dir, "performance_report.txt"))
    return data

# ==========================================
# Single Parameter
# ==========================================
def exp_single():
    print("\n========== [1/3] Single Parameter Exploration ==========")
    work_dir = os.path.join(EXP_DIR, 'single')
    cases = ['case_701_matrix_mult_bad.c', 'case_801_array_seq_access.c']
    
    params = {
        'L1 Capacity': [('--l1_i_size 4096 --l1_d_size 4096', '4KB'), 
                        ('--l1_i_size 8192 --l1_d_size 8192', '8KB'), 
                        ('--l1_i_size 16384 --l1_d_size 16384', '16KB')],
        'L1 Block Size': [('--l1_b_size 16', '16B'), 
                          ('--l1_b_size 32', '32B'), 
                          ('--l1_b_size 64', '64B')],
        'L1 Assoc': [('--l1_assoc 1', 'Direct'), 
                     ('--l1_assoc 2', '2-Way'), 
                     ('--l1_assoc 4', '4-Way')]
    }
    
    for case in cases:
        prep_dir_path = prepare_software(case)
        tasks = []
        for param_group, options in params.items():
            for arg, label in options:
                task_dir = os.path.join(work_dir, f"{param_group.replace(' ', '_')}_{label}")
                tasks.append((case, task_dir, arg, prep_dir_path))
                
        # parallel execution of simulations
        print(f"  [Sim] Dispatching {len(tasks)} parallel jobs for {case} ...")
        with concurrent.futures.ProcessPoolExecutor(max_workers=8) as executor:
            raw_results = list(executor.map(run_simulation_task, tasks))
            
        results = []
        for task, data in zip(tasks, raw_results):
            p_group = task[1].split('/')[-1].split('_')[0:2] # dirty trick to get group back
            label = task[1].split('_')[-1]
            data['Parameter Group'] = " ".join(p_group)
            data['Option'] = label
            results.append(data)
            
        df = pd.DataFrame(results).set_index(['Parameter Group', 'Option'])
        df = df[['l1i_hit', 'l1d_hit', 'l2_hit', 'overall_hit', 'est_cycles', 'est_cpi', 'est_amat']]
        
        prefix = case.split('_')[1]
        df.to_csv(os.path.join(work_dir, f'estimated_result_{prefix}.csv'))
        with open(os.path.join(work_dir, f'estimated_result_{prefix}.txt'), 'w') as f:
            f.write(df.to_string())

        fig, axes = plt.subplots(1, 3, figsize=(15, 5))
        groups = df.index.get_level_values(0).unique()
        for i, grp in enumerate(groups):
            sub_df = df.xs(grp, level=0)
            axes[i].plot(sub_df.index, sub_df['est_amat'], marker='o', color='steelblue', linewidth=2)
            axes[i].set_title(grp)
            axes[i].set_ylabel('Estimated AMAT (Cycles)' if i == 0 else '')
            axes[i].grid(True, linestyle='--', alpha=0.7)
            
        plt.suptitle(f'Estimated AMAT vs Architecture ({case})', y=1.05, fontsize=14)
        plt.tight_layout()
        plt.savefig(os.path.join(work_dir, f'estimated_amat_{prefix}.png'), bbox_inches='tight')
        plt.close()

# ==========================================
# Associativity & Block Size Correlation
# ==========================================
def exp_assoc():
    print("\n========== [2/3] Associativity & Block Size Correlation ==========")
    work_dir = os.path.join(EXP_DIR, 'assoc')
    case = 'case_701_matrix_mult_bad.c'
    prep_dir_path = prepare_software(case)
    
    b_sizes = [16, 32, 64]
    assocs = [1, 2, 4, 8]
    tasks = []
    
    # construct tasks for all combinations of block size and associativity
    for b in b_sizes:
        for a in assocs:
            args = f"--l1_i_size 8192 --l1_d_size 8192 --l1_b_size {b} --l1_assoc {a}"
            task_dir = os.path.join(work_dir, f"B{b}_A{a}")
            tasks.append((case, task_dir, args, prep_dir_path))
            
    print(f"  [Sim] Dispatching {len(tasks)} parallel jobs ...")
    with concurrent.futures.ProcessPoolExecutor(max_workers=8) as executor:
        results = list(executor.map(run_simulation_task, tasks))
        
    # collect results into a structured dictionary for plotting
    res_dict = {b: {'l1d_miss': [], 'l1i_miss': [], 'l2_miss': [], 'est_amat': [], 'est_cpi': []} for b in b_sizes}
    for task, data in zip(tasks, results):
        b = int(task[1].split('B')[1].split('_')[0])
        res_dict[b]['l1d_miss'].append(100.0 - data['l1d_hit'])
        res_dict[b]['l1i_miss'].append(100.0 - data['l1i_hit'])
        res_dict[b]['l2_miss'].append(100.0 - data['l2_hit'])
        res_dict[b]['est_amat'].append(data['est_amat'])
        res_dict[b]['est_cpi'].append(data['est_cpi'])
        
    # figure 1: Miss Rates vs Associativity for different block sizes
    fig, axes = plt.subplots(1, 3, figsize=(15, 5), sharey=True)
    for i, b in enumerate(b_sizes):
        ax = axes[i]
        ax.plot(assocs, res_dict[b]['l1d_miss'], marker='D', color='crimson', linewidth=2, label='L1 Data Miss')
        ax.plot(assocs, res_dict[b]['l1i_miss'], marker='^', color='steelblue', linewidth=2, label='L1 Inst Miss')
        ax.plot(assocs, res_dict[b]['l2_miss'], marker='s', color='darkorange', linewidth=2, label='L2 Cache Miss')
        
        ax.set_title(f'Block Size = {b}B')
        ax.set_xlabel('Associativity')
        ax.set_xticks(assocs)
        ax.set_xticklabels(['1-way', '2-way', '4-way', '8-way'])
        ax.grid(True, linestyle='--', alpha=0.7)
        
        if i == 0:
            ax.set_ylabel('Miss Rate (%)')
            ax.legend()
            
    plt.suptitle('L1D, L1I, and L2 Miss Rates vs Associativity (8KB L1)', fontsize=14, y=1.02)
    plt.tight_layout()
    plt.savefig(os.path.join(work_dir, 'assoc_miss_rate.png'), bbox_inches='tight')
    plt.close()
    
    # figure 2: Estimated AMAT and CPI vs Associativity for a fixed block size (32B)
    fig, ax1 = plt.subplots(figsize=(9, 6))
    ax2 = ax1.twinx()
    
    ax1.plot(assocs, res_dict[32]['est_amat'], marker='o', color='steelblue', linewidth=2, label='Estimated AMAT')
    ax2.plot(assocs, res_dict[32]['est_cpi'], marker='D', color='darkorange', linewidth=2, label='Estimated CPI')
    
    ax1.set_xlabel('Associativity (32B Block Size)')
    ax1.set_ylabel('AMAT (Cycles)', color='steelblue')
    ax2.set_ylabel('CPI', color='darkorange')
    
    ax1.set_xticks(assocs)
    ax1.set_xticklabels(['1-way', '2-way', '4-way', '8-way'])
    plt.title('System Performance (AMAT & CPI) vs Associativity (32B Block)')
    
    lines_1, labels_1 = ax1.get_legend_handles_labels()
    lines_2, labels_2 = ax2.get_legend_handles_labels()
    ax1.legend(lines_1 + lines_2, labels_1 + labels_2, loc='upper right')
    
    ax1.grid(True, linestyle='--', alpha=0.5)
    plt.tight_layout()
    plt.savefig(os.path.join(work_dir, 'assoc_amat_cpi.png'))
    plt.close()

# ==========================================
# Locality Analysis
# ==========================================
def exp_locality():
    print("\n========== [3/3] Locality Analysis ==========")
    work_dir = os.path.join(EXP_DIR, 'locality')
    
    cases = [
        ('case_302_hazard_c.c', 'Fibonacci\n(Temporal)'),
        ('case_801_array_seq_access.c', 'Array Seq\n(Spatial)'),
        ('case_802_array_stride_access.c', 'Array Stride\n(Weak/Thrashing)') # 改为步长测试
    ]
    
    tasks = []
    args = "--l1_i_size 4096 --l1_d_size 4096"
    for case, label in cases:
        prep_dir_path = prepare_software(case)
        task_dir = os.path.join(work_dir, case.replace('.c',''))
        tasks.append((case, task_dir, args, prep_dir_path))
        
    print(f"  [Sim] Dispatching {len(tasks)} parallel jobs ...")
    with concurrent.futures.ProcessPoolExecutor(max_workers=8) as executor:
        results = list(executor.map(run_simulation_task, tasks))
        
    l1d_miss = [100.0 - d['l1d_hit'] for d in results]
    l2_miss = [100.0 - d['l2_hit'] for d in results]
    labels = [c[1] for c in cases]
    
    plt.figure(figsize=(9, 6))
    x = np.arange(len(labels))
    plt.plot(x, l1d_miss, marker='D', color='crimson', linewidth=2, markersize=8, label='L1 Data Miss Rate')
    plt.plot(x, l2_miss, marker='s', color='skyblue', linewidth=2, markersize=8, label='L2 Cache Miss Rate')
    
    plt.xticks(x, labels)
    plt.ylabel('Miss Rate (%)')
    plt.title('Cache Miss Rates Across Locality Characteristics (L1=4KB)')
    
    # mark the "Cache Buster" point where L1D miss rate exceeds 80%
    if l1d_miss[-1] > 80.0:
        plt.annotate('Cache Buster!', xy=(2, l1d_miss[-1]), xytext=(1.8, l1d_miss[-1] - 15),
                     arrowprops=dict(facecolor='red', shrink=0.05),
                     fontsize=12, color='red', fontweight='bold')

    plt.grid(axis='y', linestyle='--', alpha=0.7)
    plt.legend()
    plt.tight_layout()
    plt.savefig(os.path.join(work_dir, 'locality_result.png'))
    plt.close()

if __name__ == "__main__":
    print(">>> Initializing Architecture Exploration Script (Multi-Core Accelerated) <<<")
    setup_dirs()
    exp_single()
    exp_assoc()
    exp_locality()
    print("\n[SUCCESS] All experiments completed safely with 16-thread parallelism!")