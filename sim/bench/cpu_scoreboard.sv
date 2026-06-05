class cpu_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(cpu_scoreboard)

    uvm_analysis_imp#(cpu_transaction, cpu_scoreboard) scb_imp;

    // 存储 Golden Model 结果的队列
    typedef struct packed {
        bit [31:0] pc;
        bit [31:0] addr;
        bit [31:0] data;
    } golden_record_unit;
    golden_record_unit golden_record_queue[$];

    function new(string name, uvm_component parent);
        super.new(name, parent);
        scb_imp = new("scb_imp", this);
    endfunction

    function void build_phase(uvm_phase phase);
        int fd;
        string trace_file;
        bit [31:0] pc_val;
        bit [31:0] addr_val;
        bit [31:0] data_val;

        super.build_phase(phase);
        
        // 从命令行 +GOLDEN_LOG=xxx.txt 获取参考日志路径
        if (!$value$plusargs("GOLDEN_LOG=%s", trace_file))
            trace_file = "golden_trace.txt";

        fd = $fopen(trace_file, "r");
        if (fd) begin
            while (!$feof(fd)) begin
                // 假设格式为: 00000008 01 00000026
                if ($fscanf(fd, "%x %x %x\n", pc_val, addr_val, data_val) == 3) begin
                    golden_record_unit read_exp;
                    read_exp.pc = pc_val;
                    read_exp.addr = addr_val;
                    read_exp.data = data_val;
                    golden_record_queue.push_back(read_exp);
                end
            end
            $fclose(fd);
            `uvm_info("SCB", $sformatf("Loaded %0d golden transactions", golden_record_queue.size()), UVM_LOW)
        end else begin
            `uvm_fatal("SCB", {"Cannot open golden log: ", trace_file})
        end
    endfunction

    // Monitor 每次传来 transaction，触发一次检查
    function void write(cpu_transaction tr);
        // =========================================================
        // 1. 核心比对：只比对写入了通用寄存器(x1-x31)的指令
        // =========================================================
        if (tr.reg_we && tr.rd != 0) begin
            golden_record_unit exp;

            `ifndef POST_IMPL
            if (golden_record_queue.size() == 0) begin
                `uvm_warning("SCB_EXTRA", $sformatf("DUV produced extra reg write! PC:%x x%0d=%x", tr.pc, tr.rd, tr.reg_wdata))
                return; 
            end
            `endif
            
            exp = golden_record_queue.pop_front();
            
            `ifndef POST_IMPL
            // 严格检查：PC、目标寄存器地址、写回的数据 必须 100% 匹配
            if (tr.pc != exp.pc || tr.rd != exp.addr || tr.reg_wdata != exp.data) begin
                `uvm_error("SCB_REG_FAIL", $sformatf(
                    "Mismatch! \n \
                    [DUV]   PC:%h, OPCODE:%h, FUNCT3:%h -> Writes x%0d = %0d (Hex: %h)\n \
                    [SPIKE] PC:%h -> Writes x%0d = %0d (Hex: %h)", 
                    tr.pc, tr.opcode, tr.funct3, tr.rd, $signed(tr.reg_wdata), tr.reg_wdata,
                    exp.pc, exp.addr, $signed(exp.data), exp.data))
            end else begin
                `uvm_info("SCB_PASS", $sformatf("[MATCH] PC:%x -> x%0d = %x", tr.pc, tr.rd, tr.reg_wdata), UVM_HIGH)
            end
            `endif
        end

        // =========================================================
        // 2. 内存写入监控 (不查 Spike Log，只供覆盖率/调试参考)
        // =========================================================
        // if (tr.mem_we) begin
        //     `uvm_info("SCB_MEM_TRACE", $sformatf("[MEM WRITE] PC:%x wrote %x to Addr:%x", tr.pc, tr.mem_wdata, tr.mem_addr), UVM_LOW)
        // end
    endfunction
    
    // =========================================================
    // 3. 终局检查：仿真结束时，Golden Queue 必须被刚好清空
    // =========================================================
    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        `ifndef POST_IMPL
        if (golden_record_queue.size() > 0) begin
            `uvm_error("SCB_LEAK", $sformatf("DUV missed %0d instructions! First missed PC: %x", golden_record_queue.size(), golden_record_queue[0].pc))
        end else begin
            `uvm_info("SCB_SUCCESS", "All Golden Transactions matched perfectly!", UVM_NONE)
        end
        `endif
    endfunction
endclass