#!/usr/bin/python3
import os
import subprocess
import argparse

def main():
    parser = argparse.ArgumentParser(description="Vivado Synthesis & Power Analysis Script")
    parser.add_argument("--mode", choices=["normal", "export_gls", "report_power"], default="normal",
                        help="normal: run syn&imp; export_gls: export netlist&SDF; report_power: run gls power report")
    parser.add_argument("--strategy", choices=["SPEED", "AREA", "POWER", "ALL"], default="SPEED")
    args = parser.parse_args()
    
    script_dir = os.path.dirname(os.path.abspath(__file__))
    prj_path = os.path.abspath(os.path.join(script_dir, "../../"))
    
    rtl_list_path = os.path.join(prj_path, "src/rtl/rtl_list_syn")
    rtl_dir = os.path.join(prj_path, "src/rtl")
    
    verilog_files = []
    if args.mode != "report_power":
        with open(rtl_list_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):
                    filepath = line.replace("${RTL_PATH}", rtl_dir + "/")
                    verilog_files.append(filepath)

    part_name = "xc7a100tcsg324-1"
    top_module = "riscv_top"
    
    syn_dir = os.path.join(prj_path, "src/report/")
    os.makedirs(syn_dir, exist_ok=True)
    os.chdir(syn_dir)

    xdc_path = os.path.join(syn_dir, "cpu_ooc.xdc")
    if args.mode != "report_power":
        with open(xdc_path, 'w') as f:
            f.write('create_clock -period 16.00 -name clk -waveform {0.000 8.000} [get_ports clk]\n')
            # memory protection
            f.write('set_property DONT_TOUCH true [get_cells -hierarchical -filter {REF_NAME=~*ram*}]\n')

    if args.mode == "normal":
        strategies = {
            "SPEED": {
                "synth": "-directive PerformanceOptimized -flatten_hierarchy rebuilt",
                "impl_opt": "opt_design -directive Explore",
                "impl_power": "",
                "impl_place": "place_design -directive Explore",
                "impl_phys_opt": "phys_opt_design -directive AggressiveExplore",
                "impl_route": "route_design -directive Explore"
            },
            "AREA": {
                "synth": "-directive AreaOptimized_high -flatten_hierarchy rebuilt",
                "impl_opt": "opt_design -directive ExploreArea",
                "impl_power": "",
                "impl_place": "place_design -directive Default",
                "impl_phys_opt": "phys_opt_design -directive Default",
                "impl_route": "route_design -directive Default"
            },
            "POWER": {
                "synth": "-directive AlternateRoutability -flatten_hierarchy rebuilt",
                "impl_opt": "opt_design -directive Default",
                "impl_power": "power_opt_design", 
                "impl_place": "place_design -directive Default",
                "impl_phys_opt": "phys_opt_design -directive Default",
                "impl_route": "route_design -directive Default"
            }
        }
    else:
            strategies = {
            "SPEED": {
                "synth": "-directive PerformanceOptimized",
                "impl_opt": "opt_design -directive Explore",
                "impl_power": "",
                "impl_place": "place_design -directive Explore",
                "impl_phys_opt": "phys_opt_design -directive AggressiveExplore",
                "impl_route": "route_design -directive Explore"
            },
            "AREA": {
                "synth": "-directive AreaOptimized_high",
                "impl_opt": "opt_design -directive ExploreArea",
                "impl_power": "",
                "impl_place": "place_design -directive Default",
                "impl_phys_opt": "phys_opt_design -directive Default",
                "impl_route": "route_design -directive Default"
            },
            "POWER": {
                "synth": "-directive AlternateRoutability",
                "impl_opt": "opt_design -directive Default",
                "impl_power": "power_opt_design", 
                "impl_place": "place_design -directive Default",
                "impl_phys_opt": "phys_opt_design -directive Default",
                "impl_route": "route_design -directive Default"
            }
        }

    target_strategies = [args.strategy] if args.strategy != "ALL" else strategies.keys()

    for name in target_strategies:
        cmd = strategies[name]
        print(f"\n========== Strategy: {name} | Mode: {args.mode} ==========")
        strategy_dir = os.path.join(syn_dir, name)
        os.makedirs(strategy_dir, exist_ok=True)
        tcl_path = os.path.join(strategy_dir, "run.tcl")
        
        with open(tcl_path, 'w') as f:
            f.write(f'set_param general.maxThreads 16\n')
            
            if args.mode == "report_power":
                f.write(f'open_checkpoint {strategy_dir}/post_route.dcp\n')
                saif_file = os.path.abspath(os.path.join(prj_path, f"sim/saif/gls_power_{args.strategy}.saif"))
                f.write(f'if {{ [file exists "{saif_file}"] }} {{\n')
                f.write(f'    puts "--- Reading Gate-Level SAIF ---"\n')
                f.write(f'    read_saif -file "{saif_file}" -strip_path tb_cpu/u_cpu\n')
                f.write(f'}} else {{\n')
                f.write(f'    puts "FATAL: {saif_file} not found. Run GLS first!"\n')
                f.write(f'}}\n')
                f.write(f'report_power -file {strategy_dir}/post_impl_power.rpt\n')
            
            else:
                f.write(f'create_project -in_memory -part {part_name}\n')
                for v_file in verilog_files: f.write(f'read_verilog -sv {v_file}\n')
                f.write(f'read_xdc {xdc_path}\n')
                f.write(f'set_property USED_IN {{synthesis implementation}} [get_files {xdc_path}]\n')
                f.write(f'set_property PROCESSING_ORDER EARLY [get_files {xdc_path}]\n')

                f.write(f'synth_design -top {top_module} -part {part_name} -verilog_define {{ENABLE_CACHE=1}} -verilog_define {{POST_IMPL=1}} -mode out_of_context {cmd["synth"]}\n')
                f.write(f'{cmd["impl_opt"]}\n')
                f.write(f'{cmd["impl_place"]}\n')
                f.write(f'{cmd["impl_phys_opt"]}\n')
                f.write(f'{cmd["impl_route"]}\n')
                f.write(f'write_checkpoint -force {strategy_dir}/post_route.dcp\n')

                f.write(f'report_timing_summary -max_paths 200 -nworst 1 -file {strategy_dir}/timing_summary.rpt\n')
                f.write(f'report_timing -delay_type max -max_paths 200 -nworst 1 -file {strategy_dir}/all_failing_paths.rpt\n')
                f.write(f'report_utilization -file {strategy_dir}/utilization.rpt\n')
                
                if args.mode == "export_gls":
                    f.write(f'puts "--- Exporting GLS Netlist and SDF ---"\n')
                    f.write(f'write_verilog -force -mode timesim -sdf_anno true {strategy_dir}/cpu_post_impl.v\n')
                    f.write(f'write_sdf -force {strategy_dir}/cpu_post_impl.sdf\n')
                else:
                    f.write(f'open_checkpoint {strategy_dir}/post_route.dcp\n')
                    saif_file = os.path.abspath(os.path.join(prj_path, f"sim/saif/power.saif"))
                    f.write(f'if {{ [file exists "{saif_file}"] }} {{\n')
                    f.write(f'    puts "--- Reading Gate-Level SAIF ---"\n')
                    f.write(f'    read_saif -file "{saif_file}" -strip_path tb_cpu/u_cpu\n')
                    f.write(f'}} else {{\n')
                    f.write(f'    puts "FATAL: {saif_file} not found. Run GLS first!"\n')
                    f.write(f'}}\n')
                    f.write(f'report_power -file {strategy_dir}/power.rpt\n')

        vivado_cmd = f"vivado -mode batch -source {tcl_path} -notrace"
        subprocess.run(vivado_cmd, shell=True)
        print(f"[{name}] Completed.")

if __name__ == "__main__":
    main()