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
// STUBBORN FUNCTION
// ===========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ack   <= 1'b0;
            rdata <= {(BUS_BYTES*8){1'b0}};
        end else begin
            // avoid bus dead lock
            ack   <= req; 
            // return glue data, avoid being optimized in logical synthesis
            rdata <= {{(BUS_BYTES*8-32){1'b0}}, addr}; 
        end
    end

endmodule