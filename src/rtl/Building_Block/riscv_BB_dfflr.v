module riscv_BB_dfflr #(
// ===========================================================================
// CONFIGURABLE PARAMETERS
// ===========================================================================
    parameter DW      = 32,     // data width
    parameter RST_VAL = 'b0     // reset value
)
(
// ===========================================================================
// PINS
// ===========================================================================
    input               clk,    // clk
    input               rst_n,  // asynchronous reset, active low
    input               en,     // load enable
    input      [DW-1:0] din,    // D
    output reg [DW-1:0] dout    // Q
);

// ===========================================================================
// FLOP
// ===========================================================================
    always@ (posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            dout <= RST_VAL;
        end
        else begin
            if(en) begin
                dout <= din;
            end
        end
    end

endmodule