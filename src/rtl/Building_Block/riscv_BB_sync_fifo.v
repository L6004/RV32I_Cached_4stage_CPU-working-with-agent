module riscv_BB_sync_fifo #(
// ===========================================================================
// CONFIGURABLE PARAMETERS
// ===========================================================================
    parameter WIDTH = 32,
    parameter DEPTH = 4
)
(
// ===========================================================================
// PINS
// ===========================================================================
    input              clk,
    input              rst_n,
    input              wen,
    input  [WIDTH-1:0] wdata,
    input              ren,
    output [WIDTH-1:0] rdata,
    output             full,
    output             empty
);

// ===========================================================================
// FIXED PARAMETERS
// ===========================================================================
    localparam AW = $clog2(DEPTH);

// ===========================================================================
// INTERNAL SIGNALS
// ===========================================================================
    wire [WIDTH-1:0] mem[DEPTH-1:0];
    wire [AW-1:0]    waddr;
    wire [AW-1:0]    waddr_d;
    wire [AW-1:0]    raddr;
    wire [AW-1:0]    raddr_d;
    wire [AW:0]      cnt;
    wire [AW:0]      cnt_d;
    wire             wallow;
    wire             rallow;
    
// ===========================================================================
// R/W ALLOW LOGIC
// ===========================================================================
    assign wallow = (wen && !full);
    assign rallow = (ren && !empty);
    
// ===========================================================================
// ADDRESS COUNTERs
// ===========================================================================
    assign cnt_d = wallow ? (cnt + {{AW{1'b0}}, 1'b1}) 
                          : (rallow ? (cnt - {{AW{1'b0}}, 1'b1})
                                    : cnt);
    riscv_BB_dffr #(
        .DW      	(AW+1          ),
        .RST_VAL 	({(AW+1){1'b0}})
    ) u_state_indicator_cnt (
        .clk   	(clk  ),
        .rst_n 	(rst_n),
        .din   	(cnt_d),
        .dout  	(cnt  )
    );

    assign waddr_d = wallow ? (waddr + {{(AW-1){1'b0}}, 1'b1}) : waddr;
    riscv_BB_dffr #(
        .DW      	(AW        ),
        .RST_VAL 	({AW{1'b0}})
    ) u_waddr_ptr (
        .clk   	(clk    ),
        .rst_n 	(rst_n  ),
        .din   	(waddr_d),
        .dout  	(waddr  )
    );

    assign raddr_d = rallow ? (raddr + {{(AW-1){1'b0}}, 1'b1}) : raddr;
    riscv_BB_dffr #(
        .DW      	(AW        ),
        .RST_VAL 	({AW{1'b0}})
    ) u_raddr_ptr (
        .clk   	(clk    ),
        .rst_n 	(rst_n  ),
        .din   	(raddr_d),
        .dout  	(raddr  )
    );

// ===========================================================================
// STATE INDICATOR LOGIC
// ===========================================================================
    assign full  = rst_n ? (cnt == DEPTH)          : 1'b0;
    assign empty = rst_n ? (cnt == {(AW+1){1'b0}}) : 1'b1;

// ===========================================================================
// R/W DATA PATH
// ===========================================================================
    genvar i;
    generate
        for (i = 0; i < DEPTH; i = i + 1) begin: GEN_FIFO_MEM
            wire ld_en;
            wire wsel;
            
            assign wsel  = (waddr == i);
            assign ld_en = (wallow && wsel);

            riscv_BB_dfflr #(
                .DW      (WIDTH        ),
                .RST_VAL ({WIDTH{1'b0}})
            ) riscv_fifo_mem (
                .clk   (clk   ),
                .rst_n (rst_n ),
                .en    (ld_en ),
                .din   (wdata ),
                .dout  (mem[i])
            );
        end
    endgenerate

    // assign rdata = rallow ? mem[raddr] : {WIDTH{1'b0}};
    assign rdata = mem[raddr];

endmodule