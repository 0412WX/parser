`timescale 1ns/1ps

module pparser_action_table #(
    parameter DESC_COUNT = 26,
    parameter DESC_W = 9,
    parameter TENANT_W = 12,
    parameter INIT_FILE = "pparser_action_table.mem"
) (
    input  wire                          clk,
    input  wire                          rst,
    input  wire [TENANT_W-1:0]          tenant_id,
    input  wire [3:0]                   path_id,
    output wire [DESC_COUNT*DESC_W-1:0] action_descs
);
    localparam ACTION_ADDR_W = 5;
    wire unused_ready;

    pparser_rule_bram #(
        .DATA_W(DESC_COUNT * DESC_W),
        .ADDR_W(ACTION_ADDR_W),
        .DEPTH(1 << ACTION_ADDR_W),
        .INIT_FILE(INIT_FILE)
    ) u_action_bram (
        .clk(clk),
        .rst(rst),
        .en(1'b1),
        .addr({tenant_id[0], path_id}),
        .data(action_descs),
        .ready(unused_ready)
    );
endmodule
