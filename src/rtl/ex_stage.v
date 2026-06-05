module ex_stage (
    input  [31:0] pc,
    input  [31:0] rs1_data,
    input  [31:0] rs2_data,
    input  [31:0] imm,
    input         alu_src_a,
    input         alu_src_b,
    input  [3:0]  alu_op,
    input  [1:0]  fwd_rs1,
    input  [1:0]  fwd_rs2,
    input  [31:0] mem_wb_result,
    input         branch,
    input         jump,
    input         jalr,
    input  [2:0]  funct3,
    
    output [31:0] alu_result,
    output [31:0] mem_write_data,
    output        ex_branch_taken,
    output [31:0] ex_branch_target
);
    wire [31:0] forward_a;
    wire [31:0] forward_b;
    wire [31:0] alu_in1;
    wire [31:0] alu_in2;
    wire        is_eq;
    wire        is_lt;
    wire        is_ltu;
    reg         branch_cond;

    // unused signals
    wire        zero;
    wire        carry;
    wire        negative;
    wire        overflow;
    wire        unused;

    assign forward_a      = (fwd_rs1 == 2'b01) ? mem_wb_result : rs1_data;
    assign forward_b      = (fwd_rs2 == 2'b01) ? mem_wb_result : rs2_data;
    assign alu_in1        = alu_src_a ? pc : forward_a;
    assign alu_in2        = alu_src_b ? imm : forward_b;
    assign mem_write_data = forward_b;
    assign unused         = |{zero, carry, negative, overflow};

    alu u_alu(
        .a        	(alu_in1   ),
        .b        	(alu_in2   ),
        .op       	(alu_op    ),
        .result   	(alu_result),
        .zero     	(zero      ),
        .carry    	(carry     ),
        .negative 	(negative  ),
        .overflow 	(overflow  )
    );
    
    // branch condition decoder
    assign is_eq  = (forward_a == forward_b);
    assign is_lt  = ($signed(forward_a) < $signed(forward_b));
    assign is_ltu = (forward_a < forward_b);
    always @(*) begin
        case (funct3)
            3'b000: branch_cond = is_eq;   // BEQ
            3'b001: branch_cond = !is_eq;  // BNE
            3'b100: branch_cond = is_lt;   // BLT
            3'b101: branch_cond = !is_lt;  // BGE
            3'b110: branch_cond = is_ltu;  // BLTU
            3'b111: branch_cond = !is_ltu; // BGEU
            default: branch_cond = 1'b0;
        endcase
    end

    assign ex_branch_taken = jump || (branch && branch_cond);
    assign ex_branch_target = jalr ? ((forward_a + imm) & ~32'h1) : (pc + imm);
    // assign ex_branch_target = jalr ? (alu_result & 32'hFFFFFFFE) : alu_result;
endmodule