class cpu_coverage extends uvm_subscriber #(cpu_transaction);
    `uvm_component_utils(cpu_coverage)

    cpu_transaction tr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_instr  = new();
        cg_branch = new();
        cg_hazard = new();
    endfunction

    covergroup cg_instr;
        // 拼接成 11-bit: {opcode[6:0], funct3[2:0], funct7[5]}
        cp_isa: coverpoint {tr.cov_instr[6:0], tr.cov_instr[14:12], tr.cov_instr[30]} {
            
            // R-Type
            bins ADD  = {11'b0110011_000_0};
            bins SUB  = {11'b0110011_000_1};
            bins SLL  = {11'b0110011_001_0};
            bins SLT  = {11'b0110011_010_0};
            bins SLTU = {11'b0110011_011_0};
            bins XOR  = {11'b0110011_100_0};
            bins SRL  = {11'b0110011_101_0};
            bins SRA  = {11'b0110011_101_1};
            bins OR   = {11'b0110011_110_0};
            bins AND  = {11'b0110011_111_0};

            // I-Type 移位
            bins SLLI = {11'b0010011_001_0};
            bins SRLI = {11'b0010011_101_0};
            bins SRAI = {11'b0010011_101_1};

            // I-Type 算术逻辑 (忽略 funct7)
            wildcard bins ADDI  = {11'b0010011_000_?};
            wildcard bins SLTI  = {11'b0010011_010_?};
            wildcard bins SLTIU = {11'b0010011_011_?};
            wildcard bins XORI  = {11'b0010011_100_?};
            wildcard bins ORI   = {11'b0010011_110_?};
            wildcard bins ANDI  = {11'b0010011_111_?};

            // B-Type 分支 (忽略 funct7)
            wildcard bins BEQ  = {11'b1100011_000_?};
            wildcard bins BNE  = {11'b1100011_001_?};
            wildcard bins BLT  = {11'b1100011_100_?};
            wildcard bins BGE  = {11'b1100011_101_?};
            wildcard bins BLTU = {11'b1100011_110_?};
            wildcard bins BGEU = {11'b1100011_111_?};

            // Load / Store 
            wildcard bins LB  = {11'b0000011_000_?};
            wildcard bins LW  = {11'b0000011_010_?};

            wildcard bins SB  = {11'b0100011_000_?};
            wildcard bins SW  = {11'b0100011_010_?};

            // U-Type / J-Type
            wildcard bins JAL   = {11'b1101111_???_?};
            wildcard bins JALR  = {11'b1100111_000_?};
            wildcard bins LUI   = {11'b0110111_???_?};
            wildcard bins AUIPC = {11'b0010111_???_?};
        }
    endgroup

    covergroup cg_branch;
        cp_branch_taken: coverpoint tr.branch_taken {
            bins taken     = {1'b1};
            bins not_taken = {1'b0};
        }
        cp_branch_instr: coverpoint tr.funct3 {
            bins beq  = {3'b000};
            bins bne  = {3'b001};
            bins blt  = {3'b100};
            bins bge  = {3'b101};
            bins bltu = {3'b110};
            bins bgeu = {3'b111};
        }

        cross cp_branch_taken, cp_branch_instr;
    endgroup

    covergroup cg_hazard;
        cp_stall: coverpoint tr.hazard_stall {
            bins is_triggered  = {1'b1};
            bins not_triggered = {1'b0};
        }
        cp_flush: coverpoint tr.hazard_flush {
            bins is_triggered  = {1'b1};
            bins not_triggered = {1'b0};
        }
    endgroup

    function void write(cpu_transaction t);
        this.tr = t;
        cg_instr.sample();
        cg_branch.sample();
        cg_hazard.sample();
    endfunction
endclass