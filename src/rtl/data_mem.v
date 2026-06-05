module data_mem (
    input         clk,
    input         we,
    input  [31:0] addr,
    input  [31:0] wdata,
    input         mem_size, // 0: Word, 1: Byte
    output [31:0] rdata
);
    reg  [31:0] mem_array[0:4095]; // 16KB
    wire [11:0] word_addr;
    wire [1:0]  byte_offset;
    wire [31:0] word_read;
    reg  [7:0]  byte_read;

    assign word_addr   = addr[13:2];
    assign byte_offset = addr[1:0];
    assign word_read   = mem_array[word_addr];

    // Synchronous write
    always @(posedge clk) begin
        if (we) begin
            if (mem_size) begin // Byte Write (SB)
                case (byte_offset)
                    2'b00: mem_array[word_addr][7:0]   <= wdata[7:0];
                    2'b01: mem_array[word_addr][15:8]  <= wdata[7:0];
                    2'b10: mem_array[word_addr][23:16] <= wdata[7:0];
                    2'b11: mem_array[word_addr][31:24] <= wdata[7:0];
                endcase
            end else begin      // Word Write (SW)
                mem_array[word_addr] <= wdata;
            end
        end
    end

    // Asynchronous read
    always @(*) begin
        case (byte_offset)
            2'b00: byte_read = word_read[7:0];
            2'b01: byte_read = word_read[15:8];
            2'b10: byte_read = word_read[23:16];
            2'b11: byte_read = word_read[31:24];
        endcase
    end

    // Do signed expansion when mem_size == 1 (LB), 
    // else pass through (LW)
    assign rdata = mem_size ? {{24{byte_read[7]}}, byte_read} : word_read;
endmodule