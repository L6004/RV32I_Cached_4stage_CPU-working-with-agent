`timescale 1ns/1ps

import uvm_pkg::*;
import cpu_env_pkg::*;
`include "uvm_macros.svh"
module tb_cpu 
// `ifdef SIM
#(
    parameter L1_I_SIZE            = 8192,
    parameter L1_D_SIZE            = 8192,
    parameter L1_B_SIZE            = 32,
    parameter L2_SIZE              = 65536,
    parameter L2_B_SIZE            = 64,
    parameter L1_ASSOC             = 2,
    parameter L2_ASSOC             = 4,
    parameter L1_L2_BUS_BYTES      = 64,
    parameter DRAM_DELAY_CYCLES    = 2,
    parameter CACHE_DRAM_BUS_BYTES = 64,
    parameter RAM_SIZE             = 1048576,
    parameter FIFO_DEPTH           = 4
)
// `endif
();

    logic clk;
    logic rst_n;

    integer data_mem_idx;
    integer reg_idx;
    integer init_idx;
    cpu_interface vif();

    `ifndef POST_IMPL
    sva_interface sva_if();
    `endif

    string mem_file;

    `ifdef POST_IMPL
        `ifdef ENABLE_CACHE
            logic                              mem_req;
            logic                              mem_dram_we;
            logic [31:0]                       mem_addr;
            logic [CACHE_DRAM_BUS_BYTES*8-1:0] mem_wdata;
            logic [CACHE_DRAM_BUS_BYTES-1:0]   mem_wstrb;
            logic                              mem_ack;
            logic [CACHE_DRAM_BUS_BYTES*8-1:0] mem_rdata;
        `else
            logic                              inst_dram_req;
            logic [31:0]                       pc_reg;
            logic                              inst_ack_base;
            logic [31:0]                       if_instr;
            logic                              data_dram_req;
            logic                              mem_we;
            logic [31:0]                       memwb_alu_result;
            logic [31:0]                       mem_wdata_base;
            logic [3:0]                        mem_wstrb_base;
            logic                              data_ack_base;
            logic [31:0]                       ram_read_data_base;
        `endif
    `endif
    
    riscv_top 
    `ifdef ENABLE_CACHE
    #(
        .L1_I_SIZE            (L1_I_SIZE           ),
        .L1_D_SIZE            (L1_D_SIZE           ),
        .L1_B_SIZE            (L1_B_SIZE           ),
        .L2_SIZE              (L2_SIZE             ),
        .L2_B_SIZE            (L2_B_SIZE           ),
        .L1_ASSOC             (L1_ASSOC            ),
        .L2_ASSOC             (L2_ASSOC            ),
        .L1_L2_BUS_BYTES      (L1_L2_BUS_BYTES     ),
        .DRAM_DELAY_CYCLES    (DRAM_DELAY_CYCLES   ),
        .CACHE_DRAM_BUS_BYTES (CACHE_DRAM_BUS_BYTES),
        .RAM_SIZE             (RAM_SIZE            ),
        .FIFO_DEPTH           (FIFO_DEPTH          ))
    `endif
    u_cpu (
        .clk   (vif.clk  ), 
        .rst_n (vif.rst_n)

        `ifdef POST_IMPL
            `ifdef ENABLE_CACHE
            ,.mem_req    (mem_req    )
            ,.mem_dram_we(mem_dram_we)
            ,.mem_addr   (mem_addr   )
            ,.mem_wdata  (mem_wdata  )
            ,.mem_wstrb  (mem_wstrb  )
            ,.mem_ack    (mem_ack    )
            ,.mem_rdata  (mem_rdata  )
            `else
            ,.inst_dram_req     (inst_dram_req     )
            ,.pc_reg            (pc_reg            )
            ,.inst_ack_base     (inst_ack_base     )
            ,.if_instr          (if_instr          )
            ,.data_dram_req     (data_dram_req     )
            ,.mem_we            (mem_we            )
            ,.memwb_alu_result  (memwb_alu_result  )
            ,.mem_wdata_base    (mem_wdata_base    )
            ,.mem_wstrb_base    (mem_wstrb_base    )
            ,.data_ack_base     (data_ack_base     )
            ,.ram_read_data_base(ram_read_data_base)
            `endif
        `endif
    );

    `ifdef POST_IMPL
        `ifdef ENABLE_CACHE
            dram_behav #(
                .DELAY_CYCLES (DRAM_DELAY_CYCLES   ),
                .BUS_BYTES    (CACHE_DRAM_BUS_BYTES),
                .RAM_SIZE     (RAM_SIZE            )
            ) u_dram_behav_cache_tb (
                .clk   (clk        ),
                .rst_n (rst_n      ),
                .req   (mem_req    ),
                .we    (mem_dram_we),
                .addr  (mem_addr   ),
                .wdata (mem_wdata  ),
                .wstrb (mem_wstrb  ),
                .ack   (mem_ack    ),
                .rdata (mem_rdata  )
            );
        `else 
            dram_behav #(
                .DELAY_CYCLES (DRAM_DELAY_CYCLES),
                .BUS_BYTES    (4                ),
                .RAM_SIZE     (RAM_SIZE         )
            ) u_data_dram_base_tb (
                .clk   (clk               ),
                .rst_n (rst_n             ),
                .req   (data_dram_req     ),
                .we    (mem_we            ),
                .addr  (memwb_alu_result  ),
                .wdata (mem_wdata_base    ),
                .wstrb (mem_wstrb_base    ),
                .ack   (data_ack_base     ),
                .rdata (ram_read_data_base)
            );

            dram_behav #(
                .DELAY_CYCLES (DRAM_DELAY_CYCLES),
                .BUS_BYTES    (4                ),
                .RAM_SIZE     (RAM_SIZE         )
            ) u_inst_dram_base_tb (
                .clk   (clk          ),
                .rst_n (rst_n        ),
                .req   (inst_dram_req),
                .we    (1'b0         ),
                .addr  (pc_reg       ),
                .wdata (32'h0        ),
                .wstrb (4'h0         ),
                .ack   (inst_ack_base),
                .rdata (if_instr     )
            );
        `endif
    `endif

    assign vif.clk                    = clk;
    assign vif.rst_n                  = rst_n;

    `ifndef POST_IMPL
    assign sva_if.clk                 = clk;
    assign sva_if.rst_n               = rst_n;

    assign sva_if.commit_reg_we       = u_cpu.memwb_reg_write;
    assign sva_if.commit_mem_we       = u_cpu.mem_we;

    assign sva_if.commit_rd           = u_cpu.memwb_rd;
    assign sva_if.commit_pc           = u_cpu.memwb_pc;
    assign sva_if.commit_instr        = u_cpu.memwb_instr;
    assign sva_if.commit_valid        = (u_cpu.memwb_valid && !u_cpu.hazard_ex_mem_stall);

    assign sva_if.commit_reg_wdata    = u_cpu.wb_write_data;
    assign sva_if.commit_mem_wdata    = u_cpu.memwb_mem_write_data;
    assign sva_if.commit_mem_addr     = u_cpu.memwb_alu_result;
    
    assign sva_if.opcode              = u_cpu.memwb_opcode;
    assign sva_if.funct3              = u_cpu.id_ex_funct3;
    assign sva_if.funct7_5            = u_cpu.memwb_funct7_5;

    assign sva_if.hazard_pc_stall     = u_cpu.hazard_pc_stall;
    assign sva_if.hazard_if_id_stall  = u_cpu.hazard_if_id_stall;
    assign sva_if.hazard_id_ex_stall  = u_cpu.hazard_id_ex_stall;
    assign sva_if.hazard_ex_mem_stall = u_cpu.hazard_ex_mem_stall;
    assign sva_if.hazard_if_id_flush  = u_cpu.hazard_if_id_flush;
    assign sva_if.hazard_id_ex_flush  = u_cpu.hazard_id_ex_flush;
    assign sva_if.if_id_pc            = u_cpu.if_id_pc;
    assign sva_if.id_ex_pc            = u_cpu.id_ex_pc;
    assign sva_if.memwb_pc            = u_cpu.memwb_pc;
    assign sva_if.if_id_instr         = u_cpu.if_id_instr;
    assign sva_if.id_ex_valid         = u_cpu.id_ex_valid;

    assign sva_if.branch_taken        = u_cpu.ex_branch_taken;
    assign sva_if.is_branch_instr     = u_cpu.ctrl_branch || u_cpu.id_ex_branch;
    assign sva_if.pc_reg              = u_cpu.pc_reg;
    assign sva_if.ex_pc               = u_cpu.id_ex_pc;
    `endif

    initial begin
        clk = 1'b0;
        forever begin
            #8;
            clk = ~clk; // 62.5MHz
        end
    end

    `ifndef POST_IMPL
    integer trace_file;
    initial begin
        trace_file = $fopen("coverage_trace.txt", "w");
        $fdisplay(trace_file, "--- RISC-V Instruction Trace ---");
    end

    // 指令 Trace
    always @(posedge clk) begin
        if (rst_n && u_cpu.if_id_valid && !u_cpu.hazard_if_id_stall && !u_cpu.hazard_if_id_flush) begin
            $fdisplay(trace_file, "0x%8h |  0x%8h", u_cpu.if_id_pc, u_cpu.if_id_instr);
        end
    end
    `endif

    initial begin
        `ifdef ENABLE_DUMP
            `ifdef ENABLE_CACHE
                $dumpfile("tb_cpu_cache.vcd");
            `else
                $dumpfile("tb_cpu_base.vcd");
            `endif
            $dumpvars(0, tb_cpu);
        `endif

        `ifdef ENABLE_CACHE
            for (init_idx = 0; init_idx < RAM_SIZE; init_idx = init_idx + 1) begin
                `ifdef POST_IMPL
                    u_dram_behav_cache_tb.memory[init_idx] = 32'h0;
                `else
                    u_cpu.u_dram_behav_cache.memory[init_idx] = 32'h0;
                `endif
            end
            if ($value$plusargs("MEM_FILE=%s", mem_file)) begin
                `ifdef POST_IMPL
                    $readmemh(mem_file, u_dram_behav_cache_tb.memory);
                `else
                    $readmemh(mem_file, u_cpu.u_dram_behav_cache.memory);
                `endif
            end else begin
                `ifdef POST_IMPL
                    $readmemh("default.mem", u_dram_behav_cache_tb.memory);
                `else
                    $readmemh("default.mem", u_cpu.u_dram_behav_cache.memory);
                `endif
            end
            $display("=> DRAM initialized. All Caches are in COLD state.");
        `else
            if ($value$plusargs("MEM_FILE=%s", mem_file)) begin
                `ifdef POST_IMPL
                    $readmemh(mem_file, u_data_dram_base_tb.memory);
                    $readmemh(mem_file, u_inst_dram_base_tb.memory);
                `else
                    $readmemh(mem_file, u_cpu.u_data_dram_base.memory);
                    $readmemh(mem_file, u_cpu.u_inst_dram_base.memory);
                `endif
            end else begin
                `ifdef POST_IMPL
                    $readmemh("default.mem", u_data_dram_base_tb.memory);
                    $readmemh("default.mem", u_inst_dram_base_tb.memory);
                `else
                    $readmemh("default.mem", u_cpu.u_data_dram_base.memory);
                    $readmemh("default.mem", u_cpu.u_inst_dram_base.memory);
                `endif
            end
            $display("=> inst_rom initialized.");
        `endif

        rst_n = 0;

        `ifndef POST_IMPL
        u_cpu.u_regfile.rst_regs = 1;   // reg_file initialization
        $display("=> [Backdoor] reg_file cleared.");
        `endif

        `ifndef POST_IMPL
        #15;
        `else
        #200;
        `endif

        rst_n = 1;

        `ifndef POST_IMPL
        u_cpu.u_regfile.rst_regs = 0;
        `endif

        $display("=> System reset done.");
    end

    initial begin
        uvm_config_db#(virtual cpu_interface)::set(null, "uvm_test_top.*", "vif", vif);
        `ifndef POST_IMPL
        uvm_config_db#(virtual sva_interface)::set(null, "uvm_test_top.*", "sva_if", sva_if);
        `endif
        run_test("cpu_base_test");
    end

    `ifdef POST_IMPL
        initial begin
            #4000; // 设置一个超时时间 (例如 200us)
            $display("\n🏁 [GLS Exit] Reached timeout limit. Exiting Gate-Level Simulation.");
            $finish;
        end
    `else
    always @(posedge clk) begin
        // 监控 IF/ID 寄存器，如果取到的指令是 j . (0x0000006f)，认为测试结束
        if (rst_n && u_cpu.if_id_valid && u_cpu.if_id_instr == 32'h0000006f) begin
            $display("\n🏁 [Normal Exit] Detected 'j .' (0x0000006f) trap. Finishing simulation.");
            #100;
            $finish;
        end
    end

    // 监控死循环指令 (j . 即 0x0000006f)，自动输出性能报告
    always @(posedge clk) begin
        if (rst_n && u_cpu.if_id_instr == 32'h0000006f) begin
            real total_cycles;
            real total_stalls;
            real total_flushes;
            real ipc;
            real cpi;

            real total_l1i_hits;
            real total_l1i_misses;
            real total_l1d_hits;
            real total_l1d_misses;
            real total_l2_hits;
            real total_l2_misses;

            uvm_report_server svr;
            int uvm_err_cnt;
            int sva_err_cnt;
            int total_err;
            
            total_cycles  = u_cpu.cycle_cnt;
            total_stalls  = u_cpu.stall_cnt;
            total_flushes = u_cpu.flush_cnt;

            cpi = total_cycles / (total_cycles - total_stalls - 2*total_flushes);
            ipc = 1.0 / cpi;

            `ifdef ENABLE_CACHE
                total_l1i_hits   = u_cpu.l1i_hit_cnt;
                total_l1i_misses = u_cpu.l1i_miss_cnt;
                total_l1d_hits   = u_cpu.l1d_hit_cnt;
                total_l1d_misses = u_cpu.l1d_miss_cnt;
                total_l2_hits    = u_cpu.l2_hit_cnt;
                total_l2_misses  = u_cpu.l2_miss_cnt;
            `endif

            $display("=================================================");
            $display("               CPU PERFORMANCE REPORT              ");
            $display("=================================================");
            $display("Total Cycles           : %0d", u_cpu.cycle_cnt);
            $display("Total Stalls           : %0d", u_cpu.stall_cnt);
            $display("Total Flushes          : %0d", u_cpu.flush_cnt);
            $display("CPI                    : %.3f", cpi);
            $display("IPC                    : %.3f", ipc);
            `ifdef ENABLE_CACHE
                $display("Total L1 I-Cache hits  : %0d", u_cpu.l1i_hit_cnt);
                $display("Total L1 I-Cache misses: %0d", u_cpu.l1i_miss_cnt);
                $display("Total L1 D-Cache hits  : %0d", u_cpu.l1d_hit_cnt);
                $display("Total L1 D-Cache misses: %0d", u_cpu.l1d_miss_cnt);
                `ifdef ENABLE_L2
                    $display("Total L2 Cache hits    : %0d", u_cpu.l2_hit_cnt);
                    $display("Total L2 Cache misses  : %0d", u_cpu.l2_miss_cnt);
                `endif
            `endif
            $display("=================================================");
            
            svr = uvm_report_server::get_server();
            uvm_err_cnt = svr.get_severity_count(UVM_ERROR) + svr.get_severity_count(UVM_FATAL);
            sva_err_cnt = sva_if.sva_err_cnt;
            total_err = uvm_err_cnt + sva_err_cnt;

            $display("\n=======================================================");
            if (total_err == 0) begin
                $display("    ____   _    ____  ____  ");
                $display("   |  _ \\ / \\  / ___|/ ___| ");
                $display("   | |_) / _ \\ \\___ \\\\___ \\ ");
                $display("   |  __/ ___ \\ ___) |___) |");
                $display("   |_| /_/   \\_\\____/|____/ ");
                $display("                            ");
                $display("   [SUCCESS] All Tests Passed! (0 Errors)");
            end else begin
                $display("    _____ _    ___ _     ");
                $display("   |  ___/ \\  |_ _| |    ");
                $display("   | |_ / _ \\  | || |    ");
                $display("   |  _/ ___ \\ | || |___ ");
                $display("   |_|/_/   \\_\\___|_____|");
                $display("                         ");
                $display("   [FAILED] Found %0d Errors (%0d UVM, %0d SVA)", total_err, uvm_err_cnt, sva_err_cnt);
            end
            $display("=======================================================\n");

            $finish;
        end
    end
    `endif

endmodule