module cache_system_top #(
// ===========================================================================
// CONFIGURABLE PARAMETERS
// ===========================================================================
    parameter L1_I_SIZE         = 8192,
    parameter L1_D_SIZE         = 8192,
    parameter L1_B_SIZE         = 32,
    parameter L2_SIZE           = 65536,
    parameter L2_B_SIZE         = 64,
    parameter L1_ASSOC          = 2,
    parameter L2_ASSOC          = 4,
    parameter L1_L2_BUS_BYTES   = 64,
    parameter L2_DRAM_BUS_BYTES = 64,
    parameter FIFO_DEPTH        = 4
)(
    input                            clk,
    input                            rst_n,
// ===========================================================================
// CPU-L1_iCACHE INTERFACE
// ===========================================================================
    input                            cpu_i_req,
    input  [31:0]                    cpu_i_addr,
    output [31:0]                    cpu_i_rdata,
    output                           i_stall,
// ===========================================================================
// CPU-L1_dCACHE INTERFACE
// ===========================================================================
    input                            cpu_d_req,
    input                            cpu_d_we,
    input  [31:0]                    cpu_d_addr,
    input  [31:0]                    cpu_d_wdata,
    input                            cpu_d_size,
    output [31:0]                    cpu_d_rdata,
    output                           d_stall,
// ===========================================================================
// PERFORMANCE COUNTERs INTERFACE
// ===========================================================================
    output                           l1i_hit, 
    output                           l1i_miss,
    output                           l1d_hit, 
    output                           l1d_miss,
    output                           l2_hit_event,
    output                           l2_miss_event,
// ===========================================================================
// DRAM INTERFACE
// ===========================================================================
    input                            mem_ack,
    input  [L2_DRAM_BUS_BYTES*8-1:0] mem_rdata,
    output                           mem_req,
    output                           mem_we,
    output [31:0]                    mem_addr,
    output [L2_DRAM_BUS_BYTES*8-1:0] mem_wdata,
    output [L2_DRAM_BUS_BYTES-1:0]   mem_wstrb
);

// ===========================================================================
// INTERNAL SIGNAL DECLARATION
// ===========================================================================
    // L1 I-cache
    wire                         l1i_mem_req;
    wire [31:0]                  l1i_mem_addr;
    wire                         l1i_mem_we;
    wire [L1_L2_BUS_BYTES*8-1:0] l1i_mem_wdata;
    wire [L1_L2_BUS_BYTES-1:0]   l1i_mem_wstrb;
    
    // L1 D-cache
    wire                         l1d_mem_req;
    wire                         l1d_mem_we;
    wire [31:0]                  l1d_mem_addr;
    wire [L1_L2_BUS_BYTES*8-1:0] l1d_mem_wdata;
    wire [L1_L2_BUS_BYTES-1:0]   l1d_mem_wstrb;

    // L1-L2 interface
    wire                         l1_bus_we;
    wire [31:0]                  l1_bus_addr;
    wire [L1_L2_BUS_BYTES*8-1:0] l1_bus_wdata;
    wire [L1_L2_BUS_BYTES*8-1:0] l2_bus_rdata;
    wire [L1_L2_BUS_BYTES-1:0]   l1_bus_wstrb;
    
    // L1 cache arbiter
    wire                         l1_bus_req;
    wire                         l2_bus_ack;
    wire                         l1d_grant_ack;
    wire                         l1i_grant_ack;
    reg                          bus_busy;
    reg                          bus_owner_is_d; // 1: D-Cache owns lock, 0: I-Cache owns lock
    wire                         grant_d;
    wire                         grant_i;

// ===========================================================================
// UNUSED SIGNALs
// ===========================================================================
    wire l2_stall;
    wire unused;
    assign unused = |{l1i_mem_we, |l1i_mem_wdata, |l1i_mem_wstrb, l2_stall};

// ===========================================================================
// L1 I-CACHE INSTANCE
// ===========================================================================
    l1_icache #(
        .C_SIZE    (L1_I_SIZE      ), 
        .ASSOC     (L1_ASSOC       ), 
        .B_SIZE    (L1_B_SIZE      ), 
        .BUS_BYTES (L1_L2_BUS_BYTES)
    ) u_icache (
        .clk        (clk          ), 
        .rst_n      (rst_n        ),
        .cpu_req    (cpu_i_req    ), 
        .cpu_addr   (cpu_i_addr   ), 
        .cpu_rdata  (cpu_i_rdata  ), 
        .cpu_stall  (i_stall      ),
        .hit_event  (l1i_hit      ), 
        .miss_event (l1i_miss     ),
        .mem_req    (l1i_mem_req  ), 
        .mem_we     (l1i_mem_we   ), 
        .mem_addr   (l1i_mem_addr ), 
        .mem_wdata  (l1i_mem_wdata), 
        .mem_wstrb  (l1i_mem_wstrb),
        .mem_ack    (l1i_grant_ack), 
        .mem_rdata  (l2_bus_rdata )
    );

