`timescale 1ns/1ps

module pparser_key_extractor #(
    parameter HEADER_W = 2048,
    parameter OUTPUT_W = 16
) (
    input  wire [HEADER_W-1:0]    header,
    input  wire [OUTPUT_W*11-1:0] descs_flat,
    output reg  [OUTPUT_W-1:0]    key_bits
);
    integer i;
    integer base;
    integer abs_bit_idx;
    reg [7:0] byte_idx;
    reg [2:0] bit_idx;

    always @* begin
        key_bits = {OUTPUT_W{1'b0}};

        for (i = 0; i < OUTPUT_W; i = i + 1) begin
            base = (OUTPUT_W - 1 - i) * 11;
            byte_idx = descs_flat[base + 10 -: 8];
            bit_idx = descs_flat[base + 2 -: 3];
            abs_bit_idx = HEADER_W - 1 - (byte_idx * 8) - bit_idx;
            key_bits[OUTPUT_W - 1 - i] = header[abs_bit_idx];
        end
    end
endmodule
