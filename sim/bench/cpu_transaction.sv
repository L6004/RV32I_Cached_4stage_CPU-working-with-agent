class cpu_transaction extends uvm_sequence_item;
// ===========================================================================
// TRANSACTION COMPONENTS
// ===========================================================================
    bit [31:0] pc;
    // reg write
    bit        reg_we;
    bit [4:0]  rd;
    bit [31:0] reg_wdata;
    // mem write
    bit        mem_we;
    bit [31:0] mem_addr;
    bit [31:0] mem_wdata;
    // instruction
    bit [6:0]  opcode;
    bit [2:0]  funct3;
    bit        funct7_5;
    bit [31:0] instr;
    bit [31:0] cov_instr;
    // branch
    bit        branch_taken;
    
    // hazard
    bit        hazard_stall;
    bit        hazard_flush;

// ===========================================================================
// REGISTRY
// ===========================================================================
    `uvm_object_utils_begin(cpu_transaction)
        `uvm_field_int (pc,           UVM_ALL_ON | UVM_HEX)
        `uvm_field_int (reg_we,       UVM_ALL_ON          )
        `uvm_field_int (rd,           UVM_ALL_ON          )
        `uvm_field_int (reg_wdata,    UVM_ALL_ON | UVM_HEX)
        `uvm_field_int (mem_we,       UVM_ALL_ON          )
        `uvm_field_int (mem_addr,     UVM_ALL_ON | UVM_HEX)
        `uvm_field_int (mem_wdata,    UVM_ALL_ON | UVM_HEX)
        `uvm_field_int (opcode,       UVM_ALL_ON          )
        `uvm_field_int (branch_taken, UVM_ALL_ON          )
        `uvm_field_int (funct3,       UVM_ALL_ON          )
        `uvm_field_int (funct7_5,     UVM_ALL_ON          )
        `uvm_field_int (instr,        UVM_ALL_ON          )
        `uvm_field_int (cov_instr,    UVM_ALL_ON          )
        `uvm_field_int (hazard_stall, UVM_ALL_ON          )
        `uvm_field_int (hazard_flush, UVM_ALL_ON          )
    `uvm_object_utils_end

// ===========================================================================
// NEW
// ===========================================================================
    function new(string name = "cpu_transaction");
        super.new(name);
    endfunction
endclass