module dram_behav #(
// ===========================================================================
// CONFIGURABLE PARAMETERS
// ===========================================================================
    parameter DELAY_CYCLES = 2,
    parameter BUS_BYTES    = 64,
    parameter RAM_SIZE     = 1048576 // 4MB
)(
    input                          clk,
    input                          rst_n,
    input                          req,
    input                          we,
    input       [31:0]             addr,
    input       [BUS_BYTES*8-1:0]  wdata,
    input       [BUS_BYTES-1:0]    wstrb,
    output reg                     ack,
    output reg  [BUS_BYTES*8-1:0]  rdata
);

// ===========================================================================
// FIXED PARAMETERS
// ===========================================================================
    localparam WORDS_PER_BLOCK = BUS_BYTES / 4;
    localparam IDLE    = 2'b00;
    localparam WAIT    = 2'b01;
    localparam RESPOND = 2'b10;

// ===========================================================================
// INTERNAL SIGNALS
// ===========================================================================
    reg  [31:0] memory [0:RAM_SIZE-1];
    wire [31:0] phys_addr;              // map base addr to 0 idx
    wire [31:0] base_word_idx;
    reg  [1:0]  current_state;
    reg  [1:0]  next_state;
    reg  [31:0] delay_cnt;

// ===========================================================================
// ADDRESS PROCESS
// ===========================================================================
    assign phys_addr     = (addr - 32'h80000000);
    assign base_word_idx = {phys_addr[31:$clog2(BUS_BYTES)], {$clog2(BUS_BYTES)-2{1'b0}}};

// ===========================================================================
// FSM
// ===========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    always @(*) begin
        next_state = current_state; 
        ack        = 1'b0;                 
        case (current_state)
            IDLE: begin
                if (req) begin
                    next_state = WAIT;
                end
            end
            WAIT: begin
                if (delay_cnt == DELAY_CYCLES) begin
                    next_state = RESPOND;
                end
            end
            RESPOND: begin
                ack = 1'b1;
                if (!req) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

// ===========================================================================
// DELAY COUNTER CONTROL
// ===========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            delay_cnt <= 32'h0;
        end else begin
            if ((current_state == IDLE) && req) begin
                delay_cnt <= 32'h0;
            end 
            else if ((current_state == WAIT) && (delay_cnt < DELAY_CYCLES)) begin
                delay_cnt <= delay_cnt + 1;
            end
        end
    end

// ===========================================================================
// MEMORY R/W
// ===========================================================================
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata <= {(BUS_BYTES*8){1'b0}};
        end else begin
            if ((current_state == WAIT) && (delay_cnt == DELAY_CYCLES)) begin
                if (we) begin
                    for (i = 0; i < BUS_BYTES; i = i + 1) begin
                        if (wstrb[i]) begin
                            memory[base_word_idx + (i >> 2)][(i[1:0]*8) +: 8] <= wdata[i*8 +: 8];
                        end
                    end
                end else begin
                    for (i = 0; i < WORDS_PER_BLOCK; i = i + 1) begin
                        rdata[i*32 +: 32] <= memory[base_word_idx + i];
                    end
                end
            end
        end
    end

endmodule