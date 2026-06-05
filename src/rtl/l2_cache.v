module l2_cache #(
// ===========================================================================
// CONFIGURABLE PARAMETERS
// ===========================================================================
    parameter C_SIZE      = 65536,  // 64KB[cite: 1]
    parameter B_SIZE      = 64,     // 64B[cite: 1]
    parameter ASSOC       = 4,      // 4 ways[cite: 1]
    parameter L1_BUS_SIZE = 64,     // 64 Byte cache bus
    parameter BUS_SIZE    = 64      // 64 Byte memory bus
)(
    input                          clk,
    input                          rst_n,
// ===========================================================================
// L1 CACHE INTERFACE
// ===========================================================================
    input                          cpu_req,
    input                          cpu_we,
    input      [31:0]              cpu_addr,
    input      [L1_BUS_SIZE*8-1:0] cpu_wdata, 
    input      [L1_BUS_SIZE-1:0]   cpu_wstrb,
    output reg [L1_BUS_SIZE*8-1:0] cpu_rdata,
    output reg                     cpu_stall,
    output reg                     hit_event,
    output reg                     miss_event,
    output reg                     cpu_ack,
// ===========================================================================
// DRAM INTERFACE
// ===========================================================================
    output reg                     mem_req,
    output reg                     mem_we,
    output reg [31:0]              mem_addr,
    output reg [BUS_SIZE*8-1:0]    mem_wdata,
    output reg [BUS_SIZE-1:0]      mem_wstrb,
    input                          mem_ack,
    input      [BUS_SIZE*8-1:0]    mem_rdata
);

// ===========================================================================
// FIXED PARAMETERS
// ===========================================================================
    // cache architecture
    localparam N_SETS     = C_SIZE / (B_SIZE * ASSOC); // 256
    localparam OFF_W      = $clog2(B_SIZE);            // 6 bits
    localparam IDX_W      = $clog2(N_SETS);            // 8 bits
    localparam TAG_W      = 32 - IDX_W - OFF_W;        // 18 bits
    localparam LRU_DEPTH  = $clog2(ASSOC);
    localparam L2_OFF_W   = $clog2(B_SIZE);
    localparam MEM_OFF_W  = $clog2(BUS_SIZE);
    localparam META_W     = 2 + TAG_W;

    // fsm params
    localparam IDLE          = 3'b000;
    localparam COMPARE       = 3'b001;
    localparam WRITE_BACK    = 3'b010;
    localparam WAIT_ACK_DROP = 3'b011;
    localparam ALLOCATE      = 3'b100;

// ===========================================================================
// INTERNAL SIGNALS
// ===========================================================================
    // input reg (block glitch)
    reg [L1_BUS_SIZE*8-1:0]       reg_cpu_wdata;
    reg [31:0]                    reg_cpu_addr;
    reg [L1_BUS_SIZE-1:0]         reg_cpu_wstrb;
    reg                           reg_cpu_we;
    
    // address degrading signals
    wire [OFF_W-1:0]              cpu_off;
    wire [IDX_W-1:0]              cpu_idx;
    wire [TAG_W-1:0]              cpu_tag;
    wire [MEM_OFF_W-L2_OFF_W-1:0] sub_idx;
    wire [IDX_W-1:0]              cpu_idx_ori;

    // cache array
    wire                          way_dirty_out [0:ASSOC-1];
    wire [B_SIZE*8-1:0]           way_data_out  [0:ASSOC-1];
    wire [META_W-1:0]             way_meta_out  [0:ASSOC-1];
    wire [TAG_W-1:0]              way_tag_out   [0:ASSOC-1];
    wire                          way_valid_out [0:ASSOC-1];
    
    // PLRU
    reg  [ASSOC-2:0]              lru_array [0:N_SETS-1];
    reg                           lru_array_refresh;
    reg  [LRU_DEPTH-1:0]          rep_way;
    reg  [ASSOC-2:0]              curr_tree;
    reg  [ASSOC-2:0]              nxt_tree;
    wire [LRU_DEPTH-1:0]          update_way;
    reg  [LRU_DEPTH-1:0]          target_way_reg;
    reg                           is_replay;

    // Hit Logic & data path
    wire [ASSOC-1:0]              hit_w;
    wire                          cache_hit;
    reg  [B_SIZE*8-1:0]           hit_block;
    reg  [LRU_DEPTH-1:0]          hit_way_idx;
    wire [B_SIZE*8-1:0]           filled_block;
    reg                           event_counted;
    wire                          req_changed;

    // fsm params and logics
    reg  [2:0]                    state;
    reg  [2:0]                    nxt_state;
    wire                          replace_dirty;

