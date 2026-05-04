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
    wire [3:0] cam_match_addr;
    wire       cam_match;

    pparser_stage0_cam_core u_stage0_cam_core (
        .clk(clk),
        .rst(rst),
        .cmp_din({1'b1, key}),
        .ready(ready),
        .match(cam_match),
        .match_addr(cam_match_addr)
    );

    assign hit = ready & cam_match;
    assign addr = cam_match_addr[1:0];
    assign terminal_after_stage0 = cam_match && (cam_match_addr[1:0] < 2);
endmodule
