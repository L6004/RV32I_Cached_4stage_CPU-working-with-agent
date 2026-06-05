class cpu_env extends uvm_env;
    `uvm_component_utils(cpu_env)

    cpu_agent      cpu_agt;
    cpu_scoreboard cpu_scb;
    cpu_coverage   cpu_cov;

    function new(string name = "cpu_env", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        cpu_agt = cpu_agent::type_id::create("cpu_agt", this);
        cpu_scb = cpu_scoreboard::type_id::create("cpu_scb", this);
        cpu_cov = cpu_coverage::type_id::create("cpu_cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        cpu_agt.cpu_mnt.ap.connect(cpu_scb.scb_imp);
        cpu_agt.cpu_mnt.ap.connect(cpu_cov.analysis_export);
    endfunction
endclass