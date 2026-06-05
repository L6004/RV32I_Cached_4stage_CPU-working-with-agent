class cpu_base_test extends uvm_test;
    `uvm_component_utils(cpu_base_test)

    cpu_env cpu_ev;

    function new(string name = "cpu_base_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        cpu_ev = cpu_env::type_id::create("cpu_ev", this);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        #1000000000;
        `uvm_error("BASE_TEST", "Simulation timeout, please check your test sequence.")
        phase.drop_objection(this);
    endtask

    `ifndef POST_IMPL
    function void report_phase(uvm_phase phase);
        uvm_report_server svr;
        int uvm_err_cnt;
        int sva_err_cnt;
        int total_err;
        virtual sva_interface sva_if;

        super.report_phase(phase);
        
        // 1. 获取 UVM 框架内所有的 ERROR 和 FATAL 数量
        svr = uvm_report_server::get_server();
        uvm_err_cnt = svr.get_severity_count(UVM_ERROR) + svr.get_severity_count(UVM_FATAL);

        // 2. 从 config_db 中获取 sva_interface 里的 SVA 错误数量
        if (uvm_config_db#(virtual sva_interface)::get(this, "", "sva_if", sva_if)) begin
            sva_err_cnt = sva_if.sva_err_cnt;
        end else begin
            sva_err_cnt = 0;
        end

        // 3. 计算总计
        total_err = uvm_err_cnt + sva_err_cnt;

        // 4. 打印霸气的 ASCII 字符图
        $display("\n=======================================================");
        if (total_err == 0) begin
            $display("    ____   _    ____  ____  ");
            $display("   |  _ \\ / \\  / ___|/ ___| ");
            $display("   | |_) / _ \\ \\___ \\\\___ \\ ");
            $display("   |  __/ ___ \\ ___) |___) |");
            $display("   |_| /_/   \\_\\____/|____/ ");
            $display("                            ");
            $display("   [SUCCESS] All Tests Passed! (0 Errors)");
        end else begin
            $display("    _____ _    ___ _     ");
            $display("   |  ___/ \\  |_ _| |    ");
            $display("   | |_ / _ \\  | || |    ");
            $display("   |  _/ ___ \\ | || |___ ");
            $display("   |_|/_/   \\_\\___|_____|");
            $display("                         ");
            $display("   [FAILED] Found %0d Errors (%0d UVM, %0d SVA)", total_err, uvm_err_cnt, sva_err_cnt);
        end
        $display("=======================================================\n");
    endfunction
    `endif
endclass