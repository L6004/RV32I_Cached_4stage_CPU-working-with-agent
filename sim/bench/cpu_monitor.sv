class cpu_monitor extends uvm_monitor;
    `uvm_component_utils(cpu_monitor)

    virtual cpu_interface vif;
    `ifndef POST_IMPL
    virtual sva_interface sva_if;
    `endif
    uvm_analysis_port #(cpu_transaction) ap;
    cpu_transaction tr;

    function new(string name = "cpu_monitor", uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual cpu_interface)::get(this, "", "vif", vif))
            `uvm_fatal("MON", "Cannot get virtual cpu_interface from config_db!")
        `ifndef POST_IMPL
        if (!uvm_config_db#(virtual sva_interface)::get(this, "", "sva_if", sva_if))
            `uvm_fatal("MON", "Cannot get virtual sva_interface from config_db!")
        `endif
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            @(posedge vif.clk);
            `ifndef POST_IMPL
            if (vif.rst_n && sva_if.commit_valid && !sva_if.hazard_ex_mem_stall) begin
                tr = new("tr");
                // if (sva_if.commit_reg_we || sva_if.commit_mem_we || sva_if.is_branch_instr) begin
                tr.pc           = sva_if.commit_pc;
                tr.reg_we       = sva_if.commit_reg_we;
                tr.rd           = sva_if.commit_rd;
                tr.reg_wdata    = sva_if.commit_reg_wdata;
                tr.mem_we       = sva_if.commit_mem_we;
                tr.mem_addr     = sva_if.commit_mem_addr;
                tr.mem_wdata    = sva_if.commit_mem_wdata;
                tr.opcode       = sva_if.opcode;
                tr.branch_taken = sva_if.branch_taken;
                tr.funct3       = sva_if.funct3;
                tr.funct7_5     = sva_if.funct7_5;
                tr.instr        = sva_if.commit_instr;
                tr.cov_instr    = sva_if.if_id_instr;
                tr.hazard_stall = (sva_if.hazard_pc_stall || 
                                    sva_if.hazard_if_id_stall ||
                                    sva_if.hazard_id_ex_stall ||
                                    sva_if.hazard_ex_mem_stall);
                tr.hazard_flush = (sva_if.hazard_if_id_flush ||
                                    sva_if.hazard_id_ex_flush);
                ap.write(tr);
                // tr.print();
                // end
            end
            `else
            tr = new("tr");
            ap.write(tr);
            `endif
        end
endtask
endclass