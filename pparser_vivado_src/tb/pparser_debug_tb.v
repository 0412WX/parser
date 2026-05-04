`timescale 1ns/1ps

module pparser_debug_tb;
    localparam HEADER_W = 2048;

    reg                 clk = 1'b0;
    reg                 rst = 1'b1;
    reg                 in_valid = 1'b0;
    wire                in_ready;
    reg  [HEADER_W-1:0] in_header = {HEADER_W{1'b0}};
    wire                out_valid;
    reg                 out_ready = 1'b1;
    wire [3:0]          out_path_id;
    wire                out_error;
    wire [511:0]        out_phv;

    integer cycle_count;

    pparser_hw_static dut (
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .in_header(in_header),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .out_path_id(out_path_id),
        .out_error(out_error),
        .out_phv(out_phv)
    );

    always #5 clk = ~clk;

    function [HEADER_W-1:0] set_byte;
        input [HEADER_W-1:0] data;
        input integer byte_idx;
        input [7:0] value;
        begin
            set_byte = data;
            set_byte[HEADER_W - 1 - (byte_idx * 8) -: 8] = value;
        end
    endfunction

    function [HEADER_W-1:0] set_u16;
        input [HEADER_W-1:0] data;
        input integer byte_idx;
        input [15:0] value;
        begin
            set_u16 = data;
            set_u16 = set_byte(set_u16, byte_idx, value[15:8]);
            set_u16 = set_byte(set_u16, byte_idx + 1, value[7:0]);
        end
    endfunction

    function [HEADER_W-1:0] set_u32;
        input [HEADER_W-1:0] data;
        input integer byte_idx;
        input [31:0] value;
        begin
            set_u32 = data;
            set_u32 = set_byte(set_u32, byte_idx, value[31:24]);
            set_u32 = set_byte(set_u32, byte_idx + 1, value[23:16]);
            set_u32 = set_byte(set_u32, byte_idx + 2, value[15:8]);
            set_u32 = set_byte(set_u32, byte_idx + 3, value[7:0]);
        end
    endfunction

    function [HEADER_W-1:0] build_ipv4_header;
        reg [HEADER_W-1:0] h;
        begin
            h = {HEADER_W{1'b0}};
            h = set_u32(h, 0, 32'h00112233);
            h = set_u16(h, 4, 16'h4455);
            h = set_u32(h, 6, 32'h66778899);
            h = set_u16(h, 10, 16'hAABB);
            h = set_u16(h, 12, 16'h0800);
            h = set_u32(h, 14, 32'h45000054);
            build_ipv4_header = h;
        end
    endfunction

    initial begin
        $dumpfile("pparser_debug_tb.vcd");
        $dumpvars(0, pparser_debug_tb);
        in_header = build_ipv4_header();

        repeat (5) @(posedge clk);
        rst <= 1'b0;

        @(posedge clk);
        in_valid <= 1'b1;
        while (!in_ready) @(posedge clk);
        @(posedge clk);
        in_valid <= 1'b0;

        repeat (20) @(posedge clk);
        $finish;
    end

    always @(posedge clk) begin
        if (rst) begin
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
            $display(
                "cyc=%0d in_v=%0b in_r=%0b s0_v=%0b s1_v=%0b s2_v=%0b s3_v=%0b s4_v=%0b s5_v=%0b s6_v=%0b s7_v=%0b s8_v=%0b s1_key=%h st0_hit=%0b st0_addr=%0d st1_key=%h st1_hit=%0b st1_addr=%0d path=%0d err=%0b out_v=%0b out_path=%0d out_err=%0b",
                cycle_count,
                in_valid,
                in_ready,
                dut.s0_valid,
                dut.s1_valid,
                dut.s2_valid,
                dut.s3_valid,
                dut.s4_valid,
                dut.s5_valid,
                dut.s6_valid,
                dut.s7_valid,
                dut.s8_valid,
                dut.s1_stage0_key,
                dut.s3_stage0_hit,
                dut.s3_stage0_addr,
                dut.s4_stage1_key,
                dut.s6_stage1_hit,
                dut.s6_stage1_addr,
                dut.s7_path_id,
                dut.s7_error,
                out_valid,
                out_path_id,
                out_error
            );
        end
    end
endmodule
