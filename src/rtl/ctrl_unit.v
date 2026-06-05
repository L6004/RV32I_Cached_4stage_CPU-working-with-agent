module ctrl_unit (
    input      [6:0]  opcode,
    input      [2:0]  funct3,
    input      [6:0]  funct7,
    output reg        alu_src_a, // 0: rs1, 1: PC
    output reg        alu_src_b, // 0: rs2, 1: imm
    output reg [3:0]  alu_op,
    output reg        mem_read,
    output reg        mem_write,
    output reg        mem_size,  // 0: Word, 1: Byte (LB/SB)
    output reg        reg_write,
    output reg [1:0]  wb_src,    // 00: ALU, 01: MEM, 10: PC+4
    output reg        branch,
    output reg        jump,
    output reg        jalr
);
    always @(*) begin
        // default value
        alu_src_a = 1'b0; 
        alu_src_b = 1'b0; 
        alu_op    = 4'b0000;
        mem_read  = 1'b0; 
        mem_write = 1'b0; 
        mem_size  = 1'b0;
        reg_write = 1'b0; 
        wb_src    = 2'b00; 
        branch    = 1'b0; 
        jump      = 1'b0; 
        jalr      = 1'b0;
        
        case (opcode)
            7'b0110011: begin // R-type
                reg_write = 1'b1;
                case ({funct7[5], funct3})
                    4'b0000: alu_op = 4'b0000; // ADD
                    4'b1000: alu_op = 4'b1100; // SUB
                    4'b0001: alu_op = 4'b1000; // SLL
                    4'b0010: alu_op = 4'b0010; // SLT
                    4'b0011: alu_op = 4'b0011; // SLTU
                    4'b0100: alu_op = 4'b0100; // XOR
                    4'b0101: alu_op = 4'b0001; // SRL
                    4'b1101: alu_op = 4'b1001; // SRA
                    4'b0110: alu_op = 4'b0110; // OR
                    4'b0111: alu_op = 4'b0111; // AND
                    default: alu_op = 4'b0000;
                endcase
            end
            7'b0010011: begin // I-type
                alu_src_b = 1'b1; reg_write = 1'b1;
                case (funct3)
                    3'b000: alu_op  = 4'b0000;                       // ADDI
                    3'b001: alu_op  = 4'b1000;                       // SLLI
                    3'b010: alu_op  = 4'b0010;                       // SLTI
                    3'b011: alu_op  = 4'b0011;                       // SLTIU
                    3'b100: alu_op  = 4'b0100;                       // XORI
                    3'b101: alu_op  = funct7[5] ? 4'b1001 : 4'b0001; // SRLI/SRAI
                    3'b110: alu_op  = 4'b0110;                       // ORI
                    3'b111: alu_op  = 4'b0111;                       // ANDI
                    default: alu_op = 4'b0000;
                endcase
            end
            7'b0000011: begin // Load (LW, LB)
                alu_src_b = 1'b1; 
                mem_read  = 1'b1; 
                reg_write = 1'b1; 
                wb_src    = 2'b01;
                mem_size  = (funct3 == 3'b000) ? 1'b1 : 1'b0; // LB vs LW
            end
            7'b0100011: begin // Store (SW, SB)
                alu_src_b = 1'b1; 
                mem_write = 1'b1;
                mem_size  = (funct3 == 3'b000) ? 1'b1 : 1'b0;
            end
            7'b1100011: begin // Branch
                // alu_src_a = 1'b1;    // 0:rs1, 1:PC 
                // alu_src_b = 1'b1;    // 0:rs2, 1:IMM
                // alu_op    = 4'b0000; // ADD (PC + IMM)
                branch    = 1'b1;
            end
            7'b1101111: begin // JAL
                // alu_src_a = 1'b1;    // 1:PC
                // alu_src_b = 1'b1;    // 1:IMM
                // alu_op    = 4'b0000; // ADD (PC + IMM)
                jump      = 1'b1; 
                reg_write = 1'b1; 
                wb_src    = 2'b10;   // writeback PC + 4
            end
            7'b1100111: begin // JALR
                // alu_src_a = 1'b0;    // 0:rs1
                // alu_src_b = 1'b1;    // 1:IMM
                // alu_op    = 4'b0000; // ADD (rs1 + IMM)
                jump      = 1'b1; 
                jalr      = 1'b1;
                reg_write = 1'b1; 
                wb_src    = 2'b10;   // writeback PC + 4
            end
            7'b0110111: begin // LUI
                alu_src_b = 1'b1; 
                reg_write = 1'b1;    // alu_src_a = 0 (rs1 is x0)
                alu_op    = 4'b0000; // 0 + imm
            end
            7'b0010111: begin // AUIPC
                alu_src_a = 1'b1; 
                alu_src_b = 1'b1; 
                reg_write = 1'b1;
                alu_op    = 4'b0000; // PC + imm
            end
        endcase
    end
endmodule