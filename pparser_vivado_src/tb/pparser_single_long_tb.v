`timescale 1ns/1ps

module pparser_single_long_tb;
    localparam HEADER_W = 2048;
    localparam PHV_W = 512;
    localparam PATH_MPLS_IPV4 = 4'd2;
    localparam PATH_ERROR = 4'hF;
    localparam WATCHDOG_CYCLES = 500;

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
    integer latency = -1;
    integer resolver_seen = 0;
    reg resolver_stage0_hit = 1'b0;
    reg [1:0] resolver_stage0_addr = 2'b00;
    reg resolver_stage1_hit = 1'b0;
    reg [2:0] resolver_stage1_addr = 3'b000;

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

    function [HEADER_W-1:0] build_mpls_ipv4_header;
        reg [HEADER_W-1:0] h;
        begin
            h = {HEADER_W{1'b0}};
            h = set_u32(h, 0, 32'h00112233);
            h = set_u16(h, 4, 16'h4455);
            h = set_u32(h, 6, 32'h66778899);
            h = set_u16(h, 10, 16'hAABB);
            h = set_u16(h, 12, 16'h8847);
            h = set_u32(h, 14, 32'h001000FF);
            h = set_u16(h, 18, 16'h0800);
            h = set_u16(h, 20, 16'h4501);
            build_mpls_ipv4_header = h;
        end
    endfunction

    function [HEADER_W-1:0] build_mpls_stage1_miss_header;
        reg [HEADER_W-1:0] h;
        begin
            h = build_mpls_ipv4_header();
            h = set_u16(h, 18, 16'h1234);
            build_mpls_stage1_miss_header = h;
        end
    endfunction

    task automatic send_one(input [HEADER_W-1:0] header);
        begin
            @(posedge clk);
            in_valid <= 1'b1;
            in_header <= header;
            while (!(in_valid && in_ready)) begin
                @(posedge clk);
            end
            accept_cycle = cycle_count;
            @(posedge clk);
            in_valid <= 1'b0;
            in_header <= {HEADER_W{1'b0}};
        end
    endtask

    task automatic expect_one(
        input [3:0] expected_path,
        input       expected_error,
        input [8*48-1:0] label
    );
        integer timeout;
        begin
            timeout = 0;
            while (!out_valid) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (timeout > 250) begin
                    $display("ERROR: %0s timed out waiting for output", label);
                    $fatal(1);
                end
            end

            latency = cycle_count - accept_cycle;
            $display(
                "SINGLE_LONG_RESULT %0s path=%0d err=%0b latency=%0d phv_marker=%02h stage0_hit=%0b stage0_addr=%0d stage1_hit=%0b stage1_addr=%0d",
                label,
                out_path_id,
                out_error,
                latency,
                out_phv[303:296],
                resolver_stage0_hit,
                resolver_stage0_addr,
                resolver_stage1_hit,
                resolver_stage1_addr
            );

            if (out_path_id !== expected_path) begin
                $display("ERROR: %0s expected path %0d got %0d", label, expected_path, out_path_id);
                $fatal(1);
            end
            if (out_error !== expected_error) begin
                $display("ERROR: %0s expected error %0b got %0b", label, expected_error, out_error);
                $fatal(1);
            end
            if (!expected_error && (out_phv[303:296] !== {4'h0, expected_path})) begin
                $display("ERROR: %0s PHV marker mismatch", label);
                $fatal(1);
            end
            if (latency != 12) begin
                $display("ERROR: %0s expected latency 12 got %0d", label, latency);
                $fatal(1);
            end
        end
    endtask

    initial begin
        repeat (5) @(posedge clk);
        rst <= 1'b0;

        resolver_seen = 0;
        send_one(build_mpls_ipv4_header());
        expect_one(PATH_MPLS_IPV4, 1'b0, "valid_mpls_ipv4");
        if (!resolver_seen || !resolver_stage0_hit || !resolver_stage1_hit || resolver_stage0_addr < 2 || resolver_stage1_addr == 3'd0) begin
            $display("ERROR: valid_mpls_ipv4 did not prove a non-bypass Stage1 match");
            $fatal(1);
        end

        repeat (4) @(posedge clk);
        resolver_seen = 0;
        send_one(build_mpls_stage1_miss_header());
        expect_one(PATH_ERROR, 1'b1, "stage1_miss_mpls");
        if (!resolver_seen || !resolver_stage0_hit || resolver_stage0_addr < 2 || resolver_stage1_hit) begin
            $display("ERROR: stage1_miss_mpls did not exercise a long-path Stage0 match");
            $fatal(1);
        end

        $display("PASS: single long-packet Stage1 lookup behavior verified");
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

    always @(posedge clk) begin
        if (dut.s6_valid) begin
            resolver_seen <= 1;
            resolver_stage0_hit <= dut.s6_stage0_hit;
            resolver_stage0_addr <= dut.s6_stage0_addr;
            resolver_stage1_hit <= dut.s6_stage1_hit;
            resolver_stage1_addr <= dut.s6_stage1_addr;
        end
    end
endmodule
