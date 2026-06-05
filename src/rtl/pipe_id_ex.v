module pipe_id_ex (
    input         clk,
    input         rst_n,
    input         stall,
    input         flush,
    input  [31:0] pc_in,
    input  [31:0] instr_in,
    input  [63:0] rs_data_in,
    input  [31:0] imm_in,
    input  [4:0]  rd_in,
    input  [9:0]  rs_in,
    input  [2:0]  funct3_in,
    input         funct7_5_in,
    input  [5:0]  alu_ctrl_in,
    input  [2:0]  mem_ctrl_in,
    input  [1:0]  wb_src_in,
    input         reg_write_in,
    input         branch_in,
    input         jump_in,
    input         jalr_in,
    input         valid_in,
    input  [6:0]  opcode_in,
    output [31:0] pc_out,
    output [31:0] instr_out,
    output [63:0] rs_data_out,
    output [31:0] imm_out,
    output [4:0]  rd_out,
    output [9:0]  rs_out,
    output [2:0]  funct3_out,
    output        funct7_5_out,
    output [5:0]  alu_ctrl_out,
    output [2:0]  mem_ctrl_out,
    output [1:0]  wb_src_out,
    output        reg_write_out,
    output        branch_out,
    output        jump_out,
    output        jalr_out,
    output        valid_out,
    output [6:0]  opcode_out
);

// ===========================================================================
// INTERNAL SIGNAL DECLARATION
// ===========================================================================
    wire       id_ex_en;
    wire       valid_d;
    wire       reg_write_d;
    wire [2:0] mem_ctrl_d;
    wire       branch_d;
    wire       jump_d;
    wire       jalr_d;
    wire [1:0] wb_src_d;

// ===========================================================================
// ENABLE
// ===========================================================================
    assign id_ex_en = !stall;

// ===========================================================================
// INPUT MUX FOR PIPELINE FLUSH
// ===========================================================================
    assign valid_d     = flush ? 1'b0 : valid_in;
    assign reg_write_d = flush ? 1'b0 : reg_write_in;
    assign mem_ctrl_d  = flush ? 3'b0 : mem_ctrl_in;
    assign branch_d    = flush ? 1'b0 : branch_in;
    assign jump_d      = flush ? 1'b0 : jump_in;
    assign jalr_d      = flush ? 1'b0 : jalr_in;
    assign wb_src_d    = flush ? 2'b0 : wb_src_in;