// ===========================================================================
// L1 D-CACHE INSTANCE
// ===========================================================================    
    l1_dcache #(
        .C_SIZE     (L1_D_SIZE      ), 
        .ASSOC      (L1_ASSOC       ), 
        .B_SIZE     (L1_B_SIZE      ), 
        .BUS_BYTES  (L1_L2_BUS_BYTES),
        .FIFO_DEPTH (FIFO_DEPTH     )
    ) u_dcache (
        .clk        (clk          ), 
        .rst_n      (rst_n        ),
        .cpu_req    (cpu_d_req    ), 
        .cpu_we     (cpu_d_we     ), 
        .cpu_addr   (cpu_d_addr   ), 
        .cpu_wdata  (cpu_d_wdata  ), 
        .cpu_size   (cpu_d_size   ),
        .cpu_rdata  (cpu_d_rdata  ), 
        .cpu_stall  (d_stall      ),
        .hit_event  (l1d_hit      ), 
        .miss_event (l1d_miss     ),
        .mem_req    (l1d_mem_req  ), 
        .mem_we     (l1d_mem_we   ), 
        .mem_addr   (l1d_mem_addr ), 
        .mem_wdata  (l1d_mem_wdata), 
        .mem_wstrb  (l1d_mem_wstrb),
        .mem_ack    (l1d_grant_ack), 
        .mem_rdata  (l2_bus_rdata )
    );

// ===========================================================================
// L1 to L2 ARBITER & MUX (FIXED: State-Locked Arbiter)
// ===========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bus_busy       <= 1'b0;
            bus_owner_is_d <= 1'b0;
        end else begin
            if (!bus_busy) begin
                // if the bus is idle, and L2 has missed (hasn't ack immediately)
                // then lock the bus
                if (l1d_mem_req && !l2_bus_ack) begin
                    bus_busy       <= 1'b1;
                    bus_owner_is_d <= 1'b1;
                end else if (l1i_mem_req && !l2_bus_ack) begin
                    bus_busy       <= 1'b1;
                    bus_owner_is_d <= 1'b0;
                end
            end else begin
                // ack from L2 signals the end of the current interaction
                // bus lock is released
                if (l2_bus_ack) begin
                    bus_busy <= 1'b0;
                end
            end
        end
    end

    // if bus is busy, maintain current grant
    // if idle, give D-Cache the priority 
    assign grant_d = bus_busy ?  bus_owner_is_d : l1d_mem_req;
    assign grant_i = bus_busy ? !bus_owner_is_d : (l1i_mem_req && !l1d_mem_req);

    // route by grant
    assign l1_bus_req   = grant_d ? l1d_mem_req   : (grant_i ? l1i_mem_req : 1'b0);
    assign l1_bus_we    = grant_d ? l1d_mem_we    : l1i_mem_we;
    assign l1_bus_addr  = grant_d ? l1d_mem_addr  : l1i_mem_addr;
    assign l1_bus_wdata = grant_d ? l1d_mem_wdata : l1i_mem_wdata;
    assign l1_bus_wstrb = grant_d ? l1d_mem_wstrb : l1i_mem_wstrb;

    // return ack to who has requested
    assign l1d_grant_ack = l2_bus_ack && grant_d;
    assign l1i_grant_ack = l2_bus_ack && grant_i;

`ifdef ENABLE_L2
// ===========================================================================
// L2 CACHE INSTANCE
// =========================================================================== 
    l2_cache #(
        .C_SIZE      (L2_SIZE          ), 
        .ASSOC       (L2_ASSOC         ), 
        .B_SIZE      (L2_B_SIZE        ),
        .L1_BUS_SIZE (L1_L2_BUS_BYTES  ),
        .BUS_SIZE    (L2_DRAM_BUS_BYTES)
    ) u_l2_cache (
        .clk        (clk          ), 
        .rst_n      (rst_n        ),
        .cpu_req    (l1_bus_req   ), 
        .cpu_we     (l1_bus_we    ), 
        .cpu_addr   (l1_bus_addr  ), 
        .cpu_wdata  (l1_bus_wdata ), 
        .cpu_wstrb  (l1_bus_wstrb ),
        .cpu_rdata  (l2_bus_rdata ), 
        .cpu_stall  (l2_stall     ), 
        .hit_event  (l2_hit_event ),
        .miss_event (l2_miss_event),
        .cpu_ack    (l2_bus_ack   ),
        .mem_req    (mem_req      ), 
        .mem_we     (mem_we       ), 
        .mem_addr   (mem_addr     ), 
        .mem_wdata  (mem_wdata    ), 
        .mem_wstrb  (mem_wstrb    ),
        .mem_ack    (mem_ack      ), 
        .mem_rdata  (mem_rdata    )
    );
`else
    assign mem_req      = l1_bus_req;
    assign mem_we       = l1_bus_we;
    assign mem_addr     = l1_bus_addr;
    assign mem_wdata    = l1_bus_wdata;
    assign mem_wstrb    = l1_bus_wstrb;
    assign l2_bus_ack   = mem_ack;
    assign l2_bus_rdata = mem_rdata;
    assign l2_hit_event = 1'b0;
`endif
endmodule