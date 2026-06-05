class cpu_agent extends uvm_agent;
    `uvm_component_utils(cpu_agent)

    cpu_monitor cpu_mnt;

    function new(string name = "cpu_agent", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        cpu_mnt = cpu_monitor::type_id::create("cpu_mnt", this);
    endfunction
endclass