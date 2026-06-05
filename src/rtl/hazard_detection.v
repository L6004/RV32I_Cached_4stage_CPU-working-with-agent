module hazard_detection (
    input        id_ex_mem_read,
    input [4:0]  id_ex_rd,
    input [4:0]  if_id_rs1,
    input [4:0]  if_id_rs2,
    input        ex_branch_taken,
    input        icache_stall,
    input        dcache_stall,
    output       pc_stall,
    output       if_id_stall,
    output       id_ex_stall,
    output       ex_mem_stall,
    output       if_id_flush,
    output       id_ex_flush
);
    // 1. Load-Use 
    wire load_use = id_ex_mem_read && (|id_ex_rd) && 
                    ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2));
    
    // 2. Jump flush only when D-Cache is not stalled and under B-type conditions
    wire jump_flush = ex_branch_taken && !dcache_stall;

    // =========================================================
    // Stall Logic
    // =========================================================
    // if jump, jump_flush=1, IF and ID instructions all wrong,
    // pc needs to go to a new addr, do not stall PC and IF/ID.
    `ifndef ENABLE_CACHE
        assign pc_stall     = (dcache_stall || load_use || icache_stall) && !jump_flush;
        assign if_id_stall  = (dcache_stall || load_use)                 && !jump_flush;
    `else
        assign pc_stall     = dcache_stall || ((load_use || icache_stall) && !ex_branch_taken);
        assign if_id_stall  = dcache_stall || ((load_use || icache_stall) && !ex_branch_taken);
    `endif
    
    `ifndef ENABLE_CACHE
        assign id_ex_stall  = dcache_stall;
        assign ex_mem_stall = dcache_stall;
    `else
        assign id_ex_stall  = (dcache_stall || icache_stall);
        assign ex_mem_stall = (dcache_stall || icache_stall);
    `endif

    // =========================================================
    // Flush Logic
    // =========================================================
    // if_id_flush:
    // 1. jump flush
    // 2. I-Cache Miss 
    // (IF not valid, must flush to avoid wrong instruction copy)
    `ifdef ENABLE_CACHE
        assign if_id_flush = jump_flush;
    `else
        assign if_id_flush = jump_flush || (icache_stall && !if_id_stall);
    `endif

    // id_ex_flush:
    // 1. jump flush
    // 2. Load-Use (ID stall, EX flushed)
    `ifdef ENABLE_CACHE
        assign id_ex_flush = jump_flush || (load_use && !dcache_stall && !icache_stall);
    `else
        assign id_ex_flush = jump_flush || (load_use && !id_ex_stall);
    `endif

endmodule