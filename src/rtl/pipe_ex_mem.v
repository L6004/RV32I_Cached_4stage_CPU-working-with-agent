module pipe_ex_mem (
// ===========================================================================
// PIPELINE REGS
// ===========================================================================
    input         clk,
    input         rst_n,
    input         stall,
    input  [31:0] pc_in,
    input  [31:0] instr_in,
    input  [31:0] alu_result_in,
    input  [31:0] mem_write_data_in,
    input  [4:0]  rd_in,
    input  [2:0]  ctrl_in,
    input  [1:0]  wb_src_in,
    input         reg_write_in,
    input         valid_in,
    input  [6:0]  opcode_in,
    input  [2:0]  funct3_in,
    input         funct7_5_in,
    output [31:0] pc_out,
    output [31:0] instr_out,
    output [31:0] alu_result_out,
    output [31:0] mem_write_data_out,
    output [4:0]  rd_out,
    output [2:0]  ctrl_out,
    output [1:0]  wb_src_out,
    output        reg_write_out,
    output        valid_out,
    output [6:0]  opcode_out,
    output [2:0]  funct3_out,
    output        funct7_5_out,

// ===========================================================================
// PERFORMANCE COUNTERS
// ===========================================================================
    input         hazard_stall,
    input         hazard_flush,
    output [31:0] cycle_cnt,
    output [31:0] stall_cnt,
    output [31:0] flush_cnt,
    input         l1i_hit,
    input         l1i_miss,
    input         l1d_hit,
    input         l1d_miss,
    input         l2_hit,
    input         l2_miss,
    output [31:0] l1i_hit_cnt,
    output [31:0] l1i_miss_cnt,
    output [31:0] l1d_hit_cnt,
    output [31:0] l1d_miss_cnt,
    output [31:0] l2_hit_cnt,
    output [31:0] l2_miss_cnt
);

// ===========================================================================
// INTERNAL SIGNAL DECLARATION
// ===========================================================================
    wire [31:0] stall_cnt_d;
    wire [31:0] flush_cnt_d;
    wire [31:0] cycle_cnt_d;
    wire [31:0] l1i_hit_cnt_d;
    wire [31:0] l1i_miss_cnt_d;
    wire [31:0] l1d_hit_cnt_d;
    wire [31:0] l1d_miss_cnt_d;
    wire [31:0] l2_hit_cnt_d;
    wire [31:0] l2_miss_cnt_d;
    wire        ex_mem_en;
    reg         l1i_counted;
    reg         l1d_counted;
    reg         l2_miss_active;
    wire        is_load;
    wire        is_store;
    wire        dcache_req;
    wire        l1i_hit_valid;
    wire        l1i_miss_valid;
    wire        l1d_hit_valid;
    wire        l1d_miss_valid;
    wire        l2_hit_valid;
    wire        l2_miss_valid;
    wire        hazard_stall_reg;
    wire        hazard_flush_reg;
    wire        l1i_hit_reg;
    wire        l1i_miss_reg;
    wire        l1d_hit_reg;
    wire        l1d_miss_reg;
    wire        l2_hit_reg;
    wire        l2_miss_reg;
    
// ===========================================================================
// ENABLE
// ===========================================================================
    assign ex_mem_en = !stall;

// ===========================================================================
// PIPELINE REGS
// ===========================================================================
    riscv_BB_dfflr #(
        .DW      (32          ),
        .RST_VAL (32'h80000000)
    ) u_pc_ff (
        .clk   (clk      ),
        .rst_n (rst_n    ),
        .en    (ex_mem_en),
        .din   (pc_in    ),
        .dout  (pc_out   )
    );
    riscv_BB_dfflr #(
        .DW      (32    ),
        .RST_VAL (32'h13)
    ) u_instr_ff (
        .clk   (clk      ),
        .rst_n (rst_n    ),
        .en    (ex_mem_en),
        .din   (instr_in ),
        .dout  (instr_out)
    );
    riscv_BB_dfflr #(
        .DW      (32   ),
        .RST_VAL (32'h0)
    ) u_alu_result_ff (
        .clk   (clk           ),
        .rst_n (rst_n         ),
        .en    (ex_mem_en     ),
        .din   (alu_result_in ),
        .dout  (alu_result_out)
    );
    riscv_BB_dfflr #(
        .DW      (32   ),
        .RST_VAL (32'h0)
    ) u_mem_write_data_ff (
        .clk   (clk               ),
        .rst_n (rst_n             ),
        .en    (ex_mem_en         ),
        .din   (mem_write_data_in ),
        .dout  (mem_write_data_out)
    );
    riscv_BB_dfflr #(
        .DW      (5   ),
        .RST_VAL (5'h0)
    ) u_rd_ff (
        .clk   (clk      ),
        .rst_n (rst_n    ),
        .en    (ex_mem_en),
        .din   (rd_in    ),
        .dout  (rd_out   )
    );
    riscv_BB_dfflr #(
        .DW      (3   ),
        .RST_VAL (3'h0)
    ) u_ctrl_ff (
        .clk   (clk      ),
        .rst_n (rst_n    ),
        .en    (ex_mem_en),
        .din   (ctrl_in  ),
        .dout  (ctrl_out )
    );
    riscv_BB_dfflr #(
        .DW      (2   ),
        .RST_VAL (2'h0)
    ) u_wb_src_ff (
        .clk   (clk       ),
        .rst_n (rst_n     ),
        .en    (ex_mem_en ),
        .din   (wb_src_in ),
        .dout  (wb_src_out)
    );
    riscv_BB_dfflr #(
        .DW      (1   ),
        .RST_VAL (1'h0)
    ) u_reg_write_ff (
        .clk   (clk          ),
        .rst_n (rst_n        ),
        .en    (ex_mem_en    ),
        .din   (reg_write_in ),
        .dout  (reg_write_out)
    );
    riscv_BB_dfflr #(
        .DW      (1   ),
        .RST_VAL (1'b0)
    ) u_valid_ff (
        .clk   (clk      ),
        .rst_n (rst_n    ),
        .en    (ex_mem_en),
        .din   (valid_in ),
        .dout  (valid_out)
    );
    riscv_BB_dfflr #(
        .DW      (7   ),
        .RST_VAL (7'h0)
    ) u_opcode_ff (
        .clk   (clk       ),
        .rst_n (rst_n     ),
        .en    (ex_mem_en ),
        .din   (opcode_in ),
        .dout  (opcode_out)
    );
    riscv_BB_dfflr #(
        .DW      (1   ),
        .RST_VAL (1'b0)
    ) u_funct7_5_ff (
        .clk   (clk         ),
        .rst_n (rst_n       ),
        .en    (ex_mem_en   ),
        .din   (funct7_5_in ),
        .dout  (funct7_5_out)
    );

