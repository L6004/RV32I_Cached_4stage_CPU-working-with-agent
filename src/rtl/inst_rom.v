module inst_rom (
    input  wire [11:0] addr,
    output wire [31:0] dout
);

    reg [31:0] rom_array [0:4095];

    assign dout = rom_array[addr];

endmodule