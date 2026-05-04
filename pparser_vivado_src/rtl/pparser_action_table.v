`timescale 1ns/1ps

module pparser_action_table #(
    parameter DESC_COUNT = 26,
    parameter DESC_W = 9,
    parameter TENANT_W = 12
) (
    input  wire [TENANT_W-1:0]          tenant_id,
    input  wire [3:0]                   path_id,
    output reg  [DESC_COUNT*DESC_W-1:0] action_descs
);
    localparam ACTION_ADDR_W = 5;

    (* rom_style = "block" *) reg [DESC_COUNT*DESC_W-1:0] action_desc_rom [0:(1 << ACTION_ADDR_W)-1];

    integer path_idx;
    integer out_idx;

    task set_desc;
        input integer rom_idx;
        input integer byte_pos;
        input integer header_byte;
        integer base;
        begin
            base = (DESC_COUNT - 1 - byte_pos) * DESC_W;
            action_desc_rom[rom_idx][base + DESC_W - 1 -: DESC_W] = {1'b1, header_byte[7:0]};
        end
    endtask

    initial begin
        for (path_idx = 0; path_idx < (1 << ACTION_ADDR_W); path_idx = path_idx + 1) begin
            action_desc_rom[path_idx] = {(DESC_COUNT * DESC_W){1'b0}};
        end

        for (path_idx = 0; path_idx < 8; path_idx = path_idx + 1) begin
            for (out_idx = 0; out_idx < 14; out_idx = out_idx + 1) begin
                set_desc(path_idx, out_idx, out_idx);
            end
        end

        for (out_idx = 22; out_idx < 26; out_idx = out_idx + 1) begin
            set_desc(0, out_idx, out_idx - 8);
            set_desc(1, out_idx, out_idx - 8);
        end

        for (out_idx = 14; out_idx < 18; out_idx = out_idx + 1) begin
            set_desc(2, out_idx, out_idx);
            set_desc(3, out_idx, out_idx);
            set_desc(6, out_idx, out_idx);
        end
        for (out_idx = 22; out_idx < 26; out_idx = out_idx + 1) begin
            set_desc(2, out_idx, out_idx - 4);
            set_desc(3, out_idx, out_idx - 4);
            set_desc(6, out_idx, out_idx - 4);
        end

        for (out_idx = 14; out_idx < 18; out_idx = out_idx + 1) begin
            set_desc(4, out_idx, out_idx);
            set_desc(5, out_idx, out_idx);
            set_desc(7, out_idx, out_idx);
        end
        for (out_idx = 18; out_idx < 22; out_idx = out_idx + 1) begin
            set_desc(4, out_idx, out_idx);
            set_desc(5, out_idx, out_idx);
            set_desc(7, out_idx, out_idx);
        end
        for (out_idx = 22; out_idx < 26; out_idx = out_idx + 1) begin
            set_desc(4, out_idx, out_idx);
            set_desc(5, out_idx, out_idx);
            set_desc(7, out_idx, out_idx);
        end
    end

    always @* begin
        action_descs = action_desc_rom[{tenant_id[0], path_id}];
    end
endmodule
