import uvm_pkg::*;
`include "uvm_macros.svh"

interface sva_interface;
    logic        clk;
    logic        rst_n;

    // monitor reg and mem write
    logic        commit_reg_we;
    logic        commit_mem_we;
    logic [4:0]  commit_rd;
    logic [31:0] commit_reg_wdata;
    logic [31:0] commit_mem_wdata;
    logic [31:0] commit_mem_addr;

    // monitor pipeline commits
    logic [31:0] commit_pc;
    logic        commit_valid;
    logic [31:0] commit_instr;
    
    // monitor hazard control
    logic        hazard_pc_stall;
    logic        hazard_if_id_stall;
    logic        hazard_id_ex_stall;
    logic        hazard_ex_mem_stall;
    logic        hazard_if_id_flush;
    logic        hazard_id_ex_flush;
    logic [31:0] if_id_pc;
    logic [31:0] id_ex_pc;
    logic [31:0] memwb_pc;
    logic        id_ex_valid;
    
    // monitor branches
    logic        branch_taken;
    logic        is_branch_instr;

    // monitor opcode & instructioons
    logic [6:0]  opcode;
    logic [2:0]  funct3;
    logic        funct7_5;
    logic [31:0] pc_reg;
    logic [31:0] ex_pc;
    logic [31:0] if_id_instr;

    // error counter
    int sva_err_cnt = 0;

// ===========================================================================
// SVA
// ===========================================================================
    // flush assertion instances
    ass_flush_if_id_instr: assert property(
        @(posedge clk) disable iff (!rst_n || (if_id_instr == 32'h0000006f))
        (hazard_if_id_flush && !hazard_if_id_stall) |=> (if_id_instr == 32'h00000013)
    ) else begin
        $error("[SVA_FLUSH_ERR] IF_ID Instr not flushed to NOP.");
        sva_err_cnt++;
    end

    ass_flush_if_id_pc: assert property(
        @(posedge clk) disable iff (!rst_n || (if_id_instr == 32'h0000006f))
        (hazard_if_id_flush && !hazard_if_id_stall) |=> (if_id_pc == 32'h0)
    ) else begin
        $error("[SVA_FLUSH_ERR] IF_ID pc not flushed to 0.");        
        sva_err_cnt++;        
    end

    ass_flush_id_ex_valid: assert property(
        @(posedge clk) disable iff (!rst_n || (if_id_instr == 32'h0000006f))
        (hazard_id_ex_flush && !hazard_id_ex_stall) |=> (id_ex_valid == 1'b0)
    ) else begin
        $error("[SVA_FLUSH_ERR] ID_EX valid not flushed to 0.");        
        sva_err_cnt++;        
    end

    // ass_flush_id_ex_pc: assert property(
    //     @(posedge clk) disable iff (!rst_n || (if_id_instr == 32'h0000006f))
    //     hazard_id_ex_flush |=> (id_ex_pc == 32'h0)
    // ) else begin
    //     $error("[SVA_FLUSH_ERR] ID_EX pc not flushed to 0.");        
    //     sva_err_cnt++;        
    // end

    // stall assertion instances
    ass_stall_pc: assert property(
        @(posedge clk) disable iff (!rst_n || (if_id_instr == 32'h0000006f))
        hazard_pc_stall |=> (pc_reg == $past(pc_reg))
    ) else begin
        $error("[SVA_STALL_ERR] PC did not stall.");
        sva_err_cnt++;
    end
                          
    ass_stall_if_id_pc: assert property(
        @(posedge clk) disable iff (!rst_n || (if_id_instr == 32'h0000006f))
        hazard_if_id_stall |=> (if_id_pc == $past(if_id_pc))
    ) else begin
        $error("[SVA_STALL_ERR] IF_ID_PC did not stall.");
        sva_err_cnt++;
    end
                          
    ass_stall_if_id_inst: assert property(
        @(posedge clk) disable iff (!rst_n || (if_id_instr == 32'h0000006f))
        hazard_if_id_stall |=> (if_id_instr == $past(if_id_instr))
    ) else begin
        $error("[SVA_STALL_ERR] IF_ID_INSTR did not stall.");
        sva_err_cnt++;
    end

    ass_stall_id_ex_pc: assert property(
        @(posedge clk) disable iff (!rst_n || (if_id_instr == 32'h0000006f))
        hazard_id_ex_stall |=> (id_ex_pc == $past(id_ex_pc))
    ) else begin
        $error("[SVA_STALL_ERR] ID_EX_PC did not stall.");
        sva_err_cnt++;
    end

    ass_stall_memwb_pc: assert property(
        @(posedge clk) disable iff (!rst_n || (if_id_instr == 32'h0000006f))
        hazard_ex_mem_stall |=> (memwb_pc == $past(memwb_pc))
    ) else begin
        $error("[SVA_STALL_ERR] MEMWB_PC did not stall.");
        sva_err_cnt++;
    end

endinterface