// ===========================================================================
// REGISTER INSTANCES
// ===========================================================================
    riscv_BB_dfflr #(
        .DW      (32          ),
        .RST_VAL (32'h80000000)
    ) u_pc_ff (
        .clk   (clk     ),
        .rst_n (rst_n   ),
        .en    (id_ex_en),
        .din   (pc_in   ),
        .dout  (pc_out  )
    );
    riscv_BB_dfflr #(
        .DW      (32    ),
        .RST_VAL (32'h13)
    ) u_instr_ff (
        .clk   (clk      ),
        .rst_n (rst_n    ),
        .en    (id_ex_en ),
        .din   (instr_in ),
        .dout  (instr_out)
    );
    riscv_BB_dfflr #(
        .DW      (64   ),
        .RST_VAL (64'h0)
    ) u_rs_data_ff (
        .clk   (clk        ),
        .rst_n (rst_n      ),
        .en    (id_ex_en   ),
        .din   (rs_data_in ),
        .dout  (rs_data_out)
    );
    riscv_BB_dfflr #(
        .DW      (32   ),
        .RST_VAL (32'h0)
    ) u_imm_ff (
        .clk   (clk     ),
        .rst_n (rst_n   ),
        .en    (id_ex_en),
        .din   (imm_in  ),
        .dout  (imm_out )
    );
    riscv_BB_dfflr #(
        .DW      (5   ),
        .RST_VAL (5'h0)
    ) u_rd_ff (
        .clk   (clk     ),
        .rst_n (rst_n   ),
        .en    (id_ex_en),
        .din   (rd_in   ),
        .dout  (rd_out  )
    );
    riscv_BB_dfflr #(
        .DW      (10   ),
        .RST_VAL (10'h0)
    ) u_rs_ff (
        .clk   (clk     ),
        .rst_n (rst_n   ),
        .en    (id_ex_en),
        .din   (rs_in   ),
        .dout  (rs_out  )
    );
    riscv_BB_dfflr #(
        .DW      (3   ),
        .RST_VAL (3'h0)
    ) u_funct3_ff (
        .clk   (clk       ),
        .rst_n (rst_n     ),
        .en    (id_ex_en  ),
        .din   (funct3_in ),
        .dout  (funct3_out)
    );
    riscv_BB_dfflr #(
        .DW      (1   ),
        .RST_VAL (1'b0)
    ) u_funct7_5_ff (
        .clk   (clk         ),
        .rst_n (rst_n       ),
        .en    (id_ex_en    ),
        .din   (funct7_5_in ),
        .dout  (funct7_5_out)
    );
    riscv_BB_dfflr #(
        .DW      (6   ),
        .RST_VAL (6'h0)
    ) u_alu_ctrl_ff (
        .clk   (clk         ),
        .rst_n (rst_n       ),
        .en    (id_ex_en    ),
        .din   (alu_ctrl_in ),
        .dout  (alu_ctrl_out)
    );
    riscv_BB_dfflr #(
        .DW      (3   ),
        .RST_VAL (3'h0)
    ) u_mem_ctrl_ff (
        .clk   (clk         ),
        .rst_n (rst_n       ),
        .en    (id_ex_en    ),
        .din   (mem_ctrl_d  ),
        .dout  (mem_ctrl_out)
    );
    riscv_BB_dfflr #(
        .DW      (2   ),
        .RST_VAL (2'h0)
    ) u_wb_src_ff (
        .clk   (clk       ),
        .rst_n (rst_n     ),
        .en    (id_ex_en  ),
        .din   (wb_src_d  ),
        .dout  (wb_src_out)
    );
    riscv_BB_dfflr #(
        .DW      (1   ),
        .RST_VAL (1'b0)
    ) u_reg_write_ff (
        .clk   (clk          ),
        .rst_n (rst_n        ),
        .en    (id_ex_en     ),
        .din   (reg_write_d  ),
        .dout  (reg_write_out)
    );
    riscv_BB_dfflr #(
        .DW      (1   ),
        .RST_VAL (1'b0)
    ) u_branch_ff (
        .clk   (clk       ),
        .rst_n (rst_n     ),
        .en    (id_ex_en  ),
        .din   (branch_d  ),
        .dout  (branch_out)
    );
    riscv_BB_dfflr #(
        .DW      (1   ),
        .RST_VAL (1'b0)
    ) u_jump_ff (
        .clk   (clk     ),
        .rst_n (rst_n   ),
        .en    (id_ex_en),
        .din   (jump_d  ),
        .dout  (jump_out)
    );
    riscv_BB_dfflr #(
        .DW      (1   ),
        .RST_VAL (1'b0)
    ) u_jalr_ff (
        .clk   (clk     ),
        .rst_n (rst_n   ),
        .en    (id_ex_en),
        .din   (jalr_d  ),
        .dout  (jalr_out)
    );
    riscv_BB_dfflr #(
        .DW      (1   ),
        .RST_VAL (1'b0)
    ) u_valid_ff (
        .clk   (clk      ),
        .rst_n (rst_n    ),
        .en    (id_ex_en ),
        .din   (valid_d  ),
        .dout  (valid_out)
    );
    riscv_BB_dfflr #(
        .DW      (7   ),
        .RST_VAL (7'h0)
    ) u_opcode_ff (
        .clk   (clk       ),
        .rst_n (rst_n     ),
        .en    (id_ex_en  ),
        .din   (opcode_in ),
        .dout  (opcode_out)
    );

endmodule