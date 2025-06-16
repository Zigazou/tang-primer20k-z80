module in_out_split(
    input direction,
    inout [7:0] data_in_out,

    input [7:0] data_in,
    output [7:0] data_out
);
    // Connect data_out to data_in_out when direction is 1
    assign data_out = (direction == 1'b1) ? data_in_out : 8'bz;

    // Drive data_in_out when direction is 0, high impedance otherwise
    assign data_in_out = (direction == 1'b0) ? data_in : 8'bz;
endmodule