`timescale 1ns/1ps

module pparser_header_bram #(
    parameter integer DATA_W = 2048,
    parameter integer DEPTH = 32,
    parameter integer ADDR_W = 5
) (
    input  wire              clk,
    input  wire              wr_en,
    input  wire [ADDR_W-1:0] wr_addr,
    input  wire [DATA_W-1:0] wr_data,
    input  wire              rd_en,
    input  wire [ADDR_W-1:0] rd_addr,
    output wire [DATA_W-1:0] rd_data
);
    wire [0:0] wea;

    assign wea = wr_en;

    pparser_header_bram_ip u_header_bram (
        .clka(clk),
        .ena(wr_en),
        .wea(wea),
        .addra(wr_addr),
        .dina(wr_data),
        .clkb(clk),
        .enb(rd_en),
        .addrb(rd_addr),
        .doutb(rd_data)
    );
endmodule
