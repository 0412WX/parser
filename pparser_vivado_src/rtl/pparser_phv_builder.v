`timescale 1ns/1ps

module pparser_phv_builder (
    input  wire [2047:0]      header,
    input  wire [26*9-1:0]    action_descs,
    input  wire [3:0]         path_id,
    input  wire               error,
    output reg  [511:0]       phv
);
    localparam DESC_COUNT = 26;
    localparam DESC_W = 9;

    integer i;
    integer base;
    integer byte_idx;
    reg byte_valid;

    always @* begin
        phv = {512{1'b0}};

        if (!error) begin
            for (i = 0; i < DESC_COUNT; i = i + 1) begin
                base = (DESC_COUNT - 1 - i) * DESC_W;
                byte_valid = action_descs[base + DESC_W - 1];
                byte_idx = action_descs[base + 7 -: 8];

                if (byte_valid) begin
                    phv[511 - (i * 8) -: 8] = header[2047 - (byte_idx * 8) -: 8];
                end
            end

            phv[511 - (26 * 8) -: 8] = {4'h0, path_id};
        end
    end
endmodule
