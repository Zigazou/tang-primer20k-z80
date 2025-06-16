module false_ram (
    input wire        clk,
    input wire [15:0] address,
    input wire        enabled,
    output reg [7:0]  data
);

always @(posedge clk)
    if (enabled)
        case (address)
            16'h0000: data <= 8'h01;
            16'h0001: data <= 8'h10;
            16'h0002: data <= 8'h00;
            16'h0003: data <= 8'h3e;
            16'h0004: data <= 8'h0a;
            16'h0005: data <= 8'hed;
            16'h0006: data <= 8'h79;
            16'h0007: data <= 8'h01;
            16'h0008: data <= 8'h10;
            16'h0009: data <= 8'h00;
            16'h000a: data <= 8'h3e;
            16'h000b: data <= 8'h05;
            16'h000c: data <= 8'hed;
            16'h000d: data <= 8'h79;
            default : data <= 8'h00;
        endcase

endmodule