// ===========================================================================
// PERFORMANCE COUNTERS
// ===========================================================================
   assign stall_cnt_d = hazard_stall_reg ? (stall_cnt + 32'h1) : stall_cnt;
   assign flush_cnt_d = hazard_flush_reg ? (flush_cnt + 32'h1) : flush_cnt;
   assign cycle_cnt_d = (cycle_cnt + 32'h1);
   riscv_BB_dffr #(
        .DW      (32   ),
        .RST_VAL (32'h0)
   ) u_stall_cnt_ff (
        .clk   (clk        ),
        .rst_n (rst_n      ),
        .din   (stall_cnt_d),
        .dout  (stall_cnt  )
    ); 
    riscv_BB_dffr #(
        .DW      (32   ),
        .RST_VAL (32'h0)
   ) u_flush_cnt_ff (
        .clk   (clk        ),
        .rst_n (rst_n      ),
        .din   (flush_cnt_d),
        .dout  (flush_cnt  )
    ); 
    riscv_BB_dffr #(
        .DW      (32   ),
        .RST_VAL (32'h0)
    ) u_cycle_cnt_ff (
        .clk   (clk        ),
        .rst_n (rst_n      ),
        .din   (cycle_cnt_d),
        .dout  (cycle_cnt  )
    ); 

    // ---------------------------------------------------------------------------
    // DELAYED HAZARD CONTROL SIGNAL & HIT/MISS SIGNAL
    // ---------------------------------------------------------------------------
    riscv_BB_dffr #(
        .DW      (1   ),
        .RST_VAL (1'b0)
    ) u_stall_ff (
        .clk   (clk             ),
        .rst_n (rst_n           ),
        .din   (hazard_stall    ),
        .dout  (hazard_stall_reg)
    );
    riscv_BB_dffr #(
        .DW      (1   ),
        .RST_VAL (1'b0)
    ) u_flush_ff (
        .clk   (clk             ),
        .rst_n (rst_n           ),
        .din   (hazard_flush    ),
        .dout  (hazard_flush_reg)
    );
    riscv_BB_dffr #(
        .DW      (1   ),
        .RST_VAL (1'b0)
    ) u_l1i_hit_ff (
        .clk   (clk        ),
        .rst_n (rst_n      ),
        .din   (l1i_hit    ),
        .dout  (l1i_hit_reg)
    );
    riscv_BB_dffr #(
        .DW      (1   ),
        .RST_VAL (1'b0)
    ) u_l1i_miss_ff (
        .clk   (clk         ),
        .rst_n (rst_n       ),
        .din   (l1i_miss    ),
        .dout  (l1i_miss_reg)
    );
    riscv_BB_dffr #(
        .DW      (1   ),
        .RST_VAL (1'b0)
    ) u_l1d_hit_ff (
        .clk   (clk        ),
        .rst_n (rst_n      ),
        .din   (l1d_hit    ),
        .dout  (l1d_hit_reg)
    );
    riscv_BB_dffr #(
        .DW      (1   ),
        .RST_VAL (1'b0)
    ) u_l1d_miss_ff (
        .clk   (clk         ),
        .rst_n (rst_n       ),
        .din   (l1d_miss    ),
        .dout  (l1d_miss_reg)
    );
    riscv_BB_dffr #(
        .DW      (1   ),
        .RST_VAL (1'b0)
    ) u_l2_hit_ff (
        .clk   (clk       ),
        .rst_n (rst_n     ),
        .din   (l2_hit    ),
        .dout  (l2_hit_reg)
    );
    riscv_BB_dffr #(
        .DW      (1   ),
        .RST_VAL (1'b0)
    ) u_l2_miss_ff (
        .clk   (clk        ),
        .rst_n (rst_n      ),
        .din   (l2_miss    ),
        .dout  (l2_miss_reg)
    );

    // ---------------------------------------------------------------------------
    // REJECT DUPLICATED STALL COUNT AND FAKE HIT
    // ---------------------------------------------------------------------------
    assign is_load    = (opcode_out == 7'h03);
    assign is_store   = (opcode_out == 7'h23);
    assign dcache_req = is_load | is_store;

    // L1 counter locker (reject duplicated stall)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            l1i_counted <= 1'b0;
            l1d_counted <= 1'b0;
        end else if (!stall) begin
            l1i_counted <= 1'b0;
            l1d_counted <= 1'b0;
        end else begin
            if (l1i_hit_reg || l1i_miss_reg) begin
                l1i_counted <= 1'b1;
            end
            if (l1d_hit_reg || l1d_miss_reg) begin
                l1d_counted <= 1'b1;
            end
        end
    end
    // valid pulse generation
    assign l1i_hit_valid  = (l1i_hit_reg  && !l1i_counted);
    assign l1i_miss_valid = (l1i_miss_reg && !l1i_counted);
    assign l1d_hit_valid  = (l1d_hit_reg  && !l1d_counted && dcache_req);
    assign l1d_miss_valid = (l1d_miss_reg && !l1d_counted && dcache_req);

    // L2 fake hit fliter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            l2_miss_active <= 1'b0;
        end else if (l2_miss_reg) begin
            l2_miss_active <= 1'b1;
        end else if (l2_hit_reg && l2_miss_active) begin
            l2_miss_active <= 1'b0;
        end
    end
    // valid pulse generation
    assign l2_hit_valid   = (l2_hit_reg && !l2_miss_active);
    assign l2_miss_valid  = l2_miss_reg;

    // use valid pulse for counter MUX
    assign l1i_hit_cnt_d  = l1i_hit_valid  ? (l1i_hit_cnt + 32'h1)  : l1i_hit_cnt;
    assign l1i_miss_cnt_d = l1i_miss_valid ? (l1i_miss_cnt + 32'h1) : l1i_miss_cnt;
    assign l1d_hit_cnt_d  = l1d_hit_valid  ? (l1d_hit_cnt + 32'h1)  : l1d_hit_cnt;
    assign l1d_miss_cnt_d = l1d_miss_valid ? (l1d_miss_cnt + 32'h1) : l1d_miss_cnt;
    assign l2_hit_cnt_d   = l2_hit_valid   ? (l2_hit_cnt + 32'h1)   : l2_hit_cnt;
    assign l2_miss_cnt_d  = l2_miss_valid  ? (l2_miss_cnt + 32'h1)  : l2_miss_cnt;
    
    riscv_BB_dffr #(
        .DW      (32   ),
        .RST_VAL (32'h0)
    ) u_l1i_hit_cnt_ff (
        .clk   (clk          ),
        .rst_n (rst_n        ),
        .din   (l1i_hit_cnt_d),
        .dout  (l1i_hit_cnt  )
    ); 
    riscv_BB_dffr #(
        .DW      (32   ),
        .RST_VAL (32'h0)
    ) u_l1i_miss_cnt_ff (
        .clk   (clk           ),
        .rst_n (rst_n         ),
        .din   (l1i_miss_cnt_d),
        .dout  (l1i_miss_cnt  )
    ); 
    riscv_BB_dffr #(
        .DW      (32   ),
        .RST_VAL (32'h0)
    ) u_l1d_hit_cnt_ff (
        .clk   (clk          ),
        .rst_n (rst_n        ),
        .din   (l1d_hit_cnt_d),
        .dout  (l1d_hit_cnt  )
    ); 
    riscv_BB_dffr #(
        .DW      (32   ),
        .RST_VAL (32'h0)
    ) u_l1d_miss_cnt_ff (
        .clk   (clk           ),
        .rst_n (rst_n         ),
        .din   (l1d_miss_cnt_d),
        .dout  (l1d_miss_cnt  )
    ); 
    riscv_BB_dffr #(
        .DW      (32   ),
        .RST_VAL (32'h0)
    ) u_l2_hit_cnt_ff (
        .clk   (clk         ),
        .rst_n (rst_n       ),
        .din   (l2_hit_cnt_d),
        .dout  (l2_hit_cnt  )
    ); 
    riscv_BB_dffr #(
        .DW      (32   ),
        .RST_VAL (32'h0)
    ) u_l2_miss_cnt_ff (
        .clk   (clk          ),
        .rst_n (rst_n        ),
        .din   (l2_miss_cnt_d),
        .dout  (l2_miss_cnt  )
    ); 

endmodule