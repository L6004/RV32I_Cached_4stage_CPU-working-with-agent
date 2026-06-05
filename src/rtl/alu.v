module alu (
    input      [31:0] a,
    input      [31:0] b,
    input      [3:0]  op,
    output reg [31:0] result,
    output            zero,
    output            carry,
    output            negative,
    output            overflow
);

    wire [32:0] sum;
    wire        sub;

    assign sub      = op[3];
    assign sum      = {1'b0, a} + {1'b0, sub ? ~b : b} + sub;
    assign zero     = (result == 32'h0);
    assign carry    = sum[32];
    assign negative = result[31];
    assign overflow = (a[31] == b[31]) && (result[31] != a[31]);

    always @(*) begin
        case (op)
            4'b0000: result = sum[31:0];                                 // ADD/ADDI
            4'b1000: result = a << b[4:0];                               // SLL/SLLI
            4'b0010: result = ($signed(a) < $signed(b)) ? 32'h1 : 32'h0; // SLT/SLTI
            4'b0011: result = (a < b) ? 32'h1 : 32'h0;                   // SLTU/SLTIU
            4'b0100: result = a ^ b;                                     // XOR/XORI
            4'b1001: result = ($signed(a) >>> b[4:0]);                   // SRA/SRAI
            4'b0001: result = (a >> b[4:0]);                             // SRL/SRLI
            4'b0110: result = a | b;                                     // OR/ORI
            4'b0111: result = a & b;                                     // AND/ANDI
            4'b1100: result = sum[31:0];                                 // SUB/BEQ/BNE (result=0 means equal)
            default: result = 32'h0;
        endcase
    end

endmodule