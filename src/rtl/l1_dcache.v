module l1_dcache #(
// ===========================================================================
// CONFIGURABLE PARAMETERS
// ===========================================================================
    parameter C_SIZE     = 8192,     // capacitance 8KB[cite: 1]
    parameter B_SIZE     = 32,       // block 32B[cite: 1]
    parameter ASSOC      = 2,        // associative ways, must be power of 2
    parameter BUS_BYTES  = 64,       // to L2 cache bus DW, notice that L2 has 64B blocks
    parameter FIFO_DEPTH = 4
)(
    input                        clk,
    input                        rst_n,
// ===========================================================================
// CPU INTERFACE
// ===========================================================================
    input                        cpu_req,
    input                        cpu_we,
    input      [31:0]            cpu_addr,
    input      [31:0]            cpu_wdata,
    input                        cpu_size,    // 0: word, 1: byte
    output     [31:0]            cpu_rdata,
    output reg                   cpu_stall,
    output reg                   hit_event,
    output reg                   miss_event,
// ===========================================================================
// L2 CACHE INTERFACE
// ===========================================================================
    output reg                   mem_req,
    output reg                   mem_we,
    output reg [31:0]            mem_addr,
    output reg [BUS_BYTES*8-1:0] mem_wdata,
    output reg [BUS_BYTES-1:0]   mem_wstrb,
    input                        mem_ack,
    input      [BUS_BYTES*8-1:0] mem_rdata
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
    // localparam IDLE       = 3'b000;
    // localparam COMPARE    = 3'b001;
    // localparam MISS_FETCH = 3'b010;
    // localparam HIT_WRITE  = 3'b011;
    // localparam POP_BUF    = 3'b100;

    // Foreground FSM: Handles CPU requests and cache refills
    localparam F_IDLE       = 2'b00;
    localparam F_COMPARE    = 2'b01;
    localparam F_MISS_FETCH = 2'b10;

    // Background FSM: Handles Write Buffer draining to L2 Cache
    localparam B_IDLE       = 2'b00;
    localparam B_WRITE      = 2'b01;
    localparam B_POP        = 2'b10;

// ===========================================================================
// INTERNAL SIGNALS
// ===========================================================================
    // input reg (block glitch)
    reg [31:0]                                                reg_cpu_wdata;
    reg [31:0]                                                reg_cpu_addr;
    reg                                                       reg_cpu_size;
    reg                                                       reg_cpu_we;
    
    // address degrading signals
    wire [OFF_W-1:0]                                          cpu_off;
    wire [IDX_W-1:0]                                          cpu_idx;
    wire [TAG_W-1:0]                                          cpu_tag;
    wire [IDX_W-1:0]                                          cpu_idx_ori;
    wire [((BUS_BYTES > B_SIZE) ? L2_OFF_W-L1_OFF_W-1 : 0):0] buf_sub_idx;
    wire                                                      req_changed;

    // cache array
    wire [TAG_W-1:0]                                          way_tag_out   [0:ASSOC-1];
    wire                                                      way_valid_out [0:ASSOC-1];
    wire [B_SIZE*8-1:0]                                       way_data_out  [0:ASSOC-1];
    wire [META_W-1:0]                                         way_meta_out  [0:ASSOC-1];
    
    // PLRU logic
    reg  [LRU_DEPTH-1:0]                                      hit_way_idx;
    reg  [LRU_DEPTH-1:0]                                      rep_way;
    wire [LRU_DEPTH-1:0]                                      update_way;
    reg  [LRU_DEPTH-1:0]                                      target_way_reg;
    reg                                                       is_replay;

    // hit & data path signals
    wire [ASSOC-1:0]                                          hit_w;
    wire                                                      cache_hit;
    reg  [B_SIZE*8-1:0]                                       hit_block;
    wire [B_SIZE*8-1:0]                                       broadcast_wdata;
    wire [B_SIZE*8-1:0]                                       filled_block;
    wire [31:0]                                               cpu_wdata_aligned;
    wire [31:0]                                               word_read;
    reg  [7:0]                                                byte_read;
    reg  [31:0]                                               rdata_comb;
    reg                                                       event_counted;

    // write buffer
    reg                                                       buf_wen;
    reg                                                       buf_ren;
    wire                                                      addr_buf_empty;
    wire                                                      addr_buf_full;
    wire                                                      strb_buf_empty;
    wire                                                      strb_buf_full;
    wire                                                      data_buf_empty;
    wire                                                      data_buf_full;
    wire                                                      buf_empty;
    wire                                                      buf_full;
    wire [31:0]                                               buf_mem_addr;
    wire [B_SIZE*8-1:0]                                       buf_mem_wdata;
    wire [B_SIZE-1:0]                                         buf_mem_wstrb;
    wire [BUS_BYTES*8-1:0]                                    buf_mem_wdata_padded;
    wire [BUS_BYTES-1:0]                                      buf_mem_wstrb_padded;

    // byte access mask
    reg  [B_SIZE-1:0]                                         block_wstrb;

    // fsm signals
    // reg  [2:0]                                                state;
    // reg  [2:0]                                                nxt_state;
    reg  [1:0]                                                f_state;
    reg  [1:0]                                                f_nxt_state;
    reg  [1:0]                                                b_state;
    reg  [1:0]                                                b_nxt_state;

    // Internal FSM control signals for L2 multiplexing
    reg                                                       f_mem_req;
    reg                                                       b_mem_req;
    reg                                                       f_lru_refresh;

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

            assign ren     = (f_state == F_IDLE);
            // data WE judgement (MISS_FETCH new block, COMPARE hit and update)
            // if Miss, write whole block; if Hit, write with strb
            assign data_we = ((f_state == F_MISS_FETCH) && mem_ack && (target_way_reg == w)) ? {B_SIZE{1'b1}} :
                             ((f_state == F_COMPARE) && cpu_req && cache_hit && reg_cpu_we && !buf_full && (hit_way_idx == w)) ? block_wstrb : 
                             {B_SIZE{1'b0}};
            
            // data mux
            assign data_din = ((f_state == F_MISS_FETCH) && mem_ack) ? filled_block : broadcast_wdata;

            // meta data WE judgement
            // update when filling in new blocks (Valid = 1, Dirty = 0/1, Tag = new tag)
            // update when hit
            assign meta_we = ((f_state == F_MISS_FETCH) && mem_ack && (target_way_reg == w)) ||
                             ((f_state == F_COMPARE) && cpu_req && cache_hit && reg_cpu_we && !buf_full && (hit_way_idx == w));
            
            // meta data: {Valid, Tag}
            assign meta_din = ((f_state == F_MISS_FETCH) && mem_ack) ? 
                              {1'b1, cpu_tag} :           // new block fetched: valid, new tag
                              {1'b1, way_tag_out[w]};     // hit: valid, old tag

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
                .addrb  (cpu_idx_ori    ), // use the unregistered cpu_idx
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

    generate
        if (BUS_BYTES == B_SIZE) begin : GEN_BUF_SAME_SIZE
            assign buf_sub_idx = 0;
        end else begin : GEN_BUF_DIFF_SIZE
            assign buf_sub_idx = buf_mem_addr[L2_OFF_W-1 : L1_OFF_W];
        end
    endgenerate

    assign req_changed = ((cpu_addr != reg_cpu_addr) || 
                          (cpu_we   != reg_cpu_we)   || 
                          (cpu_size != reg_cpu_size) ||
                          (cpu_req  && (cpu_wdata != reg_cpu_wdata)));
    
// ===========================================================================
// HIT LOGIC
// ===========================================================================
    genvar hit_idx;
    generate
        for (hit_idx = 0; hit_idx < ASSOC; hit_idx = hit_idx + 1) begin: hit_logic
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
    
    assign update_way = (f_state == F_MISS_FETCH) ? rep_way : hit_way_idx;

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
                end else if (f_lru_refresh) begin
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
        end else if ((f_state == F_MISS_FETCH) && mem_ack) begin
            is_replay <= 1'b1;
        end else if ((f_state == F_COMPARE) && cache_hit) begin
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

    // rdata alignment
    assign word_read = hit_block[ cpu_off[OFF_W-1:2] * 32 +: 32 ];
    always @(*) begin
        byte_read = 8'h0;
        if (reg_cpu_size) begin // Byte read (lb)
            case (cpu_off[1:0])
                2'b00: byte_read = word_read[7:0];
                2'b01: byte_read = word_read[15:8];
                2'b10: byte_read = word_read[23:16];
                2'b11: byte_read = word_read[31:24];
            endcase
            // Sign Extension
            rdata_comb = {{24{byte_read[7]}}, byte_read};
        end else begin      // Word read (lw)
            rdata_comb = word_read;
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
    assign cpu_rdata = (((f_state == F_MISS_FETCH) && mem_ack) ? filled_block[ cpu_off[OFF_W-1:2] * 32 +: 32 ] 
                                                           : rdata_comb);

    // broadcast data generation
    genvar b_idx;
    generate
        for (b_idx = 0; b_idx < B_SIZE; b_idx = b_idx + 1) begin : broadcast
            assign broadcast_wdata[b_idx*8 +: 8] = cpu_wdata_aligned[(b_idx%4)*8 +: 8];
        end
    endgenerate
    
    // write mask generation  
    always @(*) begin
        block_wstrb = {B_SIZE{1'b0}};
        case (reg_cpu_size)
            1'b0: block_wstrb[{cpu_off[OFF_W-1:2], 2'b00} +: 4] = 4'b1111;      // Word
            1'b1: block_wstrb[cpu_off] = 1'b1;                                  // Byte
            default: block_wstrb[{cpu_off[OFF_W-1:2], 2'b00} +: 4] = 4'b1111;
        endcase
    end

    assign cpu_wdata_aligned = reg_cpu_size ? {4{reg_cpu_wdata[7:0]}} : reg_cpu_wdata;

    assign buf_mem_wdata_padded = buf_mem_wdata;
    assign buf_mem_wstrb_padded = buf_mem_wstrb;

// ===========================================================================
// DECOUPLED FSM: FOREGROUND PART & BACKGROUND PART
// ===========================================================================
    // foreground FSM: pipeline interface
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            f_state <= F_IDLE;
        end
        else begin
            f_state <= f_nxt_state;
        end
    end

    always @(*) begin
        f_nxt_state   = f_state;
        cpu_stall     = 1'b0;
        buf_wen       = 1'b0;
        f_mem_req     = 1'b0;
        f_lru_refresh = 1'b0;

        case (f_state)
            F_IDLE: begin
                if (cpu_req) begin
                    cpu_stall   = 1'b1;
                    f_nxt_state = F_COMPARE;
                end
            end
            F_COMPARE: begin
                if (cpu_req && req_changed) begin
                    cpu_stall   = 1'b1;
                    f_nxt_state = F_IDLE;
                end
                else if (cache_hit) begin
                    if (reg_cpu_we) begin
                        if (!buf_full) begin
                            buf_wen       = 1'b1;
                            f_lru_refresh = 1'b1;
                            cpu_stall     = 1'b0; // FIFO isn't full, let pipeline go on
                            f_nxt_state   = F_IDLE;
                        end
                        else begin
                            cpu_stall     = 1'b1; // FIFO full, stall for FIFO pop until empty
                            f_nxt_state   = F_COMPARE;
                        end
                    end
                    else begin // Read Hit
                        cpu_stall         = 1'b0;
                        f_lru_refresh     = 1'b1;
                        f_nxt_state       = F_IDLE;
                    end
                end 
                else begin // R/W Miss
                    cpu_stall = 1'b1;
                    // Coherence control: pop FIFO to empty before refill
                    if (!buf_empty || mem_ack) begin
                        f_nxt_state = F_COMPARE; 
                    end else begin
                        f_nxt_state = F_MISS_FETCH;
                    end
                end
            end
            F_MISS_FETCH: begin
                cpu_stall = 1'b1;
                f_mem_req = 1'b1; // block request towards L2
                if (mem_ack) begin
                    f_lru_refresh = 1'b1;
                    f_nxt_state   = F_IDLE;
                end
            end
            default: f_nxt_state = F_IDLE;
        endcase
    end

    // background FSM: L2 interface, mainly managing FIFO
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            b_state <= B_IDLE;
        end
        else begin
            b_state <= b_nxt_state;
        end
    end

    always @(*) begin
        b_nxt_state = b_state;
        buf_ren     = 1'b0;
        b_mem_req   = 1'b0;

        case (b_state)
            B_IDLE: begin
                if (!buf_empty && !mem_ack) begin
                    b_nxt_state = B_WRITE;
                end
            end
            B_WRITE: begin
                b_mem_req = 1'b1; // L2 write request
                if (mem_ack) begin
                    b_nxt_state = B_POP;
                end
            end
            B_POP: begin
                buf_ren     = 1'b1;   // pop 1 block of FIFO, refresh empty at the next posedge
                b_nxt_state = B_IDLE; // back to IDLE, if still not empty, automatically continue
            end
            default: b_nxt_state = B_IDLE;
        endcase
    end

    // L2 BUS request MUX for FSMs
    always @(*) begin
        if (f_state == F_MISS_FETCH) begin
            // foreground refill
            mem_req   = f_mem_req;
            mem_we    = 1'b0;
            mem_addr  = {reg_cpu_addr[31:OFF_W], {OFF_W{1'b0}}};
            mem_wdata = {(BUS_BYTES*8){1'b0}};
            mem_wstrb = {BUS_BYTES{1'b0}};
        end else begin
            // default or write by background
            mem_req   = b_mem_req;
            mem_we    = (b_state == B_WRITE);
            mem_addr  = buf_mem_addr;
            mem_wdata = (buf_mem_wdata_padded << (buf_sub_idx * B_SIZE * 8));
            mem_wstrb = (buf_mem_wstrb_padded << (buf_sub_idx * B_SIZE));
        end
    end

// ===========================================================================
// WRITE BUFFER INSTANCE
// ===========================================================================
    riscv_BB_sync_fifo #(
        .WIDTH 	(32        ),
        .DEPTH 	(FIFO_DEPTH))
    u_mem_addr_fifo(
        .clk    (clk           ),
        .rst_n  (rst_n         ),
        .wen   	(buf_wen       ),
        .wdata 	(reg_cpu_addr  ),
        .ren   	(buf_ren       ),
        .rdata 	(buf_mem_addr  ),
        .full  	(addr_buf_full ),
        .empty 	(addr_buf_empty)
    ); 
    riscv_BB_sync_fifo #(
        .WIDTH 	(B_SIZE    ),
        .DEPTH 	(FIFO_DEPTH))
    u_mem_strb_fifo(
        .clk    (clk           ),
        .rst_n  (rst_n         ),
        .wen   	(buf_wen       ),
        .wdata 	(block_wstrb   ),
        .ren   	(buf_ren       ),
        .rdata 	(buf_mem_wstrb ),
        .full  	(strb_buf_full ),
        .empty 	(strb_buf_empty)
    );  
    riscv_BB_sync_fifo #(
        .WIDTH 	(B_SIZE*8  ),
        .DEPTH 	(FIFO_DEPTH))
    u_mem_data_fifo(
        .clk    (clk            ),
        .rst_n  (rst_n          ),
        .wen   	(buf_wen        ),
        .wdata 	(broadcast_wdata),
        .ren   	(buf_ren        ),
        .rdata 	(buf_mem_wdata  ),
        .full  	(data_buf_full  ),
        .empty 	(data_buf_empty )
    ); 

    assign buf_empty = (addr_buf_empty | strb_buf_empty | data_buf_empty);
    assign buf_full  = (addr_buf_full  | strb_buf_full  | data_buf_full);

// ===========================================================================
// INPUT REG UPDATE LOGIC
// ===========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_cpu_wdata  <= 32'h0;
            reg_cpu_addr   <= 32'h0;
            reg_cpu_size   <= 1'b0;
            reg_cpu_we     <= 1'b0;
            target_way_reg <= 0;
        end else begin
            // save cpu data for cache write
            if ((f_state == F_IDLE) && cpu_req) begin
                reg_cpu_wdata <= cpu_wdata;
                reg_cpu_addr  <= cpu_addr;
                reg_cpu_size  <= cpu_size;
                reg_cpu_we    <= cpu_we;
            end
            // save target way & write buffer
            if ((f_state == F_COMPARE) && cpu_req) begin
                if (cache_hit) begin
                    target_way_reg <= hit_way_idx;
                end
                else begin
                    if (buf_empty && !is_replay) begin
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
            
            if ((f_state == F_IDLE) || ((f_state == F_COMPARE) && req_changed)) begin
                event_counted <= 1'b0;
            end
            else if ((f_state == F_COMPARE) && !event_counted) begin
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