`timescale 1ns/1ps

module pparser_stage1_tcam (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] key,
    output wire        ready,
    output wire        hit,
    output wire [2:0]  addr
);
    wire        core_ready;
    wire        core_match;
    wire [3:0]  core_match_addr;
    wire [32:0] cmp_din;

    assign cmp_din = {1'b1, key};

    pparser_stage1_cam_core u_stage1_cam_core (
        .clk(clk),
        .rst(rst),
        .cmp_din(cmp_din),
        .ready(core_ready),
        .match(core_match),
        .match_addr(core_match_addr)
    );

    assign ready = core_ready;
    assign hit = core_ready & core_match;
    assign addr = core_match_addr[2:0];
endmodule
