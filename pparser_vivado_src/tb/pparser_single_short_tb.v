`timescale 1ns/1ps

module pparser_single_short_tb;
    localparam HEADER_W = 2048;
    localparam PHV_W = 512;
    localparam EXPECTED_PATH = 4'd0;
    localparam WATCHDOG_CYCLES = 200;

    reg                 clk = 1'b0;
    reg                 rst = 1'b1;
    reg                 in_valid = 1'b0;
    wire                in_ready;
    reg  [HEADER_W-1:0] in_header = {HEADER_W{1'b0}};
    wire                out_valid;
    reg                 out_ready = 1'b1;
    wire [3:0]          out_path_id;
    wire                out_error;
    wire [PHV_W-1:0]    out_phv;

    integer cycle_count = 0;
    integer accept_cycle = -1;
    integer output_cycle = -1;
    integer latency = -1;

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

    task automatic load_short_ipv4_header;
        reg [HEADER_W-1:0] h;
        begin
            h = {HEADER_W{1'b0}};
            h = set_u32(h, 0, 32'h00112233);
            h = set_u16(h, 4, 16'h4455);
            h = set_u32(h, 6, 32'h66778899);
            h = set_u16(h, 10, 16'hAABB);
            h = set_u16(h, 12, 16'h0800);
            h = set_u32(h, 14, 32'h45000054);
            in_header = h;
        end
    endtask

    initial begin
        load_short_ipv4_header();

        repeat (5) @(posedge clk);
        rst <= 1'b0;

        @(negedge clk);
        in_valid <= 1'b1;

        while (!in_ready) begin
            @(posedge clk);
            @(negedge clk);
        end

        @(posedge clk);
        accept_cycle = cycle_count;

        @(negedge clk);
        in_valid <= 1'b0;

        wait (out_valid);
        @(posedge clk);
        output_cycle = cycle_count;
        latency = output_cycle - accept_cycle;

        $display(
            "SINGLE_SHORT_RESULT path=%0d err=%0b latency=%0d phv_marker=%02h",
            out_path_id,
            out_error,
            latency,
            out_phv[303:296]
        );

        if (out_error !== 1'b0) begin
            $display("ERROR: short packet produced parse error");
            $fatal(1);
        end

        if (out_path_id !== EXPECTED_PATH) begin
            $display("ERROR: expected path %0d got %0d", EXPECTED_PATH, out_path_id);
            $fatal(1);
        end

        if (out_phv[303:296] !== {4'h0, EXPECTED_PATH}) begin
            $display("ERROR: expected PHV marker %02h got %02h", {4'h0, EXPECTED_PATH}, out_phv[303:296]);
            $fatal(1);
        end

        $display("PASS: single short IPv4 packet parsed correctly");
        $finish;
    end

    always @(posedge clk) begin
        if (rst) begin
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
            if (cycle_count > WATCHDOG_CYCLES) begin
                $display("ERROR: watchdog timeout");
                $fatal(1);
            end
        end
    end
endmodule