// ===========================================================================
// BRAM INSTANTIATION (Per Way)
// ===========================================================================
    genvar w;
    generate
        for (w = 0; w < ASSOC; w = w + 1) begin : GEN_CACHE_WAYS

            // -----------------------------------------------------------
            // 1. Write Enable arbiter (Port A)
            // -----------------------------------------------------------
            wire                meta_we;
            wire [META_W-1:0]   meta_din;
            wire [B_SIZE-1:0]   data_we;
            wire [B_SIZE*8-1:0] data_din;
            wire                ren;

            assign ren     = (state == IDLE);
            // data WE judgement (ALLOCATE new block, COMPARE hit and update)
            // if Miss, write whole block; if Hit, write with strb
            assign data_we = ((state == ALLOCATE) && mem_ack && (target_way_reg == w)) ? {B_SIZE{1'b1}} :
                             ((state == COMPARE) && cpu_req && cache_hit && reg_cpu_we && (hit_way_idx == w)) ? reg_cpu_wstrb : 
                             {B_SIZE{1'b0}};
            
            // data mux
            assign data_din = ((state == ALLOCATE) && mem_ack) ? filled_block : reg_cpu_wdata;

            // meta data WE judgement
            // update when filling in new blocks (Valid = 1, Dirty = 0/1, Tag = new tag)
            // update when hit
            assign meta_we = ((state == ALLOCATE) && mem_ack && (target_way_reg == w)) ||
                             ((state == COMPARE) && cpu_req && cache_hit && reg_cpu_we && (hit_way_idx == w));
            
            // meta data: {Dirty, Valid, Tag}
            assign meta_din = ((state == ALLOCATE) && mem_ack) ? 
                              {1'b0, 1'b1, cpu_tag} :           // new block fetched: not dirty, valid, new tag
                              {1'b1, 1'b1, way_tag_out[w]};     // hit: dirty, valid, old tag

            // -----------------------------------------------------------
            // 2. DATA SDP RAM (byte access enabled)
            // -----------------------------------------------------------
            xpm_memory_sdpram #(
                .ADDR_WIDTH_A       (IDX_W           ),
                .ADDR_WIDTH_B       (IDX_W           ),
                .BYTE_WRITE_WIDTH_A (8               ), // 8bit Byte strb
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
                .wea    (data_we        ),
                .addra  (cpu_idx        ),
                .dina   (data_din       ),
                
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
                .wea    (meta_we        ),
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
            assign way_dirty_out[w] = way_meta_out[w][META_W-1];
            assign way_valid_out[w] = way_meta_out[w][META_W-2];
            assign way_tag_out[w]   = way_meta_out[w][META_W-3:0];

        end
    endgenerate

// ===========================================================================
// ADDRESS DEGRADING LOGIC
// ===========================================================================
    assign cpu_off     = reg_cpu_addr[OFF_W-1:0];
    assign cpu_idx     = reg_cpu_addr[OFF_W+IDX_W-1 : OFF_W];
    assign cpu_tag     = reg_cpu_addr[31 : 32-TAG_W];
    assign cpu_idx_ori = cpu_addr[OFF_W+IDX_W-1 : OFF_W];

    generate
        if (BUS_SIZE == B_SIZE) begin : GEN_SAME_SIZE
            assign sub_idx = 0;
        end else begin : GEN_DIFF_SIZE
            assign sub_idx = reg_cpu_addr[MEM_OFF_W-1 : L2_OFF_W];
        end
    endgenerate

// ===========================================================================
// HIT LOGIC
// ===========================================================================
    genvar hit_idx;
    generate
        for (hit_idx = 0; hit_idx < ASSOC; hit_idx = hit_idx + 1) begin : hit_check
            assign hit_w[hit_idx] = (way_valid_out[hit_idx] && 
                                     (way_tag_out[hit_idx] == cpu_tag));
        end
    endgenerate

    assign cache_hit = |hit_w;

// ===========================================================================
// LRU REPLACE WAY LOGIC
// ===========================================================================
    integer hit_way_i;
    always @(*) begin
        hit_way_idx = {LRU_DEPTH{1'b0}};
        for (hit_way_i = 0; hit_way_i < ASSOC; hit_way_i = hit_way_i + 1) begin
            if (hit_w[hit_way_i]) begin
                hit_way_idx = hit_way_i[LRU_DEPTH-1:0];
            end
        end
    end
    
    assign update_way = (state == ALLOCATE) ? rep_way : hit_way_idx;

    always @(*) begin
        curr_tree = lru_array[cpu_idx];
        rep_way   = {LRU_DEPTH{1'b0}}; 
        nxt_tree  = curr_tree;
        begin : find_rep
            integer node; 
            integer d;
            node = 0;
            for (d = 0; d < LRU_DEPTH; d = d + 1) begin
                if (curr_tree[node] == 1'b0) begin
                    rep_way[LRU_DEPTH - 1 - d] = 1'b0; 
                    node = node * 2 + 1;
                end else begin
                    rep_way[LRU_DEPTH - 1 - d] = 1'b1; 
                    node = node * 2 + 2;
                end
            end
        end
        begin : update_tree
            integer node; 
            integer d;
            node = 0;
            for (d = 0; d < LRU_DEPTH; d = d + 1) begin
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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            is_replay <= 1'b0;
        end else if ((state == ALLOCATE) && mem_ack) begin
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
        for (hit_blk_i = 0; hit_blk_i < ASSOC; hit_blk_i = hit_blk_i + 1) begin
            if (hit_w[hit_blk_i]) begin
                hit_block = (hit_block | way_data_out[hit_blk_i]);
            end
        end
    end

    assign filled_block = mem_rdata[sub_idx * (B_SIZE*8) +: (B_SIZE*8)];
    assign cpu_rdata = (((state == ALLOCATE) && mem_ack) ? filled_block : hit_block);

// ===========================================================================
// FSM
// ===========================================================================
    assign replace_dirty = way_valid_out[rep_way] & 
                           way_dirty_out[rep_way];

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
        mem_we            = 1'b0; 
        mem_addr          = 32'h80000000; 
        mem_wdata         = {(BUS_SIZE*8){1'b0}}; 
        mem_wstrb         = {BUS_SIZE{1'b0}}; 
        lru_array_refresh = 1'b0;
        cpu_ack           = 1'b0;

        case (state)
            IDLE: begin
                if (cpu_req) begin
                    cpu_stall = 1'b1;
                    nxt_state = COMPARE;
                end
            end
            COMPARE: begin
                if (cache_hit) begin
                    cpu_stall         = 1'b0;
                    lru_array_refresh = 1'b1; 
                    cpu_ack           = 1'b1;
                    nxt_state         = IDLE;
                end else begin
                    cpu_stall  = 1'b1;
                    if (replace_dirty) begin
                        nxt_state = WRITE_BACK;
                    end
                    else begin
                        nxt_state = ALLOCATE;
                    end
                end
            end
            WRITE_BACK: begin
                cpu_stall = 1'b1;
                mem_req   = 1'b1;
                mem_we    = 1'b1;
                mem_wstrb = {BUS_SIZE{1'b1}};
                mem_addr  = {way_tag_out[rep_way], cpu_idx, {OFF_W{1'b0}}};
                mem_wdata[sub_idx * (B_SIZE*8) +: (B_SIZE*8)] = way_data_out[rep_way];
                if (mem_ack) begin
                    nxt_state = WAIT_ACK_DROP;
                end
            end
            WAIT_ACK_DROP: begin
                cpu_stall = 1'b1;
                mem_req   = 1'b0;      // pull down mem_req, let DRAM FSM exit RESPOND
                nxt_state = ALLOCATE;  // goto ALLOCATE the next cycle and mem_req
            end
            ALLOCATE: begin
                cpu_stall = 1'b1;
                mem_req   = 1'b1;
                mem_we    = 1'b0;
                mem_addr  = {reg_cpu_addr[31:OFF_W], {OFF_W{1'b0}}};
                if (mem_ack) begin
                    cpu_stall         = 1'b0;
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
// CACHE ARRAY UPDATE LOGIC
// ===========================================================================
    integer lru_arr_i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (lru_arr_i=0; lru_arr_i<N_SETS; lru_arr_i=lru_arr_i+1) begin
                lru_array[lru_arr_i] <= {(ASSOC-1){1'b0}};
            end
            reg_cpu_wdata  <= {(L1_BUS_SIZE*8){1'b0}};
            reg_cpu_addr   <= 32'h0;
            reg_cpu_wstrb  <= {L1_BUS_SIZE{1'b0}};
            reg_cpu_we     <= 1'b0;
            target_way_reg <= 0;
        end else begin
            if (lru_array_refresh) begin
                lru_array[cpu_idx] <= nxt_tree;
            end
            if ((state == IDLE) && cpu_req) begin
                reg_cpu_wdata <= cpu_wdata;
                reg_cpu_addr  <= cpu_addr;
                reg_cpu_wstrb <= cpu_wstrb;
                reg_cpu_we    <= cpu_we;
            end
            if ((state == COMPARE) && cpu_req) begin
                if (cache_hit) begin
                    target_way_reg <= hit_way_idx;
                end
                else begin
                    if (!is_replay) begin
                        target_way_reg <= rep_way;
                    end
                end
            end
        end
    end

// ===========================================================================
// EVENT GENERATION (Delta-Cycle Safe)
// ===========================================================================
    assign req_changed = ((cpu_addr != reg_cpu_addr) || (cpu_we != reg_cpu_we));
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hit_event     <= 1'b0;
            miss_event    <= 1'b0;
            event_counted <= 1'b0;
        end else begin
            hit_event  <= 1'b0;
            miss_event <= 1'b0;
            
            if ((state == IDLE) || ((state == COMPARE) && req_changed)) begin
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