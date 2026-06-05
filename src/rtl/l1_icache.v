module l1_icache #(
// ===========================================================================
// CONFIGURABLE PARAMETERS
// ===========================================================================
    parameter C_SIZE    = 8192, // capacitance 8KB
    parameter B_SIZE    = 32,   // block 32B
    parameter ASSOC     = 2,    // associative ways, must be power of 2
    parameter BUS_BYTES = 64    // to L2 cache bus DW, notice that L2 has 64B blocks
)(
    input                    clk,
    input                    rst_n,
// ===========================================================================
// CPU INTERFACE
// ===========================================================================
    input                    cpu_req,
    input  [31:0]            cpu_addr,
    output [31:0]            cpu_rdata,
    output reg               cpu_stall,
    output reg               hit_event,   // for performance counter
    output reg               miss_event,  // for performance counter
// ===========================================================================
// L2 CACHE INTERFACE
// ===========================================================================
    output reg               mem_req,
    output                   mem_we,      // I-Cache equiv 0
    output [31:0]            mem_addr,
    output [BUS_BYTES*8-1:0] mem_wdata,   // I-Cache equiv 0
    output [BUS_BYTES-1:0]   mem_wstrb,   // I-Cache equiv 0
    input                    mem_ack,
    input  [BUS_BYTES*8-1:0] mem_rdata
);

// ===========================================================================
// FIXED PARAMETERS
// ===========================================================================
    // cache architecture
    localparam N_SETS     = C_SIZE / (B_SIZE * ASSOC);
    localparam OFF_W      = $clog2(B_SIZE);
    localparam IDX_W      = $clog2(N_SETS);
    localparam TAG_W      = 32 - IDX_W - OFF_W;
    localparam LRU_DEPTH  = (ASSOC == 1) ? 1 : $clog2(ASSOC);
    localparam L1_OFF_W   = $clog2(B_SIZE);
    localparam L2_OFF_W   = $clog2(BUS_BYTES);
    localparam META_W     = 1 + TAG_W;

    // fsm params
    localparam IDLE       = 2'b00;
    localparam COMPARE    = 2'b01;
    localparam MISS_FETCH = 2'b10;

// ===========================================================================
// INTERNAL SIGNALS
// ===========================================================================
    // input reg (block glitch)
    reg [31:0]                          reg_cpu_addr;
    
    // address degrading signals
    wire [OFF_W-1:0]                    cpu_off;
    wire [IDX_W-1:0]                    cpu_idx;
    wire [TAG_W-1:0]                    cpu_tag;
    wire [IDX_W-1:0]                    cpu_idx_ori;
    wire                                addr_changed;

    // cache array
    wire [TAG_W-1:0]                    way_tag_out   [0:ASSOC-1];
    wire                                way_valid_out [0:ASSOC-1];
    wire [B_SIZE*8-1:0]                 way_data_out  [0:ASSOC-1];
    wire [META_W-1:0]                   way_meta_out  [0:ASSOC-1];
    
    // PLRU logic
    reg                                 lru_array_refresh;
    reg  [LRU_DEPTH-1:0]                hit_way_idx;
    reg  [LRU_DEPTH-1:0]                rep_way;
    wire [LRU_DEPTH-1:0]                update_way;
    reg  [LRU_DEPTH-1:0]                target_way_reg;
    reg                                 is_replay;

    // hit & data path signals
    wire [ASSOC-1:0]                    hit_w;
    wire                                cache_hit;
    reg  [B_SIZE*8-1:0]                 hit_block;
    wire [B_SIZE*8-1:0]                 filled_block;
    reg                                 event_counted;

    // fsm signals
    reg  [1:0]                          state;
    reg  [1:0]                          nxt_state;

