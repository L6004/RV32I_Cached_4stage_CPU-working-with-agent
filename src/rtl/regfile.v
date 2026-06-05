module regfile (
    input         clk,
    input         we,
    input  [4:0]  waddr,
    input  [31:0] wdata,
    input  [4:0]  raddr1,
    input  [4:0]  raddr2,
    output [31:0] rdata1,
    output [31:0] rdata2
);
// ===========================================================================
// INTERNAL SIGNAL DECLARATION
// ===========================================================================
    // Backdoor reset for TB
    `ifdef SIM
        reg rst_regs;
    `endif
    
    // Backdoor interface for TB initialization
    // x0 doesn't need reset
    wire [31:0] gpl [0:31];
    wire reg_rst_n;

    `ifdef SIM
        assign reg_rst_n = !rst_regs;
    `else
        assign reg_rst_n = 1'b1;
    `endif
    assign gpl[0] = 32'h0;

// ===========================================================================
// REGISTER GENERATION
// ===========================================================================
    genvar i;
    generate
        for (i = 1; i < 32; i = i + 1) begin: GEN_GPL_REGS
            wire gpl_ld_en;
            wire gpl_wsel;
            
            assign gpl_wsel  = (waddr == i);
            assign gpl_ld_en = (we && gpl_wsel);

            riscv_BB_dfflr #(
                .DW      (32   ),
                .RST_VAL (32'h0)
            ) riscv_gpl (
                .clk   (clk      ),
                .rst_n (reg_rst_n),
                .en    (gpl_ld_en),
                .din   (wdata    ),
                .dout  (gpl[i]   )
            );
        end
    endgenerate

    // Write-First forwarding, sloving conflict between ID read and WB write
    assign rdata1 = (raddr1 == 5'h0) ? 32'h0 
                                     : ((we && (waddr == raddr1)) ? wdata 
                                                                  : gpl[raddr1]);
    assign rdata2 = (raddr2 == 5'h0) ? 32'h0 
                                     : ((we && (waddr == raddr2)) ? wdata 
                                                                  : gpl[raddr2]);
endmodule