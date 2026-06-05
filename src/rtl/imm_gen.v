module imm_gen (
    input  [31:0] instr,
    output [31:0] imm
    // output reg [31:0] imm
);

    wire [4:0]  opcode;
    wire [4:0]  op_type;
    wire [31:0] s_type_imm;     // 01000
    wire [31:0] b_type_imm;     // 11000
    wire [31:0] j_type_imm;     // 11011
    wire [31:0] u_type_imm;     // 01101 00101
    wire [31:0] i_type_imm;     // 00100 00000 11001
    
    assign opcode = instr[6:2];

    assign op_type = {(opcode == 5'b01000), (opcode == 5'b11000), (opcode == 5'b11011), 
                     ((opcode == 5'b01101) || (opcode == 5'b00101)), 
                     ((opcode == 5'b00100) || (opcode == 5'b00000) || (opcode == 5'b11001))};

    assign s_type_imm  = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    assign b_type_imm  = {s_type_imm[31:12], s_type_imm[0], 
                          s_type_imm[10:1], 1'b0};
    assign j_type_imm  = {{11{instr[31]}}, instr[31], instr[19:12], 
                          instr[20], instr[30:21], 1'b0};
    assign u_type_imm  = {instr[31:12], 12'h0};
    assign i_type_imm  = {{20{u_type_imm[31]}}, u_type_imm[31:20]};

    assign imm         = op_type[4] ? s_type_imm 
                                    : op_type[3] ? b_type_imm
                                                 : op_type[2] ? j_type_imm
                                                              : op_type[1] ? u_type_imm
                                                                           : op_type[0] ? i_type_imm
                                                                                        : 32'h0;

endmodule