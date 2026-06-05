module riscv_top 
// `ifdef SIM
#(
// ===========================================================================
// CONFIGURABLE PARAMETERS
// ===========================================================================
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
(
    input         clk,
    input         rst_n

    `ifdef POST_IMPL
        `ifdef ENABLE_CACHE
        ,output                              mem_req
        ,output                              mem_dram_we
        ,output [31:0]                       mem_addr
        ,output [CACHE_DRAM_BUS_BYTES*8-1:0] mem_wdata
        ,output [CACHE_DRAM_BUS_BYTES-1:0]   mem_wstrb
        ,input                               mem_ack
        ,input  [CACHE_DRAM_BUS_BYTES*8-1:0] mem_rdata
        `else
        ,output                              inst_dram_req
        ,output [31:0]                       pc_reg
        ,input                               inst_ack_base
        ,input  [31:0]                       if_instr
        ,output                              data_dram_req
        ,output                              mem_we
        ,output [31:0]                       memwb_alu_result
        ,output [31:0]                       mem_wdata_base
        ,output [3:0]                        mem_wstrb_base
        ,input                               data_ack_base
        ,input  [31:0]                       ram_read_data_base
        `endif
    `endif

);
    
    // ===========================================================================
    // INTERNAL SIGNAL DECLARATION
    // ===========================================================================
    // --- Hazard & Forwarding Signals ---
    wire        hazard_pc_stall;
    wire        hazard_if_id_stall;
    wire        hazard_if_id_flush;
    wire        hazard_id_ex_flush;
    wire        hazard_id_ex_mem_read;
    wire        hazard_icache_stall;
    wire        hazard_dcache_stall;
    wire        hazard_id_ex_stall;
    wire        hazard_ex_mem_stall;
    wire [1:0]  fwd_rs1;
    wire [1:0]  fwd_rs2;

    // --- Branch/Jump Signals (From EX) ---
    wire        ex_branch_taken;
    wire [31:0] ex_branch_target;

    // --- IF Stage ---
    wire [31:0] pc_next;
    `ifndef POST_IMPL
        wire [31:0] pc_reg;
        wire [31:0] if_instr;
    `else
        `ifdef ENABLE_CACHE
            wire [31:0] pc_reg;
            wire [31:0] if_instr;
        `endif
    `endif

    // --- IF/ID pipeline regs ---
    wire [31:0] if_id_pc;
    wire [31:0] if_id_pc_d;
    wire [31:0] if_id_instr;
    wire [31:0] if_id_instr_d;
    wire        if_id_valid;
    wire        if_id_valid_d;
    wire        if_id_reg_en;

    // --- ID Stage ---
    wire [6:0]  id_opcode;
    wire [4:0]  id_rd;
    wire [2:0]  id_funct3;
    wire [9:0]  id_rs;
    wire [6:0]  id_funct7;
    wire [63:0] id_rs_data;
    wire [31:0] id_imm;
    wire        ctrl_alu_src_a;
    wire        ctrl_alu_src_b;
    wire        ctrl_mem_read;
    wire        ctrl_mem_write;
    wire        ctrl_mem_size;
    wire [2:0]  ctrl_mem_ctrl;
    wire        ctrl_reg_write;
    wire        ctrl_branch;
    wire        ctrl_jump;
    wire        ctrl_jalr;
    wire [3:0]  ctrl_alu_op;
    wire [5:0]  ctrl_alu_ctrl;
    wire [1:0]  ctrl_wb_src;
    wire [4:0]  memwb_rd;
    wire [31:0] wb_write_data;
    wire        memwb_reg_write;
    wire        rs1_valid;
    wire        rs2_valid;

    // --- ID/EX pipeline regs ---
    wire [31:0] id_ex_pc;
    wire [31:0] id_ex_instr;
    wire [63:0] id_ex_rs_data;
    wire [31:0] id_ex_imm;
    wire [4:0]  id_ex_rd;
    wire [9:0]  id_ex_rs;
    wire        id_ex_funct7_5;
    wire [2:0]  id_ex_funct3;
    wire        id_ex_alu_src_a;
    wire        id_ex_alu_src_b;
    wire [3:0]  id_ex_alu_op;
    wire [5:0]  id_ex_alu_ctrl;
    wire        id_ex_mem_read;
    wire        id_ex_mem_write;
    wire        id_ex_mem_size;
    wire [2:0]  id_ex_mem_ctrl;
    wire [1:0]  id_ex_wb_src;
    wire        id_ex_reg_write;
    wire        id_ex_branch;
    wire        id_ex_jump;
    wire        id_ex_jalr;
    wire        id_ex_valid;
    wire [6:0]  id_ex_opcode;

    // --- EX Stage ---
    wire [31:0] ex_alu_result;
    wire [31:0] ex_mem_write_data;
    wire        ex_branch;
    wire        ex_jump;

    // --- EX/MEM_WB pipeline regs ---
    wire [31:0] memwb_pc;
    wire [31:0] memwb_instr;
    `ifndef POST_IMPL
        wire [31:0] memwb_alu_result;
    `else
        `ifdef ENABLE_CACHE
            wire [31:0] memwb_alu_result;
        `endif
    `endif
    wire [31:0] memwb_mem_write_data;
    wire        memwb_mem_read;
    wire        memwb_mem_write;
    wire        memwb_mem_size;
    wire [1:0]  memwb_wb_src;
    wire        memwb_valid;
    wire [2:0]  memwb_mem_ctrl;
    wire [6:0]  memwb_opcode;
    wire [2:0]  memwb_funct3;
    wire        memwb_funct7_5;
    wire [31:0] cycle_cnt;
    wire [31:0] stall_cnt;
    wire [31:0] flush_cnt;
    wire [31:0] l1i_hit_cnt;
    wire [31:0] l1i_miss_cnt;
    wire [31:0] l1d_hit_cnt;
    wire [31:0] l1d_miss_cnt;
    wire [31:0] l2_hit_cnt;
    wire [31:0] l2_miss_cnt;

    // --- MEM_WB Stage ---
    wire [31:0] mem_read_data;
    wire [31:0] ram_read_data;
    `ifndef POST_IMPL
        wire        mem_we;
    `else
        `ifdef ENABLE_CACHE
            wire        mem_we;
        `endif
    `endif
    wire        is_perf_cnt;
    reg  [31:0] perf_cnt_data;

    // --- cache interface ---
    wire [31:0] cpu_i_rdata;
    wire        i_stall;
    wire        cpu_d_req;
    wire [31:0] cpu_d_rdata;
    wire        d_stall;
    wire        l1i_hit;
    wire        l1i_miss;
    wire        l1d_hit;
    wire        l1d_miss;
    wire        l2_hit_event;
    wire        l2_miss_event;

    // --- dram interface ---
    `ifndef POST_IMPL
    wire                              mem_req;
    wire                              mem_dram_we;
    wire [31:0]                       mem_addr;
    wire [CACHE_DRAM_BUS_BYTES*8-1:0] mem_wdata;
    wire [CACHE_DRAM_BUS_BYTES-1:0]   mem_wstrb;
    wire                              mem_ack;
    wire [CACHE_DRAM_BUS_BYTES*8-1:0] mem_rdata;
    `ifndef ENABLE_CACHE
        wire                          data_ack_base;
        wire [3:0]                    mem_wstrb_base;
        wire [31:0]                   mem_wdata_base;
        wire                          inst_ack_base;
        wire                          inst_dram_req;
        wire                          data_dram_req;
        wire [31:0]                   ram_read_data_base;
    `endif
    `endif
    `ifndef ENABLE_CACHE
        wire [7:0]                    ram_read_data_byte;
        reg                           inst_dram_req_state;   // 0: req hold, 1: ack clr
        reg                           data_dram_req_state;
        wire                          inst_dram_valid;
        wire                          data_dram_valid;
    `endif

    // ===========================================================================
    // 1. IF Stage
    // ===========================================================================
    // PC refresh: if encounter prediction error or jump, correct pc
    //             else pc += 4
    assign pc_next = ex_branch_taken ? ex_branch_target : 
                                       (pc_reg + 32'h4);
    riscv_BB_dfflr #(
        .DW      (32          ),
        .RST_VAL (32'h80000000)
    ) u_pc_ff (
        .clk   (clk             ),
        .rst_n (rst_n           ),
        .en    (!hazard_pc_stall),
        .din   (pc_next         ),
        .dout  (pc_reg          )
    );

    // ===========================================================================
    // IF/ID Pipeline Register
    // ===========================================================================
    // pipeline regs enable only when the pipeline is not stalled
    // or is flushed (all regs cleared)
    assign if_id_reg_en  = !hazard_if_id_stall;

    // input muxes
    assign if_id_pc_d    = hazard_if_id_flush ? 32'h0  : pc_reg;
    assign if_id_instr_d = hazard_if_id_flush ? 32'h13 : if_instr;
    assign if_id_valid_d = hazard_if_id_flush ? 1'b0   : 1'b1;

    // pipeline regs
    riscv_BB_dfflr #(
        .DW      (32          ),
        .RST_VAL (32'h80000000)
    ) u_if_id_pc_ff (
        .clk   (clk         ),
        .rst_n (rst_n       ),
        .en    (if_id_reg_en),
        .din   (if_id_pc_d  ),
        .dout  (if_id_pc    )
    );
    riscv_BB_dfflr #(
        .DW      (32    ),
        .RST_VAL (32'h13)
    ) u_if_id_instr_ff (
        .clk   (clk          ),
        .rst_n (rst_n        ),
        .en    (if_id_reg_en ),
        .din   (if_id_instr_d),
        .dout  (if_id_instr  )
    );
    riscv_BB_dfflr #(
        .DW      (1   ),
        .RST_VAL (1'b0)
    ) u_if_id_valid_ff (
        .clk   (clk          ),
        .rst_n (rst_n        ),
        .en    (if_id_reg_en ),
        .din   (if_id_valid_d),
        .dout  (if_id_valid  )
    );

    // ===========================================================================
    // 2. ID Stage
    // ===========================================================================
    assign id_opcode  = if_id_instr[6:0];
    assign id_rd      = if_id_instr[11:7];
    assign id_funct3  = if_id_instr[14:12];
    assign id_funct7  = if_id_instr[31:25];

    // rs1 is only used in R, I, Load/Store, B and JALR instructions
    assign rs1_valid = (id_opcode == 7'b0110011) || (id_opcode == 7'b0010011) || 
                       (id_opcode == 7'b0000011) || (id_opcode == 7'b0100011) || 
                       (id_opcode == 7'b1100011) || (id_opcode == 7'b1100111);
    // rs2 is only used in R, Store and B instructions
    assign rs2_valid = (id_opcode == 7'b0110011) || (id_opcode == 7'b0100011) || 
                       (id_opcode == 7'b1100011);

    assign id_rs[4:0] = rs1_valid ? if_id_instr[19:15] : 5'h0;
    assign id_rs[9:5] = rs2_valid ? if_id_instr[24:20] : 5'h0;
    
    // Write-First register file 
    // Solving conflict between WB write and ID read
    regfile u_regfile (
        .clk    (clk              ),
        .we     (memwb_reg_write  ),
        .waddr  (memwb_rd         ),
        .wdata  (wb_write_data    ),
        .raddr1 (id_rs[4:0]       ),
        .raddr2 (id_rs[9:5]       ),
        .rdata1 (id_rs_data[31:0] ),
        .rdata2 (id_rs_data[63:32])
    );

    // Immediate value generation
    imm_gen u_imm_gen (
        .instr (if_id_instr),
        .imm   (id_imm     )
    );

    // Control unit
    ctrl_unit u_ctrl_unit (
        .opcode    (id_opcode     ),
        .funct3    (id_funct3     ),
        .funct7    (id_funct7     ),
        .alu_src_a (ctrl_alu_src_a),
        .alu_src_b (ctrl_alu_src_b),
        .alu_op    (ctrl_alu_op   ),
        .mem_read  (ctrl_mem_read ),
        .mem_write (ctrl_mem_write),
        .mem_size  (ctrl_mem_size ),
        .reg_write (ctrl_reg_write),
        .wb_src    (ctrl_wb_src   ),
        .branch    (ctrl_branch   ),
        .jump      (ctrl_jump     ),
        .jalr      (ctrl_jalr     )
    );

    // ===========================================================================
    // ID/EX Pipeline Register
    // ===========================================================================
    assign ctrl_alu_ctrl   = {ctrl_alu_op, ctrl_alu_src_b, ctrl_alu_src_a};
    assign ctrl_mem_ctrl   = {ctrl_mem_size, ctrl_mem_write, ctrl_mem_read};
    assign id_ex_alu_src_a = id_ex_alu_ctrl[0];
    assign id_ex_alu_src_b = id_ex_alu_ctrl[1];
    assign id_ex_alu_op    = id_ex_alu_ctrl[5:2];
    assign id_ex_mem_read  = id_ex_mem_ctrl[0];
    assign id_ex_mem_write = id_ex_mem_ctrl[1];
    assign id_ex_mem_size  = id_ex_mem_ctrl[2];
    pipe_id_ex u_pipe_id_ex (
        .clk           (clk               ),
        .rst_n         (rst_n             ),
        .stall         (hazard_id_ex_stall),
        .flush         (hazard_id_ex_flush),
        .pc_in         (if_id_pc          ),
        .instr_in      (if_id_instr       ),
        .rs_data_in    (id_rs_data        ),
        .imm_in        (id_imm            ),
        .rd_in         (id_rd             ),
        .rs_in         (id_rs             ),
        .funct3_in     (id_funct3         ),
        .funct7_5_in   (id_funct7[5]      ),
        .alu_ctrl_in   (ctrl_alu_ctrl     ),
        .mem_ctrl_in   (ctrl_mem_ctrl     ),
        .wb_src_in     (ctrl_wb_src       ),
        .reg_write_in  (ctrl_reg_write    ),
        .branch_in     (ctrl_branch       ),
        .jump_in       (ctrl_jump         ),
        .jalr_in       (ctrl_jalr         ),
        .valid_in      (if_id_valid       ),
        .opcode_in     (id_opcode         ),
        .pc_out        (id_ex_pc          ),
        .instr_out     (id_ex_instr       ),
        .rs_data_out   (id_ex_rs_data     ),
        .imm_out       (id_ex_imm         ),
        .rd_out        (id_ex_rd          ),
        .rs_out        (id_ex_rs          ),
        .funct3_out    (id_ex_funct3      ),
        .funct7_5_out  (id_ex_funct7_5    ),
        .alu_ctrl_out  (id_ex_alu_ctrl    ),
        .mem_ctrl_out  (id_ex_mem_ctrl    ),
        .wb_src_out    (id_ex_wb_src      ),
        .reg_write_out (id_ex_reg_write   ),
        .branch_out    (id_ex_branch      ),
        .jump_out      (id_ex_jump        ),
        .jalr_out      (id_ex_jalr        ),
        .valid_out     (id_ex_valid       ),
        .opcode_out    (id_ex_opcode      )
    );
    
    // ===========================================================================
    // Hazard & Forwarding Unit
    // ===========================================================================
    assign hazard_id_ex_mem_read = (id_ex_mem_read && id_ex_valid);
    hazard_detection u_hazard (
        .id_ex_mem_read  (hazard_id_ex_mem_read),
        .id_ex_rd        (id_ex_rd             ),
        .if_id_rs1       (id_rs[4:0]           ),
        .if_id_rs2       (id_rs[9:5]           ),
        .ex_branch_taken (ex_branch_taken      ),
        .icache_stall    (hazard_icache_stall  ),
        .dcache_stall    (hazard_dcache_stall  ),
        .pc_stall        (hazard_pc_stall      ),
        .if_id_stall     (hazard_if_id_stall   ),
        .id_ex_stall     (hazard_id_ex_stall   ),
        .ex_mem_stall    (hazard_ex_mem_stall  ),
        .if_id_flush     (hazard_if_id_flush   ),
        .id_ex_flush     (hazard_id_ex_flush   )
    );

    // 4-Stage pipeline only need one stage forwarding
    // from MEM/WB to EX
    assign fwd_rs1 = (memwb_reg_write && 
                      (memwb_rd != 5'b0) && 
                      (memwb_rd == id_ex_rs[4:0])) ? 2'b01 
                                                   : 2'b00;
    assign fwd_rs2 = (memwb_reg_write && 
                      (memwb_rd != 5'b0) && 
                      (memwb_rd == id_ex_rs[9:5])) ? 2'b01 
                                                   : 2'b00;

    // ===========================================================================
    // 3. EX Stage
    // ===========================================================================
    assign ex_branch = (id_ex_branch && id_ex_valid);
    assign ex_jump   = (id_ex_jump && id_ex_valid);
    ex_stage u_ex_stage (
        .pc               (id_ex_pc            ),
        .rs1_data         (id_ex_rs_data[31:0] ),
        .rs2_data         (id_ex_rs_data[63:32]),
        .imm              (id_ex_imm           ),
        .alu_src_a        (id_ex_alu_src_a     ),
        .alu_src_b        (id_ex_alu_src_b     ),
        .alu_op           (id_ex_alu_op        ),
        .fwd_rs1          (fwd_rs1             ),
        .fwd_rs2          (fwd_rs2             ),
        .mem_wb_result    (wb_write_data       ),
        .branch           (ex_branch           ),
        .jump             (ex_jump             ),
        .jalr             (id_ex_jalr          ),
        .funct3           (id_ex_funct3        ),
        .alu_result       (ex_alu_result       ),
        .mem_write_data   (ex_mem_write_data   ),
        .ex_branch_taken  (ex_branch_taken     ),
        .ex_branch_target (ex_branch_target    )
    );

    // ===========================================================================
    // EX/MEM_WB Pipeline Register
    // ===========================================================================
    assign memwb_mem_read      = memwb_mem_ctrl[0];
    assign memwb_mem_write     = memwb_mem_ctrl[1];
    assign memwb_mem_size      = memwb_mem_ctrl[2];
    assign id_ex_mem_reg_write = (id_ex_reg_write & id_ex_valid);
    pipe_ex_mem u_pipe_ex_mem (
        .clk                (clk                 ),
        .rst_n              (rst_n               ),
        .stall              (hazard_ex_mem_stall ),
        .pc_in              (id_ex_pc            ),
        .instr_in           (id_ex_instr         ),
        .alu_result_in      (ex_alu_result       ),
        .mem_write_data_in  (ex_mem_write_data   ),
        .rd_in              (id_ex_rd            ),
        .ctrl_in            (id_ex_mem_ctrl      ),
        .wb_src_in          (id_ex_wb_src        ),
        .reg_write_in       (id_ex_mem_reg_write ),
        .valid_in           (id_ex_valid         ),
        .opcode_in          (id_ex_opcode        ),
        .funct3_in          (id_ex_funct3        ),
        .funct7_5_in        (id_ex_funct7_5      ),
        .pc_out             (memwb_pc            ),
        .instr_out          (memwb_instr         ),
        .alu_result_out     (memwb_alu_result    ),
        .mem_write_data_out (memwb_mem_write_data),
        .rd_out             (memwb_rd            ),
        .ctrl_out           (memwb_mem_ctrl      ),
        .wb_src_out         (memwb_wb_src        ),
        .reg_write_out      (memwb_reg_write     ),
        .valid_out          (memwb_valid         ),
        .hazard_stall       (hazard_pc_stall     ),
        .hazard_flush       (hazard_id_ex_flush  ),
        .cycle_cnt          (cycle_cnt           ),
        .stall_cnt          (stall_cnt           ),
        .flush_cnt          (flush_cnt           ),
        .opcode_out         (memwb_opcode        ),
        .funct3_out         (memwb_funct3        ),
        .funct7_5_out       (memwb_funct7_5      ),
        .l1i_hit            (l1i_hit             ),
        .l1i_miss           (l1i_miss            ),
        .l1d_hit            (l1d_hit             ),
        .l1d_miss           (l1d_miss            ),
        .l2_hit             (l2_hit_event        ),
        .l2_miss            (l2_miss_event       ),
        .l1i_hit_cnt        (l1i_hit_cnt         ),
        .l1i_miss_cnt       (l1i_miss_cnt        ),
        .l1d_hit_cnt        (l1d_hit_cnt         ),
        .l1d_miss_cnt       (l1d_miss_cnt        ),
        .l2_hit_cnt         (l2_hit_cnt          ),
        .l2_miss_cnt        (l2_miss_cnt         )
    );

    // ===========================================================================
    // 4. MEM & WB Stage
    // ===========================================================================
    // data memory, supporting byte approach
    assign mem_we = memwb_mem_write && memwb_valid;
    `ifndef ENABLE_CACHE
    assign ram_read_data_byte = (memwb_alu_result[1:0] == 2'b00) ? ram_read_data_base[7:0]   :
                                (memwb_alu_result[1:0] == 2'b01) ? ram_read_data_base[15:8]  :
                                (memwb_alu_result[1:0] == 2'b10) ? ram_read_data_base[23:16] :
                                                                   ram_read_data_base[31:24];
    assign ram_read_data = memwb_mem_size ? {{24{ram_read_data_byte[7]}}, ram_read_data_byte} 
                                          : ram_read_data_base;
    `endif

    // reserve data memory addrs for performance counters
    // assign mem_read_data = (memwb_alu_result == 32'h80001000) ? cycle_cnt    :
    //                        (memwb_alu_result == 32'h80001004) ? stall_cnt    :
    //                        (memwb_alu_result == 32'h80001008) ? flush_cnt    : 
    //                        (memwb_alu_result == 32'h8000100C) ? l1i_hit_cnt  :
    //                        (memwb_alu_result == 32'h80001010) ? l1i_miss_cnt :
    //                        (memwb_alu_result == 32'h80001014) ? l1d_hit_cnt  :
    //                        (memwb_alu_result == 32'h80001018) ? l1d_miss_cnt :
    //                        (memwb_alu_result == 32'h8000101C) ? l2_hit_cnt   :
    //                        (memwb_alu_result == 32'h80001020) ? l2_miss_cnt  :
    //                        ram_read_data;
    assign is_perf_cnt = (memwb_alu_result[31:8] == 24'h800010);
    always @(*) begin
        case (memwb_alu_result[7:0])
            8'h00: perf_cnt_data = cycle_cnt;
            8'h04: perf_cnt_data = stall_cnt;
            8'h08: perf_cnt_data = flush_cnt;
            8'h0C: perf_cnt_data = l1i_hit_cnt;
            8'h10: perf_cnt_data = l1i_miss_cnt;
            8'h14: perf_cnt_data = l1d_hit_cnt;
            8'h18: perf_cnt_data = l1d_miss_cnt;
            8'h1C: perf_cnt_data = l2_hit_cnt;
            8'h20: perf_cnt_data = l2_miss_cnt;
            default: perf_cnt_data = 32'h0;
        endcase
    end
    assign mem_read_data = is_perf_cnt ? perf_cnt_data : ram_read_data;
    
    // Write-Back MUX
    // assign wb_write_data = (memwb_wb_src == 2'b00) ? memwb_alu_result   : 
    //                        (memwb_wb_src == 2'b01) ? mem_read_data      :
    //                        (memwb_wb_src == 2'b10) ? (memwb_pc + 32'h4) : 
    //                        32'h0;
    assign wb_write_data = (memwb_wb_src == 2'b00) ? memwb_alu_result : 
                           (memwb_wb_src == 2'b10) ? (memwb_pc + 32'h4) : 
                           (is_perf_cnt)           ? perf_cnt_data : 
                           ram_read_data;
    
    // ===========================================================================
    // CACHE INSTANCE
    // ===========================================================================
    assign cpu_d_req = (memwb_mem_read || memwb_mem_write);
    `ifdef ENABLE_CACHE        
        cache_system_top #(
            .L1_I_SIZE         (L1_I_SIZE           ),
            .L1_D_SIZE         (L1_D_SIZE           ),
            .L1_B_SIZE         (L1_B_SIZE           ),
            .L2_SIZE           (L2_SIZE             ),
            .L2_B_SIZE         (L2_B_SIZE           ),
            .L1_ASSOC          (L1_ASSOC            ),
            .L2_ASSOC          (L2_ASSOC            ),
            .L1_L2_BUS_BYTES   (L1_L2_BUS_BYTES     ),
            .L2_DRAM_BUS_BYTES (CACHE_DRAM_BUS_BYTES),
            .FIFO_DEPTH        (FIFO_DEPTH          )
        ) u_cache_system_top (
            .clk           (clk                 ),
            .rst_n         (rst_n               ),
            .cpu_i_req     (1'b1                ),
            .cpu_i_addr    (pc_reg              ),
            .cpu_i_rdata   (if_instr            ),
            .i_stall       (hazard_icache_stall ),
            .cpu_d_req     (cpu_d_req           ),
            .cpu_d_we      (mem_we              ),
            .cpu_d_addr    (memwb_alu_result    ),
            .cpu_d_wdata   (memwb_mem_write_data),
            .cpu_d_size    (memwb_mem_size      ),
            .cpu_d_rdata   (ram_read_data       ),
            .d_stall       (hazard_dcache_stall ),
            .l1i_hit       (l1i_hit             ),
            .l1i_miss      (l1i_miss            ),
            .l1d_hit       (l1d_hit             ),
            .l1d_miss      (l1d_miss            ),
            .l2_hit_event  (l2_hit_event        ),
            .l2_miss_event (l2_miss_event       ),
            .mem_ack       (mem_ack             ),
            .mem_rdata     (mem_rdata           ),
            .mem_req       (mem_req             ),
            .mem_we        (mem_dram_we         ),
            .mem_addr      (mem_addr            ),
            .mem_wdata     (mem_wdata           ),
            .mem_wstrb     (mem_wstrb           )
        );
    `else
        assign hazard_icache_stall = !inst_dram_valid;
        assign hazard_dcache_stall = (cpu_d_req && !data_dram_valid);
    `endif

    // ===========================================================================
    // DRAM INSTANCE (behavioral)
    // ===========================================================================
        `ifdef ENABLE_CACHE
            `ifndef POST_IMPL
            dram_behav #(
                .DELAY_CYCLES (DRAM_DELAY_CYCLES   ),
                .BUS_BYTES    (CACHE_DRAM_BUS_BYTES),
                .RAM_SIZE     (RAM_SIZE            )
            ) u_dram_behav_cache (
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
            `endif
        `else 
            assign mem_wstrb_base = (memwb_mem_size ? (4'b0001 << memwb_alu_result[1:0]) 
                                                    : 4'b1111);
            assign mem_wdata_base = (memwb_mem_size ? {4{memwb_mem_write_data[7:0]}} 
                                                    : memwb_mem_write_data);
            // ===========================================================================
            // DATA DRAM FOR BASE
            // ===========================================================================
            // DRAM request/valid control FSM
            always@ (posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    data_dram_req_state <= 1'b1;
                end
                else begin
                    if ((data_dram_req_state == 1'b0) && 
                        data_ack_base &&
                        !hazard_icache_stall) begin
                            data_dram_req_state <= 1'b1;
                    end
                    else if ((data_dram_req_state == 1'b1) &&
                             !data_ack_base &&
                             cpu_d_req) begin
                                data_dram_req_state <= 1'b0;
                    end
                end
            end
            assign data_dram_req   = (data_dram_req_state == 1'b0);
            assign data_dram_valid = (data_dram_req && data_ack_base);
            `ifndef POST_IMPL
            dram_behav #(
                .DELAY_CYCLES (DRAM_DELAY_CYCLES),
                .BUS_BYTES    (4                ),
                .RAM_SIZE     (RAM_SIZE         )
            ) u_data_dram_base (
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
            `endif
            // ===========================================================================
            // INSTRUCTION DRAM FOR BASE
            // ===========================================================================
            // DRAM request/valid control FSM
            always@ (posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    inst_dram_req_state <= 1'b0;
                end
                else begin
                    if ((inst_dram_req_state == 1'b0) && 
                        inst_ack_base &&
                        !hazard_dcache_stall) begin
                            inst_dram_req_state <= 1'b1;
                    end
                    else if ((inst_dram_req_state == 1'b1) &&
                             !inst_ack_base) begin
                                inst_dram_req_state <= 1'b0;
                    end
                end
            end
            assign inst_dram_req   = (inst_dram_req_state == 1'b0);
            assign inst_dram_valid = (inst_dram_req && inst_ack_base);
            `ifndef POST_IMPL
            dram_behav #(
                .DELAY_CYCLES (DRAM_DELAY_CYCLES),
                .BUS_BYTES    (4                ),
                .RAM_SIZE     (RAM_SIZE         )
            ) u_inst_dram_base (
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
endmodule