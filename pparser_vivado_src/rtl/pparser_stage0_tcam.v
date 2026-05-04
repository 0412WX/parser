`timescale 1ns/1ps

module pparser_stage0_tcam (
    input  wire        clk,
    input  wire        rst,
    input  wire [15:0] key,
    output wire        ready,
    output wire        hit,
    output wire [1:0]  addr,
    output wire        terminal_after_stage0
);
    wire       core_ready;
    wire       core_match;
    wire [3:0] core_match_addr;
    wire [16:0] cmp_din;

    assign cmp_din = {1'b1, key};

    pparser_stage0_cam_core u_stage0_cam_core (
        .clk(clk),
        .rst(rst),
        .cmp_din(cmp_din),
        .ready(core_ready),
        .match(core_match),
        .match_addr(core_match_addr)
    );

    assign ready = core_ready;
    assign hit = core_ready & core_match;
    assign addr = core_match_addr[1:0];
    assign terminal_after_stage0 = core_match && (core_match_addr[1:0] < 2);
endmodule
