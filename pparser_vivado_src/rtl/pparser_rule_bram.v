`timescale 1ns/1ps

module pparser_rule_bram #(
    parameter integer DATA_W = 16,
    parameter integer ADDR_W = 1,
    parameter integer DEPTH = 2,
    parameter INIT_FILE = "none"
) (
    input  wire              clk,
    input  wire              rst,
    input  wire              en,
    input  wire [ADDR_W-1:0] addr,
    output wire [DATA_W-1:0] data,
    output reg               ready
);
    always @(posedge clk) begin
        if (rst) begin
            ready <= 1'b0;
        end else begin
            ready <= 1'b1;
        end
    end

    xpm_memory_sprom #(
        .ADDR_WIDTH_A(ADDR_W),
        .AUTO_SLEEP_TIME(0),
        .CASCADE_HEIGHT(0),
        .ECC_MODE("no_ecc"),
        .MEMORY_INIT_FILE(INIT_FILE),
        .MEMORY_INIT_PARAM(""),
        .MEMORY_OPTIMIZATION("true"),
        .MEMORY_PRIMITIVE("block"),
        .MEMORY_SIZE(DATA_W * DEPTH),
        .MESSAGE_CONTROL(0),
        .READ_DATA_WIDTH_A(DATA_W),
        .READ_LATENCY_A(1),
        .READ_RESET_VALUE_A("0"),
        .RST_MODE_A("SYNC"),
        .SIM_ASSERT_CHK(0),
        .USE_MEM_INIT(1),
        .WAKEUP_TIME("disable_sleep")
    ) u_rule_bram (
        .dbiterra(),
        .douta(data),
        .sbiterra(),
        .addra(addr),
        .clka(clk),
        .ena(en),
        .injectdbiterra(1'b0),
        .injectsbiterra(1'b0),
        .regcea(1'b1),
        .rsta(rst),
        .sleep(1'b0)
    );
endmodule