// ===========================================================================
// BRAM INSTANTIATION (Per Way)
// ===========================================================================
    genvar w;
    generate
        for (w = 0; w < ASSOC; w = w + 1) begin : GEN_CACHE_WAYS

            // -----------------------------------------------------------
            // 1. Write Enable arbiter (Port A)
            // -----------------------------------------------------------
            wire              we;
            wire [META_W-1:0] meta_din;
            wire              ren;
            
            assign ren      = (state == IDLE);
            // meta data WE judgement
            // update when filling in new blocks (Valid = 1, Dirty = 0/1, Tag = new tag)
            // update when hit
            assign we       = ((state == MISS_FETCH) && mem_ack && (target_way_reg == w));
            
            // meta data: {Valid, Tag}
            assign meta_din = ((state == MISS_FETCH) && mem_ack) ? 
                              {1'b1, cpu_tag} :           // new block fetched: valid, new tag
                              {1'b1, way_tag_out[w]};     // hit: valid, old tag

            // -----------------------------------------------------------
            // 2. DATA SDP RAM
            // -----------------------------------------------------------
            xpm_memory_sdpram #(
                .ADDR_WIDTH_A       (IDX_W           ),
                .ADDR_WIDTH_B       (IDX_W           ),
                .BYTE_WRITE_WIDTH_A (B_SIZE*8        ),
                .MEMORY_PRIMITIVE   ("block"         ),
                .MEMORY_SIZE        ((C_SIZE/ASSOC)*8), // total bit number of 1 way
                .READ_DATA_WIDTH_B  (B_SIZE*8        ), // read whole block
                .WRITE_DATA_WIDTH_A (B_SIZE*8        ), // write whole block
                .READ_LATENCY_B     (1               ), // read port with 1 cycle delay
                .WRITE_MODE_B       ("read_first"    ),
                .MEMORY_INIT_FILE   ("none"          ),
                .MEMORY_INIT_PARAM  ("0"             ),
                .USE_MEM_INIT       (1               )
            ) u_data_ram (
                // port A: write
                .clka   (clk            ),
                .ena    (1'b1           ),
                .wea    (we             ),
                .addra  (cpu_idx        ),
                .dina   (filled_block   ),
                
                // port B: read
                .clkb   (clk            ),
                .enb    (ren            ),
                .addrb  (cpu_idx_ori    ),
                .doutb  (way_data_out[w]),
                
                .rstb   (~rst_n         ),
                .sleep  (1'b0           ),
                .regceb (1'b1           )
                // skip unused ports
            );

            // -----------------------------------------------------------
            // 3. METADATA SDP RAM (word access)
            // -----------------------------------------------------------
            xpm_memory_sdpram #(
                .ADDR_WIDTH_A       (IDX_W        ),
                .ADDR_WIDTH_B       (IDX_W        ),
                .BYTE_WRITE_WIDTH_A (META_W       ),
                .MEMORY_PRIMITIVE   ("block"      ), // or distributed if resource is not enough
                .MEMORY_SIZE        (N_SETS*META_W), 
                .READ_DATA_WIDTH_B  (META_W       ),
                .WRITE_DATA_WIDTH_A (META_W       ),
                .READ_LATENCY_B     (1            ),
                .MEMORY_INIT_FILE   ("none"       ),
                .MEMORY_INIT_PARAM  ("0"          ),
                .USE_MEM_INIT       (1            )
            ) u_meta_ram (
                // port A: write
                .clka   (clk            ),
                .ena    (1'b1           ),
                .wea    (we             ),
                .addra  (cpu_idx        ),
                .dina   (meta_din       ),
                
                // port B: read
                .clkb   (clk            ),
                .enb    (ren            ),
                .addrb  (cpu_idx_ori    ),
                .doutb  (way_meta_out[w]),
                
                .rstb   (~rst_n         ),
                .sleep  (1'b0           ),
                .regceb (1'b1           )
            );

            // -----------------------------------------------------------
            // 4. meta data unpack
            // -----------------------------------------------------------
            assign way_valid_out[w] = way_meta_out[w][META_W-1];
            assign way_tag_out[w]   = way_meta_out[w][META_W-2:0];

        end
    endgenerate

// ===========================================================================
// ADDRESS DEGRADING LOGIC
// ===========================================================================
    assign cpu_off     = reg_cpu_addr[OFF_W-1:0];
    assign cpu_idx     = reg_cpu_addr[OFF_W+IDX_W-1 : OFF_W];
    assign cpu_tag     = reg_cpu_addr[31 : 32-TAG_W];
    assign cpu_idx_ori = cpu_addr[OFF_W+IDX_W-1 : OFF_W];

    assign addr_changed = (cpu_addr != reg_cpu_addr);

// ===========================================================================
// HIT LOGIC
// ===========================================================================
    genvar hit_idx;
    generate
        for (hit_idx = 0; hit_idx < ASSOC; hit_idx = hit_idx + 1) begin: hit_check
            assign hit_w[hit_idx] = ((^cpu_idx !== 1'bx) && 
                                     way_valid_out[hit_idx] && 
                                     (way_tag_out[hit_idx] == cpu_tag));
        end
    endgenerate

    assign cache_hit = |hit_w;
    
// ===========================================================================
// LRU REPLACE WAY LOGIC
// ===========================================================================
    // find out hit way
    integer hit_way_i;
    always @(*) begin
        hit_way_idx = {LRU_DEPTH{1'b0}};
        for (hit_way_i = 0; hit_way_i < ASSOC; hit_way_i = hit_way_i + 1) begin: hit_way_check
            if (hit_w[hit_way_i]) begin
                hit_way_idx = hit_way_i[LRU_DEPTH-1:0];
            end
        end
    end
    
    assign update_way = (state == MISS_FETCH) ? rep_way : hit_way_idx;

    generate
        if (ASSOC > 1) begin: GEN_PLRU
            localparam SAFE_LRU_W = (ASSOC > 1) ? (ASSOC - 1) : 1;
            reg  [SAFE_LRU_W-1:0] lru_array [0:N_SETS-1];
            reg  [SAFE_LRU_W-1:0] curr_tree;
            reg  [SAFE_LRU_W-1:0] nxt_tree;
            
            always @(*) begin
                curr_tree = lru_array[cpu_idx];
                rep_way   = {LRU_DEPTH{1'b0}};
                nxt_tree  = curr_tree;

                // find replace way from current LRU tree (0: left, 1: right)
                begin : find_rep
                    integer node;
                    integer d;
                    node = 0;
                    for (d = 0; d < LRU_DEPTH; d = d + 1) begin: find_rep_way
                        if (curr_tree[node] == 1'b0) begin
                            rep_way[LRU_DEPTH - 1 - d] = 1'b0;
                            node = node * 2 + 1;
                        end else begin
                            rep_way[LRU_DEPTH - 1 - d] = 1'b1;
                            node = node * 2 + 2;
                        end
                    end
                end

                // calculate new tree from update_way
                begin : update_tree
                    integer node; 
                    integer d;
                    node = 0;
                    for (d = 0; d < LRU_DEPTH; d = d + 1) begin: calc_new_tree
                        if (update_way[LRU_DEPTH - 1 - d] == 1'b0) begin
                            nxt_tree[node] = 1'b1;
                            node = node * 2 + 1;
                        end else begin
                            nxt_tree[node] = 1'b0;
                            node = node * 2 + 2;
                        end
                    end
                end
            end

            integer lru_arr_i;
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    for (lru_arr_i = 0; lru_arr_i < N_SETS; lru_arr_i = lru_arr_i + 1) begin
                        lru_array[lru_arr_i] <= {(ASSOC-1){1'b0}};
                    end
                end else if (lru_array_refresh) begin
                    lru_array[cpu_idx] <= nxt_tree;
                end
            end
        end
        else begin: GEN_DIRECT_MAPPED
            always @(*) begin
                rep_way = {LRU_DEPTH{1'b0}}; 
            end
        end
    endgenerate
    

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            is_replay <= 1'b0;
        end else if ((state == MISS_FETCH) && mem_ack) begin
            is_replay <= 1'b1;
        end else if ((state == COMPARE) && cache_hit) begin
            is_replay <= 1'b0;
        end
    end

// ===========================================================================
// DATA PATH LOGIC
// ===========================================================================
    integer hit_blk_i;
    always @(*) begin
        hit_block = {(B_SIZE*8){1'b0}};
        for (hit_blk_i = 0; hit_blk_i < ASSOC; hit_blk_i = hit_blk_i + 1) begin: data_update
            if (hit_w[hit_blk_i]) begin
                hit_block = hit_block | way_data_out[hit_blk_i];
            end
        end
    end
    
    generate
        if (BUS_BYTES == B_SIZE) begin: GEN_READ_SAME_SIZE
            assign filled_block = mem_rdata;
        end
        else begin: GEN_READ_DIFF_SIZE
            wire [$clog2(BUS_BYTES/B_SIZE)-1:0] read_sub_idx;
            assign read_sub_idx = reg_cpu_addr[$clog2(BUS_BYTES)-1 : $clog2(B_SIZE)];
            assign filled_block = mem_rdata[read_sub_idx * (B_SIZE*8) +: (B_SIZE*8)];
        end
    endgenerate
    // according to offset, slice 32b instruction from 256b block
    // word offset = offset >> 2
    assign cpu_rdata = (((state == MISS_FETCH) && mem_ack) ? filled_block[ cpu_off[OFF_W-1:2] * 32 +: 32 ]
                                                           : hit_block[ cpu_off[OFF_W-1:2] * 32 +: 32 ]);

    assign mem_addr  = {cpu_addr[31:OFF_W], {OFF_W{1'b0}}}; // block aligned address

// ===========================================================================
// UNUSED SIGNALS
// ===========================================================================
    assign mem_we    = 1'b0;
    assign mem_wdata = {(BUS_BYTES*8){1'b0}};
    assign mem_wstrb = {BUS_BYTES{1'b0}};

// ===========================================================================
// FSM
// ===========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end
        else begin
            state <= nxt_state;
        end
    end

    always @(*) begin
        nxt_state         = state;
        cpu_stall         = 1'b0;
        mem_req           = 1'b0;
        lru_array_refresh = 1'b0;

        case (state)
            IDLE: begin
                if (cpu_req) begin
                    cpu_stall = 1'b1;
                    nxt_state = COMPARE;
                end
            end
            COMPARE: begin
                if (addr_changed) begin
                    cpu_stall = 1'b1;
                    nxt_state = IDLE;
                end
                else if (cache_hit) begin
                    cpu_stall         = 1'b0;
                    lru_array_refresh = 1'b1;
                    nxt_state         = COMPARE;
                end 
                else begin
                    cpu_stall  = 1'b1;
                    nxt_state  = MISS_FETCH;
                end
            end
            MISS_FETCH: begin
                cpu_stall = 1'b1;
                mem_req   = 1'b1;
                if (mem_ack) begin
                    lru_array_refresh = 1'b1;
                    nxt_state         = IDLE;
                end
            end
            default: begin
                nxt_state = IDLE;
            end
        endcase
    end

// ===========================================================================
// INPUT REG UPDATE LOGIC
// ===========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            target_way_reg <= 1'b0;
            reg_cpu_addr   <= 32'h0;
        end else begin
            if ((state == IDLE) && cpu_req) begin
                reg_cpu_addr  <= cpu_addr;
            end
            if ((state == COMPARE) && cpu_req) begin
                if (cache_hit) begin
                    target_way_reg <= hit_way_idx;
                end
                else begin
                    if (!is_replay) begin
                        target_way_reg <= (ASSOC > 1) ? rep_way : 0;
                    end
                end
            end
        end
    end

// ===========================================================================
// EVENT GENERATION (Delta-Cycle Safe)
// ===========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hit_event     <= 1'b0;
            miss_event    <= 1'b0;
            event_counted <= 1'b0;
        end else begin
            hit_event  <= 1'b0;
            miss_event <= 1'b0;
            
            if ((state == IDLE) || ((state == COMPARE) && addr_changed)) begin
                event_counted <= 1'b0;
            end
            else if ((state == COMPARE) && !event_counted) begin
                if (cache_hit) begin
                    if (!is_replay) begin
                        hit_event <= 1'b1;
                    end
                end else begin
                    miss_event <= 1'b1;
                end
                event_counted <= 1'b1;
            end
        end
    end
endmodule