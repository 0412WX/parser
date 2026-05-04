`timescale 1ns/1ps

module pparser_stage1_tcam (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] key,
    output wire        ready,
    output wire        hit,
    output wire [2:0]  addr
);
    wire [3:0] cam_match_addr;
    wire       cam_match;

    pparser_stage1_cam_core u_stage1_cam_core (
        .clk(clk),
        .rst(rst),
        .cmp_din({1'b1, key}),
        .ready(ready),
        .match(cam_match),
        .match_addr(cam_match_addr)
    );

    assign hit = ready & cam_match;
    assign addr = cam_match_addr[2:0];
endmodule
